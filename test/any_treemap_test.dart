// ignore_for_file: deprecated_member_use

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapNode<String> _root({double first = 2}) => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [
        TreemapNode(key: 'a', label: 'Alpha', weight: first),
        TreemapNode(key: 'b', label: 'Beta', weight: 3),
      ],
    ),
  ],
);

bool _semanticsContains(SemanticsNode node, String label) {
  if (node.getSemanticsData().label == label) return true;
  var found = false;
  node.visitChildren((child) {
    found = _semanticsContains(child, label);
    return !found;
  });
  return found;
}

List<SemanticsData> _allSemantics(SemanticsNode node) {
  final result = <SemanticsData>[node.getSemanticsData()];
  node.visitChildren((child) {
    result.addAll(_allSemantics(child));
    return true;
  });
  return result;
}

void main() {
  testWidgets('renders constrained immutable data with semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 400,
        height: 300,
        child: TreemapChart<String>(
          root: _root(),
          tiles: testTreemapTiles(),
          labels: testTreemapLabels(),
          semantics: const TreemapSemantics(),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );
    await tester.pump();

    expect(snapshot?.nodes, hasLength(3));
    expect(find.byType(CustomPaint), findsWidgets);
    // The test binding's active view owner is not the root pipeline owner.
    final semanticsRoot =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    expect(_semanticsContains(semanticsRoot, 'Alpha'), isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('empty and all-zero trees render no package visual', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          key: const ValueKey('empty-chart'),
          root: TreemapNode(
            key: 'root',
            children: [TreemapNode(key: 'zero', weight: 0)],
          ),
          tiles: const TreemapNoopTileLayer(),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );
    expect(snapshot?.nodes, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('empty-chart')),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-size data and appearance updates rebuild normally', (
    tester,
  ) async {
    final firstWeight = ValueNotifier(1.0);
    addTearDown(firstWeight.dispose);
    TreemapGeometrySnapshot<String>? latest;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 400,
        height: 300,
        child: ValueListenableBuilder<double>(
          valueListenable: firstWeight,
          builder: (context, value, _) {
            final style = TreemapStyle(
              tileAppearance: TreemapAppearance(
                borderRadius: BorderRadius.circular(value),
              ),
            );
            return TreemapChart<String>(
              root: _root(first: value),
              tiles: testTreemapTiles(style: style),
              labels: testTreemapLabels(style: style),
              onSnapshot: (snapshot) => latest = snapshot,
            );
          },
        ),
      ),
    );
    final before = latest!.index[const TreemapKey.source('a')]!.bounds.area;

    firstWeight.value = 8;
    await tester.pump();
    await tester.pump();
    final after = latest!.index[const TreemapKey.source('a')]!.bounds.area;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('borrowed controller remains usable after chart removal', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    await tester.pumpTreemapApp(
      SizedBox(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _root(),
          tiles: testTreemapTiles(),
          controller: controller,
        ),
      ),
    );
    expect(controller.zoomTo('group').succeeded, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.reset().succeeded, isTrue);
  });

  testWidgets('unbounded constraints produce an actionable Flutter error', (
    tester,
  ) async {
    await tester.pumpTreemapApp(
      SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: TreemapChart<String>(root: _root(), tiles: testTreemapTiles()),
        ),
      ),
    );
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('finite width and height'));
  });

  testWidgets(
    'semantic nodes expose level, selection, focus, and zoom action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      await tester.pumpTreemapApp(
        SizedBox(
          width: 400,
          height: 300,
          child: TreemapChart<String>(
            root: _root(),
            tiles: testTreemapTiles(),
            labels: testTreemapLabels(),
            semantics: const TreemapSemantics(),
            controller: controller,
            autofocus: true,
          ),
        ),
      );
      controller.select('a');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // The test binding's active view owner is not the root pipeline owner.
      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      final nodes = _allSemantics(root);
      final alpha = nodes.singleWhere((data) => data.label == 'Alpha');
      expect(alpha.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(
        nodes.any((data) => data.hasFlag(SemanticsFlag.isFocused)),
        isTrue,
      );
      final group = nodes.singleWhere((data) => data.label == 'Group');
      expect(group.headingLevel, 2);
      expect(group.hasAction(SemanticsAction.expand), isTrue);
      semantics.dispose();
    },
  );
}
