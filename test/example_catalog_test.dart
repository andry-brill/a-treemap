import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

void main() {
  test('every scenario has detailed tooltip metadata', () {
    expect(allScenarios, hasLength(43));
    for (final scenario in allScenarios) {
      expect(
        scenario.description.trim().length,
        greaterThan(100),
        reason: scenario.id,
      );
      expect(
        scenario.description,
        isNot(equals(scenario.title)),
        reason: scenario.id,
      );
    }
  });

  testWidgets('scenario groups start expanded and can collapse', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TreemapExampleApp());
    await tester.pump();

    expect(find.text('any_treemap feature catalog'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      find.byKey(const ValueKey('scenario-data-explicit-tree')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scenario-data-from-records')),
      findsOneWidget,
    );

    final group = find.byKey(const ValueKey('scenario-group-Data'));
    final groupTitle = find.descendant(of: group, matching: find.text('Data'));
    final expandedIcon = find.byKey(const ValueKey('scenario-group-icon-Data'));
    expect(find.byIcon(Icons.expand_less), findsWidgets);
    expect(
      tester.getCenter(expandedIcon).dx,
      greaterThan(tester.getCenter(groupTitle).dx),
    );

    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('scenario-data-explicit-tree')),
      findsNothing,
    );
    expect(tester.widget<Icon>(expandedIcon).icon, Icons.expand_more);

    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('scenario-data-explicit-tree')),
      findsOneWidget,
    );
  });

  testWidgets('scenario buttons select with a trailing checkmark', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TreemapExampleApp());
    await tester.pump();

    final first = find.byKey(const ValueKey('scenario-data-explicit-tree'));
    final second = find.byKey(const ValueKey('scenario-data-from-records'));
    final firstCheck = find.byKey(
      const ValueKey('scenario-check-data-explicit-tree'),
    );
    final firstTitle = find.descendant(
      of: first,
      matching: find.text('Explicit immutable tree'),
    );
    expect(firstCheck, findsOneWidget);
    expect(tester.getSize(first).width, greaterThan(250));
    expect(tester.getSize(first).height, lessThan(60));
    expect(tester.widget<Text>(firstTitle).style?.fontSize, 14);
    expect(
      find.descendant(
        of: first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding ==
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getCenter(firstCheck).dx,
      greaterThan(
        tester
            .getCenter(
              find.descendant(
                of: first,
                matching: find.text('Explicit immutable tree'),
              ),
            )
            .dx,
      ),
    );

    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(firstCheck, findsNothing);
    expect(
      find.byKey(const ValueKey('scenario-check-data-from-records')),
      findsOneWidget,
    );
    expect(find.text('2/41'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('scenario-header-description')),
          )
          .data,
      allScenarios[1].description,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('group titles are subdued and scenario descriptions tooltip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TreemapExampleApp());
    await tester.pump();

    final group = find.byKey(const ValueKey('scenario-group-Data'));
    final groupTitle = tester.widget<Text>(
      find.descendant(of: group, matching: find.text('Data')),
    );
    final headerMetadata = tester.widget<Text>(
      find.byKey(const ValueKey('scenario-header-metadata')),
    );
    final scenarioButton = find.byKey(
      const ValueKey('scenario-data-explicit-tree'),
    );
    final scenarioTitle = tester.widget<Text>(
      find.descendant(
        of: scenarioButton,
        matching: find.text('Explicit immutable tree'),
      ),
    );
    expect(groupTitle.style?.fontSize, 13);
    expect(groupTitle.style!.color!.a, lessThan(scenarioTitle.style!.color!.a));
    expect(headerMetadata.style!.color, groupTitle.style!.color);
    expect(find.text(allScenarios.first.description), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1100, 700));
    await mouse.moveTo(tester.getCenter(scenarioButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(allScenarios.first.description), findsNWidgets(2));
    await mouse.removePointer();
  });

  testWidgets('app bar toggles between light and dark themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TreemapExampleApp());
    await tester.pump();

    final toggle = find.byKey(const ValueKey('theme-toggle'));
    final scaffold = find.byType(Scaffold);
    final initial = Theme.of(tester.element(scaffold)).brightness;

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final toggled = Theme.of(tester.element(scaffold)).brightness;
    expect(
      toggled,
      initial == Brightness.dark ? Brightness.light : Brightness.dark,
    );
    expect(
      find.byIcon(
        toggled == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
      ),
      findsOneWidget,
    );
  });

  testWidgets('virtualized builders retain multiple readable labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scenario = allScenarios.singleWhere(
      (item) => item.id == 'appearance-builders-virtualized',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: scenario.builder)),
      ),
    );
    await tester.pump();

    final customLabelCount = find
        .byIcon(Icons.widgets_outlined)
        .evaluate()
        .length;
    expect(customLabelCount, 80);
    expect(find.textContaining('Item '), findsWidgets);
    expect(find.text('Other (41)'), findsOneWidget);
    expect(find.text('null'), findsNothing);
  });

  testWidgets('grouped scenario navigation layout and selection contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TreemapExampleApp());
    await tester.pump();

    final picker = find.byKey(const ValueKey('scenario-picker'));
    final first = find.byKey(const ValueKey('scenario-data-explicit-tree'));
    final second = find.byKey(const ValueKey('scenario-data-from-records'));
    final colorScheme = Theme.of(tester.element(first)).colorScheme;

    Material nearestMaterial(Finder finder) {
      Material? material;
      tester.element(finder).visitAncestorElements((element) {
        if (element.widget case final Material value) {
          material = value;
          return false;
        }
        return true;
      });
      return material!;
    }

    expect(tester.getSize(picker).width, 300);
    expect(
      tester
          .widget<ListView>(
            find.descendant(of: picker, matching: find.byType(ListView)),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('scenario-group-Data'))).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('scenario-group-Layout algorithms')),
            )
            .dy,
      ),
    );
    expect(nearestMaterial(first).color, colorScheme.secondaryContainer);
    expect(nearestMaterial(second).color, Colors.transparent);
    expect(
      tester.widget<InkWell>(first).borderRadius,
      BorderRadius.circular(10),
    );

    await tester.tap(second);
    await tester.pumpAndSettle();

    expect(nearestMaterial(first).color, Colors.transparent);
    expect(nearestMaterial(second).color, colorScheme.secondaryContainer);
    expect(
      find.byKey(const ValueKey('scenario-check-data-from-records')),
      findsOneWidget,
    );
  });
}
