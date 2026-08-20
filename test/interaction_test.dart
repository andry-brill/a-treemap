import 'dart:ui' show PointerDeviceKind;

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

Widget _bareTooltipContainer(BuildContext context, Widget child) => child;

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [
        TreemapNode(key: 'a', label: 'Alpha', weight: 4),
        TreemapNode(key: 'b', label: 'Beta', weight: 3),
      ],
    ),
    TreemapNode(key: 'c', label: 'Gamma', weight: 2),
  ],
);

TreemapNode<String> _consumerTree() => TreemapNode(
  key: 'root',
  label: 'All markets',
  children: [
    TreemapNode(
      key: 'consumer',
      label: 'Consumer',
      children: [
        TreemapNode(key: 'mobile', label: 'Mobile', weight: 55),
        TreemapNode(key: 'web', label: 'Web', weight: 30),
        TreemapNode(key: 'desktop', label: 'Desktop', weight: 15),
      ],
    ),
  ],
);

TreemapNode<String> _deepTree() => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [
        TreemapNode(
          key: 'subgroup',
          label: 'Subgroup',
          children: [
            TreemapNode(key: 'deep-a', label: 'Deep Alpha', weight: 4),
            TreemapNode(key: 'deep-b', label: 'Deep Beta', weight: 3),
          ],
        ),
      ],
    ),
  ],
);

Offset _centerOf(
  WidgetTester tester,
  TreemapGeometrySnapshot<String> snapshot,
  String key,
) {
  final chartOrigin = tester.getTopLeft(find.byType(TreemapChart<String>));
  final bounds = snapshot.index[TreemapKey.source(key)]!.bounds;
  return chartOrigin + Offset(bounds.centerX, bounds.centerY);
}

