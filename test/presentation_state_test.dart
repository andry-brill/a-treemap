import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNode<String> _tree([double value = 30]) => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(
      key: 'a',
      children: [
        TreemapNode(key: 'x', weight: 10, color: 10),
        TreemapNode(key: 'y', weight: 30, color: value),
      ],
    ),
    TreemapNode(key: 'b', weight: 60),
  ],
);

final _scale = TreemapColorScale.interpolated(
  colors: const [Colors.black, Colors.white],
  fallback: Colors.pink,
  domainScope: TreemapColorDomainScope.visible,
  labelFormatter: (value) => '${value.round()}',
);

class _CaptureTiles implements TreemapTileLayer<String> {
  int builds = 0;
  late TreemapVisualContext<String> visual;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    builds++;
    this.visual = visual;
    return const SizedBox.expand();
  }
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'replacing surrounding composition preserves the displayed frame',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final root = _tree();
      final tiles = _CaptureTiles();
      final layout = TreemapLayoutConfig<String>(maxVisibleDepth: 1);
      Widget chart(bool surround) => _app(
        TreemapChart<String>(
          tree: TreemapNormalizer.normalize(root),
          controller: controller,
          tiles: tiles,
          layout: layout,
          transition: TreemapTransitions.standard,
          surrounding: surround ? const TreemapSurroundingGrid<String>() : null,
        ),
      );
      await tester.pumpWidget(chart(false));
      await tester.pumpAndSettle();
      controller.zoomTo('a');
      await tester.pumpAndSettle();
      final before = tiles.visual.presentation.displayedSnapshot!;
      expect(before.focusKey, const TreemapKey.source('a'));
      await tester.pumpWidget(chart(true));
      expect(
        tiles.visual.presentation.displayedSnapshot!.focusKey,
        before.focusKey,
      );
      expect(
        tiles.visual.presentation.displayedSnapshot!.nodes.map(
          (node) => node.key,
        ),
        before.nodes.map((node) => node.key),
      );
      expect(
        tiles
            .visual
            .presentation
            .displayedSnapshot!
            .index[const TreemapKey.source('x')]!
            .bounds,
        before.index[const TreemapKey.source('x')]!.bounds,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared scales stay independent across mounted charts', (
    tester,
  ) async {
    final left = _CaptureTiles();
    final right = _CaptureTiles();
    final secondRoot = TreemapNode<String>(
      key: 'root',
      children: [
        TreemapNode(key: 'x', weight: 100),
        TreemapNode(key: 'y', weight: 200),
      ],
    );
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            Expanded(
              child: TreemapChart<String>(
                tree: TreemapNormalizer.normalize(_tree()),
                tiles: left,
                surrounding: TreemapLegend(
                  scale: _scale,
                  config: const TreemapLegendConfig.bar(),
                ),
              ),
            ),
            Expanded(
              child: TreemapChart<String>(
                tree: TreemapNormalizer.normalize(secondRoot),
                tiles: right,
                surrounding: TreemapLegend(
                  scale: _scale,
                  config: const TreemapLegendConfig.bar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(left.visual.presentation.resolveColorScale(_scale).minimum, 10);
    expect(right.visual.presentation.resolveColorScale(_scale).minimum, 100);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(_scale.minimum, double.negativeInfinity);
  });

  testWidgets(
    'aggregate replacement hides stale hover without controller writes',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final tiles = _CaptureTiles();
      var notifications = 0;
      controller.addListener(() => notifications++);
      Future<void> show(double weight) async {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 600,
              height: 300,
              child: TreemapChart<String>(
                tree: TreemapNormalizer.normalize(
                  TreemapNode(
                    key: 'root',
                    children: [
                      TreemapNode(key: 'large', weight: 1000),
                      TreemapNode(key: 'small1', weight: 1),
                      TreemapNode(key: 'small2', weight: weight),
                    ],
                  ),
                ),
                controller: controller,
                tiles: tiles,
                layout: TreemapLayoutConfig(
                  minimumWidth: 20,
                  minimumHeight: 20,
                  minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(2);
      final aggregate = tiles
          .visual
          .presentation
          .displayedSnapshot!
          .visibleNodes
          .singleWhere((node) => node.isAggregate);
      tiles.visual.actions.hover(aggregate.key);
      await tester.pumpAndSettle();
      expect(tiles.visual.presentation.hoveredColor, 3);
      notifications = 0;
      await show(4);
      expect(tiles.visual.presentation.hoveredColor, isNull);
      expect(tiles.visual.presentation.hoveredKey, isNull);
      expect(notifications, 0);
      final replacement = tiles
          .visual
          .presentation
          .displayedSnapshot!
          .visibleNodes
          .singleWhere((node) => node.isAggregate);
      expect(replacement.key, isNot(aggregate.key));
      tiles.visual.actions.hover(replacement.key);
      await tester.pumpAndSettle();
      expect(tiles.visual.presentation.hoveredColor, 5);
      final state = tiles.visual.presentation;
      tiles.visual.actions.revealAggregate(replacement.key);
      await tester.pumpAndSettle();
      expect(tiles.visual.presentation.hoveredColor, isNull);
      expect(tiles.visual.presentation.resolveColorScale(_scale).maximum, 4);
      expect(
        state.hoveredColor,
        5,
      ); // Already delivered output stays immutable.
    },
  );

  testWidgets(
    'callback-driven host rebuilds settle without a presentation loop',
    (tester) async {
      final tree = TreemapNormalizer.normalize(_tree());
      var publications = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              return TreemapChart<String>(
                tree: tree,
                tiles: const TreemapNoopTileLayer(),
                layout: TreemapLayoutConfig(maxVisibleDepth: 1),
                onPresentationChanged: (_) => setState(() => publications++),
              );
            },
          ),
        ),
      );
      expect(await tester.pumpAndSettle(), lessThan(5));
      expect(publications, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('layout and presentation changes never notify the controller', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final tiles = _CaptureTiles();
    var root = _tree();
    Future<void> show(double width, int depth) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: width,
            height: 300,
            child: TreemapChart<String>(
              tree: TreemapNormalizer.normalize(root),
              controller: controller,
              tiles: tiles,
              layout: TreemapLayoutConfig(maxVisibleDepth: depth),
              surrounding: TreemapLegend(
                scale: _scale,
                config: const TreemapLegendConfig.bar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(600, 1);
    expect(tiles.visual.presentation.resolveColorScale(_scale).minimum, 40);
    await show(300, 2);
    expect(tiles.visual.presentation.resolveColorScale(_scale).minimum, 10);
    root = _tree(90);
    await show(300, 2);
    expect(tiles.visual.presentation.resolveColorScale(_scale).maximum, 90);
    expect(notifications, 0);
    controller.zoomTo('a');
    await tester.pumpAndSettle();
    expect(notifications, 1);
    expect(tiles.visual.presentation.resolveColorScale(_scale).maximum, 90);
  });

  testWidgets('scope updates chrome without rebuilding chart computation', (
    tester,
  ) async {
    final tiles = _CaptureTiles();
    await tester.pumpWidget(
      _app(
        TreemapChart<String>(
          tree: TreemapNormalizer.normalize(_tree()),
          tiles: tiles,
          layout: TreemapLayoutConfig(maxVisibleDepth: 1),
          surrounding: TreemapSurroundingGrid(
            topCenter: TreemapSurroundingContent.builder(
              builder: (context, controller) {
                final state = TreemapPresentationScope.of<String>(context);
                final scale = state.resolveColorScale(_scale);
                return SizedBox(
                  height: 30,
                  child: Text('domain ${scale.minimum} ${scale.maximum}'),
                );
              },
            ),
          ),
        ),
      ),
    );
    final buildsAfterLayout = tiles.builds;
    await tester.pumpAndSettle();
    expect(find.text('domain 40.0 60.0'), findsOneWidget);
    expect(tiles.builds, buildsAfterLayout);
    expect(
      tiles.visual.presentation.displayedSnapshot,
      same(tiles.visual.presentation.displayedSnapshot!),
    );
  });

  testWidgets(
    'external legend receives immutable output and destination bounds during animation',
    (tester) async {
      final controller = TreemapController<String>();
      final output = ValueNotifier<TreemapPresentationState<String>?>(null);
      addTearDown(controller.dispose);
      addTearDown(output.dispose);
      final tiles = _CaptureTiles();
      var notifications = 0;
      controller.addListener(() => notifications++);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Expanded(
                child: TreemapChart<String>(
                  tree: TreemapNormalizer.normalize(_tree()),
                  controller: controller,
                  tiles: tiles,
                  layout: TreemapLayoutConfig(maxVisibleDepth: 1),
                  transition: TreemapTransitions.standard,
                  onPresentationChanged: (state) => output.value = state,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: output,
                builder: (context, state, _) => TreemapLegendView<String>(
                  scale: state == null
                      ? _scale.resolveDomain(const [])
                      : _scale,
                  presentation: state,
                  config: const TreemapLegendConfig.bar(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = output.value!;
      expect(before.resolveColorScale(_scale).minimum, 40);
      expect(find.text('40'), findsOneWidget);
      controller.zoomTo('a');
      await tester.pump();
      final destination = output.value!;
      expect(destination.resolveColorScale(_scale).minimum, 10);
      expect(destination.resolveColorScale(_scale).maximum, 30);
      await tester.pump(const Duration(milliseconds: 100));
      expect(output.value!.resolveColorScale(_scale).maximum, 30);
      expect(output.value!.targetSnapshot, same(destination.targetSnapshot));
      expect(
        output.value!.displayedSnapshot,
        isNot(same(destination.displayedSnapshot)),
      );
      expect(before.resolveColorScale(_scale).minimum, 40);
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(notifications, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement controllers and removal cannot receive stale publication',
    (tester) async {
      final first = TreemapController<String>();
      final second = TreemapController<String>();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final root = _tree();
      final tiles = _CaptureTiles();
      final publications = <TreemapPresentationState<String>>[];
      Widget chart(TreemapController<String> controller) => _app(
        TreemapChart<String>(
          tree: TreemapNormalizer.normalize(root),
          controller: controller,
          tiles: tiles,
          onPresentationChanged: publications.add,
        ),
      );
      await tester.pumpWidget(chart(first));
      await tester.pumpAndSettle();
      second.synchronize(TreemapNormalizer.normalize(root));
      second.zoomTo('a');
      await tester.pumpWidget(chart(second));
      await tester.pumpAndSettle();
      expect(
        publications.last.targetSnapshot!.focusKey,
        const TreemapKey.source('a'),
      );
      final count = publications.length;
      first.zoomTo('a');
      await tester.pumpAndSettle();
      expect(publications.length, count);
      await tester.pumpWidget(const SizedBox());
      second.reset();
      await tester.pumpAndSettle();
      expect(publications.length, count);
      expect(tester.takeException(), isNull);
    },
  );
}
