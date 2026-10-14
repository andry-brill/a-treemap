import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapNormalizedTree<String> _tree({
  double color = 10,
  bool includeTen = true,
}) => TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    color: -1000,
    children: [
      TreemapNode(
        key: 'a',
        label: 'A',
        children: [
          if (includeTen)
            TreemapNode(key: 'ten', label: 'Ten', weight: 10, color: color),
          TreemapNode(key: 'thirty', label: 'Thirty', weight: 30),
        ],
      ),
      TreemapNode(key: 'b', label: 'B', weight: 60),
    ],
  ),
);

final _scale = TreemapColorScale.interpolated(
  colors: const [Colors.blue, Colors.red],
  fallback: Colors.grey,
  domainScope: TreemapColorDomainScope.visible,
);

final class _Capture implements TreemapTileLayer<String> {
  _Capture([this.delegate]);
  final TreemapTileLayer<String>? delegate;
  late TreemapVisualContext<String> visual;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return delegate?.build(context, visual) ?? const SizedBox.expand();
  }
}

final class _CountingLayout implements ITreemapLayoutStrategy<String> {
  int calls = 0;
  @override
  Map<TreemapKey<String>, TreemapBounds> layout(
    TreemapStrategyInput<String> input,
  ) {
    calls++;
    final total = input.items.fold<double>(0, (sum, item) => sum + item.weight);
    var left = input.bounds.left;
    return {
      for (final item in input.items)
        item.key: (() {
          final width = input.bounds.width * item.weight / total;
          final bounds = TreemapBounds.fromLTWH(
            left,
            input.bounds.top,
            width,
            input.bounds.height,
          );
          left += width;
          return bounds;
        })(),
    };
  }
}

final class _ThemedTiles implements TreemapTileLayer<String> {
  _ThemedTiles(this.resolver);
  final TreemapAppearanceResolver<String> resolver;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) =>
      Row(
        children: [
          for (final brightness in Brightness.values)
            Expanded(
              child: Theme(
                data: ThemeData(brightness: brightness),
                child: Builder(
                  builder: (context) {
                    final appearance = visual
                        .resolveAppearances(context, resolver)
                        .values
                        .first;
                    return ColoredBox(
                      key: ValueKey(brightness),
                      color: appearance.color!,
                    );
                  },
                ),
              ),
            ),
        ],
      );
}

final class _LiveThemedTiles implements TreemapTileLayer<String> {
  _LiveThemedTiles(this.brightness, this.resolver);
  final ValueNotifier<Brightness> brightness;
  final TreemapAppearanceResolver<String> resolver;
  int builds = 0;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    builds++;
    return ValueListenableBuilder(
      valueListenable: brightness,
      child: Builder(
        builder: (context) {
          final appearances = visual.resolveAppearances(context, resolver);
          expect(
            visual.resolveAppearances(context, resolver),
            same(appearances),
          );
          return ColoredBox(
            key: const ValueKey('live-theme-tile'),
            color: appearances.values.first.color!,
          );
        },
      ),
      builder: (context, brightness, child) => Theme(
        data: ThemeData(brightness: brightness),
        child: child!,
      ),
    );
  }
}

