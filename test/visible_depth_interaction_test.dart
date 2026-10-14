import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [
        TreemapNode(
          key: 'subgroup',
          label: 'Subgroup',
          children: [
            TreemapNode(key: 'a', label: 'Alpha', weight: 4),
            TreemapNode(key: 'b', label: 'Beta', weight: 3),
          ],
        ),
      ],
    ),
    TreemapNode(key: 'c', label: 'Gamma', weight: 2),
  ],
);

final class _RecordingTiles implements TreemapTileLayer<String> {
  late TreemapVisualContext<String> visual;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return const SizedBox.expand();
  }
}

Offset _centerOf(
  WidgetTester tester,
  TreemapGeometrySnapshot<String> snapshot,
  String key,
) {
  final bounds = snapshot.index[TreemapKey.source(key)]!.bounds;
  return tester.getTopLeft(find.byType(TreemapChart<String>)) +
      Offset(bounds.centerX, bounds.centerY);
}

void main() {
  testWidgets('boundary labels, tooltip, semantics, and pointer drill-down', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    late TreemapGeometrySnapshot<String> snapshot;
    await tester.pumpTreemapApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          height: 300,
          child: TreemapChart<String>(
            tree: TreemapNormalizer.normalize(_tree()),
            controller: controller,
            tiles: testTreemapTiles(),
            layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
            labels: TreemapWidgetLabels(
              builder: (_, details, _) =>
                  Text('${details.label}: ${details.weight}'),
            ),
            tooltip: TreemapTooltip(
              config: const TreemapTooltipConfig(
                activation: TreemapTooltipActivation.hover,
              ),
              builder: (_, details) =>
                  Text('Tooltip ${details.label}: ${details.weight}'),
            ),
            semantics: const TreemapSemantics(),
            interaction: TreemapInteractionConfig(onNodeTap: (_) {}),
            onPresentationChanged: (presentation) =>
                snapshot = presentation.targetSnapshot!,
          ),
        ),
      ),
    );
    expect(find.text('Group: 7.0'), findsOneWidget);
    expect(find.text('Alpha: 4.0'), findsNothing);
    expect(find.semantics.byLabel('Alpha'), findsNothing);
    final groupSemantics = find.semantics
        .byLabel('Group')
        .evaluate()
        .single
        .getSemanticsData();
    expect(groupSemantics.value, '7.0');
    expect(groupSemantics.hint, 'Level 2. Activate to drill down.');
    expect(groupSemantics.hasAction(SemanticsAction.tap), isTrue);
    expect(groupSemantics.hasAction(SemanticsAction.expand), isTrue);
    semantics.dispose();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(_centerOf(tester, snapshot, 'group'));
    await tester.pump();
    expect(find.text('Tooltip Group: 7.0'), findsOneWidget);
    await mouse.removePointer();
    await tester.tapAt(_centerOf(tester, snapshot, 'group'));
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('group'));
    expect(snapshot.nodes.single.key, const TreemapKey.source('subgroup'));
    expect(find.text('Subgroup: 7.0'), findsOneWidget);
    await tester.tapAt(_centerOf(tester, snapshot, 'subgroup'));
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('subgroup'));
    expect(find.text('Alpha: 4.0'), findsOneWidget);
    expect(find.text('Beta: 3.0'), findsOneWidget);
    await tester.tapAt(_centerOf(tester, snapshot, 'a'));
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('subgroup'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('group'));
    controller.zoomOut();
    await tester.pumpAndSettle();
    expect(find.text('Group: 7.0'), findsOneWidget);
  });

  testWidgets('keyboard activation drills into successive boundary branches', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    await tester.pumpTreemapApp(
      TreemapChart<String>(
        tree: TreemapNormalizer.normalize(_tree()),
        controller: controller,
        tiles: testTreemapTiles(),
        layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
        autofocus: true,
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('group'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('subgroup'));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('group'));
  });

  for (final transition in [null, TreemapTransitions.standard]) {
    testWidgets(
      'depth changes clear hidden targets and preserve focus/selection '
      '(animated: ${transition != null})',
      (tester) async {
        final controller = TreemapController<String>();
        final depth = ValueNotifier<int?>(null);
        addTearDown(controller.dispose);
        addTearDown(depth.dispose);
        final root = _tree();
        final tiles = _RecordingTiles();
        final hovered = <TreemapKey<String>?>[];
        await tester.pumpTreemapApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              height: 300,
              child: ValueListenableBuilder<int?>(
                valueListenable: depth,
                builder: (_, limit, _) => TreemapChart<String>(
                  tree: TreemapNormalizer.normalize(root),
                  controller: controller,
                  tiles: tiles,
                  layout: TreemapLayoutConfig(maxVisibleDepth: limit),
                  transition: transition,
                  interaction: TreemapInteractionConfig(
                    onHoverChanged: (details) => hovered.add(details?.key),
                  ),
                  tooltip: TreemapTooltip(
                    config: const TreemapTooltipConfig(
                      activation: TreemapTooltipActivation.hover,
                    ),
                    builder: (_, details) => Text('Tooltip ${details.label}'),
                  ),
                ),
              ),
            ),
          ),
        );
        controller.zoomTo('group');
        controller.select('a');
        await tester.pumpAndSettle();
        const key = TreemapKey.source('a');
        tiles.visual.actions.focus(key);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 500));
        await mouse.moveTo(
          _centerOf(tester, tiles.visual.presentation.displayedSnapshot!, 'a'),
        );
        await tester.pump();
        expect(tiles.visual.presentation.hoveredKey, key);
        expect(find.text('Tooltip Alpha'), findsOneWidget);
        expect(
          tiles.visual.presentation.statesFor(key),
          contains(TreemapVisualState.focused),
        );
        depth.value = 1;
        await tester.pump();
        expect(tiles.visual.presentation.hoveredKey, isNull);
        expect(hovered, [key, null]);
        expect(find.text('Tooltip Alpha'), findsNothing);
        await tester.pumpAndSettle();
        expect(controller.focusKey, const TreemapKey.source('group'));
        expect(controller.selectedEntries, contains(key));
        expect(
          tiles.visual.presentation.displayedSnapshot!.index.containsKey(key),
          isFalse,
        );
        depth.value = null;
        await tester.pumpAndSettle();
        expect(
          tiles.visual.presentation.displayedSnapshot!.index.containsKey(key),
          isTrue,
        );
        expect(
          tiles.visual.presentation.statesFor(key),
          contains(TreemapVisualState.selected),
        );
        expect(
          tiles.visual.presentation.statesFor(key),
          isNot(contains(TreemapVisualState.focused)),
        );
        expect(tiles.visual.presentation.hoveredKey, isNull);
        expect(find.text('Tooltip Alpha'), findsNothing);
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
      },
    );
  }

  testWidgets('depth changes preserve aggregate selection until data changes', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    final depth = ValueNotifier<int?>(2);
    addTearDown(controller.dispose);
    addTearDown(depth.dispose);
    var root = TreemapNode<String>(
      key: 'root',
      children: [
        TreemapNode(
          key: 'group',
          children: [
            TreemapNode(key: 'large', weight: 1000),
            TreemapNode(key: 'small-a', weight: 1),
            TreemapNode(key: 'small-b', weight: 1),
          ],
        ),
      ],
    );
    final tiles = _RecordingTiles();
    var tree = TreemapNormalizer.normalize(root);
    await tester.pumpTreemapApp(
      ValueListenableBuilder<int?>(
        valueListenable: depth,
        builder: (_, limit, _) => TreemapChart<String>(
          tree: tree,
          controller: controller,
          tiles: tiles,
          layout: TreemapLayoutConfig(
            maxVisibleDepth: limit,
            minimumWidth: 20,
            minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
            policy: const TreemapLayoutPolicy(
              rootRule: TreemapLayoutRule(
                algorithm: TreemapLayoutAlgorithm.dice,
              ),
            ),
          ),
        ),
      ),
    );
    final key = tiles.visual.presentation.displayedSnapshot!.nodes
        .singleWhere((node) => node.isAggregate)
        .key;
    controller.selectEntry(key);
    await tester.pumpAndSettle();
    depth.value = 1;
    await tester.pumpAndSettle();
    expect(
      tiles.visual.presentation.displayedSnapshot!.index.containsKey(key),
      isFalse,
    );
    expect(controller.selectedEntries, {key});
    depth.value = 2;
    await tester.pumpAndSettle();
    expect(
      tiles.visual.presentation.displayedSnapshot!.index.containsKey(key),
      isTrue,
    );
    expect(
      tiles.visual.presentation.statesFor(key),
      contains(TreemapVisualState.selected),
    );
    root = TreemapNode(
      key: 'root',
      children: [TreemapNode(key: 'replacement', weight: 1)],
    );
    tree = TreemapNormalizer.normalize(root);
    depth.value = null;
    await tester.pumpAndSettle();
    expect(controller.selectedEntries, isEmpty);
    expect(
      tiles.visual.presentation.displayedSnapshot!.nodes.single.key,
      const TreemapKey.source('replacement'),
    );
  });

  testWidgets('depth-limited branches respect disabled tap zoom', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    late TreemapGeometrySnapshot<String> snapshot;
    await tester.pumpTreemapApp(
      TreemapChart<String>(
        tree: TreemapNormalizer.normalize(_tree()),
        controller: controller,
        tiles: testTreemapTiles(),
        layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
        interaction: const TreemapInteractionConfig(zoomOnNodeTap: false),
        onPresentationChanged: (presentation) =>
            snapshot = presentation.targetSnapshot!,
      ),
    );
    await tester.tapAt(_centerOf(tester, snapshot, 'group'));
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('root'));
  });
}