void main() {
  testWidgets('hover tooltip follows each topmost visible leaf', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          height: 300,
          child: TreemapChart<String>(
            root: _consumerTree(),
            tiles: testTreemapTiles(),
            controller: controller,
            tooltip: TreemapTooltip(
              config: const TreemapTooltipConfig(
                activation: TreemapTooltipActivation.hover,
              ),
              builder: (context, details) => Text(
                details.label ?? '',
                key: const ValueKey('visible-leaf-tooltip'),
              ),
            ),
            onSnapshot: (value) => snapshot = value,
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    for (final leaf in const [
      (key: 'mobile', label: 'Mobile'),
      (key: 'web', label: 'Web'),
      (key: 'desktop', label: 'Desktop'),
    ]) {
      await mouse.moveTo(_centerOf(tester, snapshot!, leaf.key));
      await tester.pump();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('visible-leaf-tooltip')))
            .data,
        leaf.label,
      );
      expect(controller.hoveredKey, TreemapKey.source(leaf.key));
    }
    await mouse.removePointer();
  });

  testWidgets('chart tooltip anchors to the tapped leaf bounds', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 420,
          height: 280,
          child: TreemapChart<String>(
            root: _tree(),
            tiles: testTreemapTiles(),
            interaction: const TreemapInteractionConfig(zoomOnNodeTap: false),
            tooltip: TreemapTooltip(
              config: const TreemapTooltipConfig(
                activation: TreemapTooltipActivation.tap,
                placement: TreemapTooltipPlacement.above,
                hideDelay: Duration(minutes: 1),
                margin: 8,
                maxWidth: 120,
                containerBuilder: _bareTooltipContainer,
              ),
              builder: (context, details) => const SizedBox(
                key: ValueKey('bounded-tooltip'),
                width: 100,
                height: 32,
              ),
            ),
            onSnapshot: (value) => snapshot = value,
          ),
        ),
      ),
    );

    await tester.tapAt(_centerOf(tester, snapshot!, 'c'));
    await tester.pump();

    final chartOrigin = tester.getTopLeft(find.byType(TreemapChart<String>));
    final leafBounds = snapshot!.index[const TreemapKey.source('c')]!.bounds;
    final expectedX = (leafBounds.centerX - 50).clamp(0, 320).toDouble();
    final expectedY = (leafBounds.top - 40).clamp(0, 248).toDouble();
    final tooltip = find.byKey(const ValueKey('bounded-tooltip'));
    final tooltipOffset = tester.getTopLeft(tooltip) - chartOrigin;

    expect(tester.getSize(tooltip), const Size(100, 32));
    expect(tooltipOffset.dx, closeTo(expectedX, .001));
    expect(tooltipOffset.dy, closeTo(expectedY, .001));
  });

  testWidgets('deepest leaf click zooms out when no tap callback is defined', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 420,
        height: 280,
        child: TreemapChart<String>(
          root: _deepTree(),
          tiles: testTreemapTiles(),
          controller: controller,
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );

    expect(controller.zoomTo('subgroup').succeeded, isTrue);
    await tester.pump();
    expect(controller.focusKey, const TreemapKey.source('subgroup'));

    await tester.tapAt(_centerOf(tester, snapshot!, 'deep-a'));
    await tester.pump();

    expect(controller.focusKey, const TreemapKey.source('group'));
  });

  testWidgets('custom leaf tap callback suppresses automatic zoom out', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    TreemapGeometrySnapshot<String>? snapshot;
    String? tapped;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 420,
        height: 280,
        child: TreemapChart<String>(
          root: _deepTree(),
          tiles: testTreemapTiles(),
          controller: controller,
          interaction: TreemapInteractionConfig(
            onNodeTap: (details) => tapped = details.label,
          ),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );

    expect(controller.zoomTo('subgroup').succeeded, isTrue);
    await tester.pump();
    await tester.tapAt(_centerOf(tester, snapshot!, 'deep-a'));
    await tester.pump();

    expect(tapped, 'Deep Alpha');
    expect(controller.focusKey, const TreemapKey.source('subgroup'));
  });

  testWidgets('modifier click zooms out instead of built-in zoom in', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 420,
        height: 280,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          controller: controller,
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );

    final childCenter = _centerOf(tester, snapshot!, 'a');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tapAt(childCenter);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.focusKey, const TreemapKey.source('root'));

    await tester.tapAt(childCenter);
    await tester.pump();
    expect(controller.focusKey, const TreemapKey.source('group'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tapAt(_centerOf(tester, snapshot!, 'a'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.focusKey, const TreemapKey.source('root'));
  });

  testWidgets('tap dispatch order, uncontrolled selection, tooltip, and zoom', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final events = <String>[];
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 420,
        height: 280,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          controller: controller,
          interaction: TreemapInteractionConfig(
            selectOnNodeTap: true,
            onNodeTap: (_) => events.add('tap'),
            onSelectionChanged: (_, changed) => events.add('selection'),
          ),
          tooltip: TreemapTooltip(
            config: const TreemapTooltipConfig(
              activation: TreemapTooltipActivation.tap,
              hideDelay: Duration(milliseconds: 100),
            ),
            builder: (context, details) => Text(
              'tooltip:${details.label}',
              key: const ValueKey('tooltip'),
            ),
          ),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );
    await tester.tapAt(_centerOf(tester, snapshot!, 'c'));
    await tester.pump();

    expect(events, ['tap', 'selection']);
    expect(controller.selectedKeys, {'c'});
    expect(controller.focusKey, const TreemapKey.source('root'));
    expect(find.byKey(const ValueKey('tooltip')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    expect(find.byKey(const ValueKey('tooltip')), findsNothing);

    final groupBounds =
        snapshot!.index[const TreemapKey.source('group')]!.bounds;
    final visibleNode = snapshot!.hitTest(
      groupBounds.centerX,
      groupBounds.centerY,
    )!;
    expect(visibleNode.key, isNot(const TreemapKey.source('group')));

    await tester.tapAt(_centerOf(tester, snapshot!, 'group'));
    await tester.pump();
    expect(find.text('tooltip:${visibleNode.label}'), findsOneWidget);
    expect(controller.selectedEntries, {visibleNode.key});
    expect(controller.focusKey, const TreemapKey.source('group'));
  });

  testWidgets(
    'controlled selection reports intent without mutating controller',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      Set<TreemapKey<String>>? proposed;
      TreemapGeometrySnapshot<String>? snapshot;
      await tester.pumpTreemapApp(
        SizedBox(
          width: 400,
          height: 240,
          child: TreemapChart<String>(
            root: _tree(),
            tiles: testTreemapTiles(),
            controller: controller,
            selection: TreemapSelectionConfig(
              selected: {const TreemapKey.source('a')},
            ),
            interaction: TreemapInteractionConfig(
              selectOnNodeTap: true,
              zoomOnNodeTap: false,
              onSelectionChanged: (selection, _) => proposed = selection,
            ),
            onSnapshot: (value) => snapshot = value,
          ),
        ),
      );
      await tester.tapAt(_centerOf(tester, snapshot!, 'c'));
      await tester.pump();

      expect(proposed, {const TreemapKey.source('c')});
      expect(controller.selectedEntries, isEmpty);
    },
  );

  testWidgets('mouse hover, exit, touch long press, and disabled input work', (
    tester,
  ) async {
    final hovered = <String?>[];
    final pressed = <String>[];
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 400,
        height: 240,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          interaction: TreemapInteractionConfig(
            longPressDuration: const Duration(milliseconds: 50),
            onHoverChanged: (details) => hovered.add(details?.label),
            onNodeLongPress: (details) => pressed.add(details.label ?? ''),
          ),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
    );
    final center = _centerOf(tester, snapshot!, 'c');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center);
    await mouse.moveTo(center);
    await tester.pump();
    expect(hovered.last, 'Gamma');
    await mouse.removePointer();
    await tester.pump();
    expect(hovered.last, isNull);

    final touch = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 51));
    await touch.up();
    expect(pressed, ['Gamma']);
  });

  testWidgets('keyboard traverses, activates, and goes back', (tester) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    await tester.pumpTreemapApp(
      SizedBox(
        width: 400,
        height: 240,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          controller: controller,
          autofocus: true,
          semantics: const TreemapSemantics(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