void main() {
  test('preparation caches finite numeric extrema and immutable indexes', () {
    final tree = _tree();
    expect(tree.globalColorDomain, (10, 60));
    expect(tree.totals['a'], 40);
    expect(() => tree.totals['a'] = 900, throwsUnsupportedError);
    final first = TreemapLayoutEngine<String>().layout(
      tree: tree,
      viewport: const TreemapBounds.fromLTWH(0, 0, 600, 400),
    );
    final second = TreemapLayoutEngine<String>().layout(
      tree: tree,
      viewport: const TreemapBounds.fromLTWH(0, 0, 300, 200),
    );
    expect(
      first.index[const TreemapKey.source('ten')]!.node,
      same(tree.nodes['ten']),
    );
    expect(second.index[const TreemapKey.source('a')]!.weight, 40);
    final excluded = TreemapNormalizer.normalize(
      TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(key: 'nan', weight: 1, color: double.nan),
          TreemapNode(key: 'infinity', weight: 2, color: double.infinity),
          TreemapNode(key: 'direct', weight: 3, color: Colors.green),
          TreemapNode(key: 'text', weight: 4, color: 'category'),
        ],
      ),
    );
    expect(excluded.globalColorDomain, isNull);
  });

  test(
    'empty destination preserves focused navigation and suppresses hover',
    () {
      final tree = _tree();
      final snapshot = TreemapLayoutEngine<String>().layout(
        tree: tree,
        viewport: const TreemapBounds.fromLTWH(0, 0, 0, 400),
        focus: TreemapFocus.source('a'),
      );
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.focusKey, const TreemapKey.source('a'));
      final state = TreemapPresentationState.fromData(
        tree: tree,
        targetSnapshot: snapshot,
        hoveredKey: const TreemapKey.source('ten'),
      );
      expect(state.currentPath.map((entry) => entry.key.sourceKey), [
        'root',
        'a',
      ]);
      expect(state.canZoomOut, isTrue);
      expect(state.hoveredColor, isNull);
      expect(state.resolveColorScale(_scale).legendEntries, isEmpty);
    },
  );

  testWidgets(
    'interaction and styling reuse target geometry and cached domains',
    (tester) async {
      final tree = _tree();
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final strategy = _CountingLayout();
      final tiles = _Capture();
      var notifications = 0;
      controller.addListener(() => notifications++);
      Widget chart(Color background) => TreemapChart<String>(
        tree: tree,
        controller: controller,
        tiles: tiles,
        layout: TreemapLayoutConfig(
          policy: TreemapLayoutPolicy(
            rootRule: TreemapLayoutRule(strategy: strategy),
          ),
        ),
        labels: TreemapWidgetLabels(
          builder: (_, details, states) => ColoredBox(color: background),
        ),
      );
      await tester.pumpTreemapApp(chart(Colors.white));
      await tester.pumpAndSettle();
      final before = tiles.visual.presentation;
      final calls = strategy.calls;
      final scale = before.resolveColorScale(_scale);
      tiles.visual.actions.hover(const TreemapKey.source('ten'));
      tiles.visual.actions.focus(const TreemapKey.source('ten'));
      await tester.pumpAndSettle();
      expect(notifications, 0);
      expect(strategy.calls, calls);
      expect(
        tiles.visual.presentation.targetSnapshot,
        same(before.targetSnapshot),
      );
      expect(
        tiles.visual.presentation.targetDetails,
        same(before.targetDetails),
      );
      expect(tiles.visual.presentation.resolveColorScale(_scale), same(scale));
      tiles.visual.actions.select(const TreemapKey.source('ten'));
      await tester.pumpAndSettle();
      expect(notifications, 1);
      expect(strategy.calls, calls);
      expect(tiles.visual.presentation.selectedEntries, {
        const TreemapKey.source('ten'),
      });
      await tester.pumpTreemapApp(chart(Colors.yellow));
      await tester.pumpAndSettle();
      expect(strategy.calls, calls);
      expect(
        tiles.visual.presentation.hoveredKey,
        const TreemapKey.source('ten'),
      );
      expect(
        tiles.visual.presentation.keyboardFocusedKey,
        const TreemapKey.source('ten'),
      );
    },
  );

  testWidgets(
    'tiles and canvas labels share one appearance calculation per frame',
    (tester) async {
      var resolutions = 0;
      final appearance = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        nodeStyleResolver: (_, details, states) {
          resolutions++;
          return null;
        },
      );
      final tiles = _Capture(TreemapTiles(appearance: appearance));
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree(),
          tiles: tiles,
          labels: TreemapCanvasLabels(appearance: appearance),
        ),
      );
      await tester.pumpAndSettle();
      final count = tiles.visual.presentation.details.length;
      expect(resolutions, count);
      tiles.visual.actions.hover(const TreemapKey.source('ten'));
      await tester.pumpAndSettle();
      expect(resolutions, 2 * count);
    },
  );

  testWidgets('appearance sharing respects distinct inherited environments', (
    tester,
  ) async {
    final resolver = TreemapAppearanceResolver<String>(
      colorScale: _scale,
      nodeStyleResolver: (context, details, states) => TreemapAppearance(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
      ),
    );
    await tester.pumpTreemapApp(
      TreemapChart<String>(tree: _tree(), tiles: _ThemedTiles(resolver)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ColoredBox>(find.byKey(const ValueKey(Brightness.dark)))
          .color,
      Colors.black,
    );
    expect(
      tester
          .widget<ColoredBox>(find.byKey(const ValueKey(Brightness.light)))
          .color,
      Colors.white,
    );
  });

  testWidgets(
    'retained visual contexts refresh appearances after theme changes',
    (tester) async {
      final brightness = ValueNotifier(Brightness.light);
      addTearDown(brightness.dispose);
      var resolutions = 0;
      final resolver = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        nodeStyleResolver: (context, details, states) {
          resolutions++;
          return TreemapAppearance(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          );
        },
      );
      final layer = _LiveThemedTiles(brightness, resolver);
      final tiles = _Capture(layer);
      await tester.pumpTreemapApp(
        TreemapChart<String>(tree: _tree(), tiles: tiles),
      );
      await tester.pumpAndSettle();
      final visual = tiles.visual;
      final count = visual.presentation.details.length;
      expect(resolutions, count);
      final builds = layer.builds;
      for (final value in [Brightness.dark, Brightness.light]) {
        brightness.value = value;
        // Consecutive frames need not advance the test clock to invalidate caches.
        await tester.pump();
        expect(tiles.visual, same(visual));
        expect(layer.builds, builds);
        expect(
          tester
              .widget<ColoredBox>(find.byKey(const ValueKey('live-theme-tile')))
              .color,
          value == Brightness.dark ? Colors.black : Colors.white,
        );
      }
      expect(resolutions, 3 * count);
    },
  );

  testWidgets('aggregate source updates publish refreshed breadcrumb paths', (
    tester,
  ) async {
    var tree = _tree();
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final tiles = _Capture();
    TreemapPresentationState<String>? output;
    Widget chart() => TreemapChart<String>(
      tree: tree,
      controller: controller,
      tiles: tiles,
      onPresentationChanged: (state) => output = state,
    );
    await tester.pumpTreemapApp(chart());
    controller.zoomTo('a');
    const aggregate = TreemapKey<String>.aggregate(
      aggregateParent: TreemapKey.source('a'),
      aggregateSignature: 42,
    );
    controller.revealAggregate(aggregate, memberKeys: ['ten', 'thirty']);
    await tester.pumpAndSettle();
    final old = output!;
    var notifications = 0;
    controller.addListener(() => notifications++);
    tree = TreemapNormalizer.normalize(
      tree.root.copyWith(
        children: [
          tree.nodes['a']!.copyWith(label: 'Updated A'),
          tree.nodes['b']!,
        ],
      ),
    );
    await tester.pumpTreemapApp(chart());
    await tester.pumpAndSettle();
    expect(output, same(tiles.visual.presentation));
    expect(output!.currentPath[1].label, 'Updated A');
    expect(output!.targetSnapshot!.path[1].label, 'Updated A');
    expect(old.currentPath[1].label, 'A');
    expect(notifications, 0);
    expect(controller.zoomOut().succeeded, isTrue);
    await tester.pumpAndSettle();
    expect(output!.focusKey, const TreemapKey.source('a'));
  });

  testWidgets(
    'observer interaction supersedes a pending visibility-clear effect',
    (tester) async {
      final tiles = _Capture();
      final hovers = <TreemapKey<String>?>[];
      var tree = _tree();
      var rehover = false;
      Widget chart() => TreemapChart<String>(
        tree: tree,
        tiles: tiles,
        interaction: TreemapInteractionConfig(
          onHoverChanged: (details) => hovers.add(details?.key),
        ),
        onPresentationChanged: (state) {
          if (rehover && state.hoveredKey == null) {
            rehover = false;
            tiles.visual.actions.hover(const TreemapKey.source('thirty'));
          }
        },
      );
      await tester.pumpTreemapApp(chart());
      await tester.pumpAndSettle();
      tiles.visual.actions.hover(const TreemapKey.source('ten'));
      await tester.pumpAndSettle();
      tree = _tree(includeTen: false);
      rehover = true;
      await tester.pumpTreemapApp(chart());
      await tester.pumpAndSettle();
      expect(hovers, [
        const TreemapKey.source('ten'),
        const TreemapKey.source('thirty'),
      ]);
      expect(
        tiles.visual.presentation.hoveredKey,
        const TreemapKey.source('thirty'),
      );
    },
  );

  testWidgets(
    'publication coalesces commands and delivers the painted immutable value after frame',
    (tester) async {
      final tiles = _Capture();
      final states = <TreemapPresentationState<String>>[];
      final phases = <SchedulerPhase>[];
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree(),
          tiles: tiles,
          onPresentationChanged: (state) {
            states.add(state);
            phases.add(SchedulerBinding.instance.schedulerPhase);
          },
        ),
      );
      await tester.pumpAndSettle();
      final initial = states.single;
      tiles.visual.actions.hover(const TreemapKey.source('ten'));
      tiles.visual.actions.hover(const TreemapKey.source('thirty'));
      tiles.visual.actions.focus(const TreemapKey.source('thirty'));
      expect(states, hasLength(1));
      await tester.pumpAndSettle();
      expect(states, hasLength(2));
      expect(states.last, same(tiles.visual.presentation));
      expect(states.last.hoveredColor, 30);
      expect(initial.hoveredKey, isNull);
      expect(phases, everyElement(SchedulerPhase.postFrameCallbacks));
      expect(
        () => states.last.selectedEntries.add(const TreemapKey.source('b')),
        throwsUnsupportedError,
      );
      final actions = tiles.visual.actions;
      await tester.pumpWidget(const SizedBox());
      actions.hover(const TreemapKey.source('b'));
      actions.activate(const TreemapKey.source('b'));
      expect(actions.reset().status, TreemapCommandStatus.unchanged);
      await tester.pump();
      expect(states, hasLength(2));
    },
  );

  for (final change in ['resize', 'source', 'zoom', 'disabled']) {
    testWidgets(
      '$change invalidates transient targets without controller feedback or resurrection',
      (tester) async {
        var tree = _tree();
        final controller = TreemapController<String>();
        addTearDown(controller.dispose);
        final tiles = _Capture();
        final hovers = <TreemapKey<String>?>[];
        var notifications = 0;
        controller.addListener(() => notifications++);
        Future<void> show({
          double width = 600,
          bool enabled = true,
          bool cull = false,
        }) async {
          await tester.pumpTreemapApp(
            SizedBox(
              width: width,
              height: 400,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 400,
                  child: TreemapChart<String>(
                    tree: tree,
                    controller: controller,
                    tiles: tiles,
                    layout: TreemapLayoutConfig(
                      minimumWidth: cull ? 150 : 0,
                      minimumNodePolicy: TreemapMinimumNodePolicy.hide,
                      policy: const TreemapLayoutPolicy(
                        rootRule: TreemapLayoutRule(
                          algorithm: TreemapLayoutAlgorithm.dice,
                        ),
                      ),
                    ),
                    interaction: TreemapInteractionConfig(
                      enabled: enabled,
                      zoomOnNodeTap: false,
                      onHoverChanged: (details) => hovers.add(details?.key),
                    ),
                    tooltip: TreemapTooltip(
                      config: const TreemapTooltipConfig(
                        activation: TreemapTooltipActivation.tap,
                        hideDelay: Duration(seconds: 1),
                      ),
                      builder: (_, details) => Text('Tooltip ${details.key}'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show();
        final key = TreemapKey<String>.source(change == 'zoom' ? 'a' : 'ten');
        tiles.visual.actions.hover(key);
        tiles.visual.actions.focus(key);
        tiles.visual.actions.activate(key);
        await tester.pump();
        expect(tiles.visual.presentation.tooltipKey, key);
        final before = notifications;
        switch (change) {
          case 'resize':
            await show(width: 300, cull: true);
          case 'source':
            tree = _tree(includeTen: false);
            await show();
          case 'zoom':
            controller.zoomTo('a');
            await tester.pump();
          case 'disabled':
            await show(enabled: false);
        }
        expect(tiles.visual.presentation.hoveredKey, isNull);
        expect(tiles.visual.presentation.keyboardFocusedKey, isNull);
        expect(tiles.visual.presentation.tooltipKey, isNull);
        expect(notifications, before + (change == 'zoom' ? 1 : 0));
        expect(hovers, [key, null]);
        tree = _tree();
        controller.reset();
        await show();
        expect(tiles.visual.presentation.hoveredKey, isNull);
        expect(tiles.visual.presentation.keyboardFocusedKey, isNull);
        expect(tiles.visual.presentation.tooltipKey, isNull);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'controlled missing selection falls back once without controller writes',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final tiles = _Capture();
      final proposals = <Set<TreemapKey<String>>>[];
      var tree = _tree();
      Widget chart() => TreemapChart<String>(
        tree: tree,
        controller: controller,
        tiles: tiles,
        selection: TreemapSelectionConfig(
          selected: {const TreemapKey.source('ten')},
          fallbackToNearestAncestor: true,
        ),
        interaction: TreemapInteractionConfig(
          onSelectionChanged: (selection, _) => proposals.add(selection),
        ),
      );
      await tester.pumpTreemapApp(chart());
      await tester.pumpAndSettle();
      expect(tiles.visual.presentation.selectedEntries, {
        const TreemapKey.source('ten'),
      });
      tree = _tree(includeTen: false);
      await tester.pumpTreemapApp(chart());
      await tester.pumpAndSettle();
      expect(tiles.visual.presentation.selectedEntries, {
        const TreemapKey.source('a'),
      });
      expect(proposals, [
        {const TreemapKey.source('a')},
      ]);
      expect(controller.selectedEntries, isEmpty);
      await tester.pumpTreemapApp(chart());
      await tester.pumpAndSettle();
      expect(proposals, hasLength(1));
      expect(tiles.visual.presentation.selectedEntries, {
        const TreemapKey.source('a'),
      });
    },
  );

  testWidgets(
    'source color updates replace metadata without starting a geometry transition',
    (tester) async {
      final tiles = _Capture();
      Future<void> show(double color) async {
        await tester.pumpTreemapApp(
          TreemapChart<String>(
            tree: _tree(color: color),
            tiles: tiles,
            transition: TreemapTransitions.standard,
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(10);
      tiles.visual.actions.hover(const TreemapKey.source('ten'));
      await tester.pump();
      final previous = tiles.visual.presentation;
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree(color: 50),
          tiles: tiles,
          transition: TreemapTransitions.standard,
        ),
      );
      expect(tiles.visual.presentation.isAnimating, isFalse);
      expect(tiles.visual.presentation.hoveredColor, 50);
      expect(
        tiles
            .visual
            .presentation
            .targetDetails[const TreemapKey.source('ten')]!
            .color,
        50,
      );
      expect(previous.hoveredColor, 10);
      expect(
        tiles
            .visual
            .presentation
            .targetSnapshot!
            .index[const TreemapKey.source('ten')]!
            .bounds,
        previous.targetSnapshot!.index[const TreemapKey.source('ten')]!.bounds,
      );
    },
  );

  testWidgets('long press cancels when source changes during the gesture', (
    tester,
  ) async {
    final tiles = _Capture();
    var longPresses = 0;
    Future<void> show(TreemapNormalizedTree<String> tree) =>
        tester.pumpTreemapApp(
          TreemapChart<String>(
            tree: tree,
            tiles: tiles,
            interaction: TreemapInteractionConfig(
              longPressDuration: const Duration(milliseconds: 200),
              onNodeLongPress: (_) => longPresses++,
            ),
          ),
        );
    await show(_tree());
    final bounds = tiles
        .visual
        .presentation
        .targetSnapshot!
        .index[const TreemapKey.source('ten')]!
        .bounds;
    final position =
        tester.getTopLeft(find.byType(TreemapChart<String>)) +
        Offset(bounds.centerX, bounds.centerY);
    final gesture = await tester.startGesture(position);
    await show(_tree(color: 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(longPresses, 0);
    await gesture.up();
  });
}
