import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingTiles implements TreemapTileLayer<String> {
  TreemapVisualContext<String>? latest;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    latest = visual;
    return Stack(
      children: [
        for (final node in visual.visibleLeafNodes)
          Positioned(
            left: node.bounds.left,
            top: node.bounds.top,
            width: node.bounds.width,
            height: node.bounds.height,
            child: const ColoredBox(color: Color(0xFF123456)),
          ),
      ],
    );
  }
}

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'branch',
      label: 'Branch',
      children: [
        TreemapNode(key: 'a', label: 'Alpha', weight: 2),
        TreemapNode(key: 'b', label: 'Beta', weight: 1),
      ],
    ),
  ],
);

TreemapNode<String> _manyLeaves(int count) => TreemapNode(
  key: 'root',
  children: [
    for (var index = 0; index < count; index++)
      TreemapNode(key: 'leaf-$index', weight: 1),
  ],
);

void main() {
  testWidgets('core chart renders only the explicitly supplied tile layer', (
    tester,
  ) async {
    final tiles = _RecordingTiles();
    final chart = TreemapChart<String>(root: _tree(), tiles: tiles);

    expect(chart.labels, isNull);
    expect(chart.tooltip, isNull);
    expect(chart.surrounding, isNull);
    expect(chart.semantics, isNull);
    expect(chart.transition, isNull);
    expect(chart.clipBehavior, Clip.none);
    expect(chart.layout.minimumWidth, 0);
    expect(chart.layout.minimumHeight, 0);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 300, height: 200, child: chart),
        ),
      ),
    );

    expect(tiles.latest, isNotNull);
    expect(
      tiles.latest!.visibleLeafNodes.map((node) => node.key.sourceKey),
      unorderedEquals(['a', 'b']),
    );
    expect(find.byType(ColoredBox), findsNWidgets(2));
    expect(find.text('Alpha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit no-op layer supports a geometry-only chart', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 200,
            child: TreemapChart<String>(
              root: _tree(),
              tiles: const TreemapNoopTileLayer(),
              onSnapshot: (value) => snapshot = value,
            ),
          ),
        ),
      ),
    );

    expect(snapshot?.visibleNodes, isNotEmpty);
    expect(find.text('Alpha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget labels accept arbitrary clipped widgets', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 200,
            child: TreemapChart<String>(
              root: _tree(),
              tiles: const TreemapNoopTileLayer(),
              labels: TreemapWidgetLabels(
                builder: (context, details, states) => CustomPaint(
                  key: ValueKey('custom-${details.key.sourceKey}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('custom-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-b')), findsOneWidget);
    expect(find.byType(ClipRect), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout minimum dimensions reserve widget-label geometry', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              height: 80,
              child: TreemapChart<String>(
                root: _manyLeaves(12),
                tiles: const TreemapNoopTileLayer(),
                layout: TreemapLayoutConfig(
                  minimumWidth: 60,
                  minimumHeight: 30,
                  minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
                ),
                onSnapshot: (value) => snapshot = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(snapshot!.nodes.any((node) => node.isAggregate), isTrue);
    expect(tester.takeException(), isNull);
  });
}
