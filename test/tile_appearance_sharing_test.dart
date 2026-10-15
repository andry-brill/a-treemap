import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _parent = TreemapKey.source('parent');
final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [
      TreemapNode(
        key: 'parent',
        label: 'Parent',
        children: [TreemapNode(key: 'child', label: 'Child', weight: 1)],
      ),
    ],
  ),
);
final _scale = TreemapColorScale.exact({}, fallback: Colors.white);

final class _CaptureTiles implements TreemapTileLayer<String> {
  _CaptureTiles(this.appearance, {this.beforeTiles});
  @override
  final TreemapAppearanceResolver<String> appearance;
  final void Function(BuildContext, TreemapVisualContext<String>)? beforeTiles;
  late TreemapVisualContext<String> visual;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    beforeTiles?.call(context, visual);
    return TreemapTiles(appearance: appearance).build(context, visual);
  }
}

TreemapCanvasLabelPainter<String> _labels(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapCanvasLabelPainter<String>>()
    .single;
TreemapTilePainter<String> _tiles(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapTilePainter<String>>()
    .single;

void main() {
  testWidgets(
    'invisible sources remain optional and are resolved only by consumers',
    (tester) async {
      const emptyTiles = TreemapNoopTileLayer<String>();
      expect(emptyTiles.appearance, isNull);
      var resolutions = 0;
      final appearance = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        nodeStyleResolver: (_, _, _) {
          resolutions++;
          return null;
        },
      );
      for (final tiles in [
        emptyTiles,
        TreemapNoopTileLayer<String>(appearance: appearance),
      ]) {
        for (final widgets in [false, true]) {
          await tester.pumpTreemapApp(
            TreemapChart<String>(
              tree: _tree,
              tiles: tiles,
              labels: widgets
                  ? TreemapWidgetLabels<String>(
                      builder: (_, details, _) => Text(details.label!),
                    )
                  : null,
            ),
          );
          await tester.pumpAndSettle();
          expect(resolutions, 0);
          expect(find.text('Child'), widgets ? findsOneWidget : findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('the same canvas labels follow invisible tile source changes', (
    tester,
  ) async {
    final labels = TreemapCanvasLabels<String>(
      parentLabels: const TreemapParentLabelConfig(),
    );
    TreemapGeometrySnapshot<String>? target;
    Future<void> show(Color color) async {
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree,
          tiles: TreemapNoopTileLayer(
            appearance: TreemapAppearanceResolver<String>(
              colorScale: TreemapColorScale.exact({}, fallback: color),
            ),
          ),
          labels: labels,
          onPresentationChanged: (state) => target = state.targetSnapshot,
        ),
      );
      await tester.pumpAndSettle();
      final painter = _labels(tester);
      expect(painter.appearances[_parent]!.color, color);
      expect(
        painter.config
            .resolveLines(
              painter.details[_parent]!,
              painter.appearances[_parent]!,
              null,
              styles: painter.styles[_parent]!,
            )
            .first
            .style
            .color,
        treemapContrastingTextColor(color),
      );
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<TreemapTilePainter<String>>(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    }

    await show(Colors.white);
    final initial = target;
    expect(initial!.index[_parent]!.headerBounds, isNotNull);
    await show(Colors.black);
    expect(target, same(initial));
  });

  testWidgets(
    'declared backgrounds are shared before tile build and update with states',
    (tester) async {
      var resolutions = 0;
      final appearance = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        style: const TreemapStyle(
          selectedAppearance: TreemapAppearance(color: Colors.black),
        ),
        nodeStyleResolver: (_, _, _) {
          resolutions++;
          return null;
        },
      );
      Map<TreemapKey<String>, TreemapAppearance>? before;
      final tiles = _CaptureTiles(
        appearance,
        beforeTiles: (context, visual) {
          before = visual.resolveTileAppearances(context);
        },
      );
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree,
          tiles: tiles,
          labels: TreemapCanvasLabels(
            parentLabels: const TreemapParentLabelConfig(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_labels(tester).appearances, same(_tiles(tester).appearances));
      expect(_labels(tester).appearances, same(before));
      expect(() => before!.clear(), throwsUnsupportedError);
      final count = tiles.visual.presentation.details.length;
      expect(resolutions, count);
      final geometry = tiles.visual.presentation.targetSnapshot;
      tiles.visual.actions.select(_parent);
      await tester.pumpAndSettle();
      expect(_labels(tester).appearances, same(_tiles(tester).appearances));
      expect(_labels(tester).appearances[_parent]!.color, Colors.black);
      expect(resolutions, 2 * count);
      expect(tiles.visual.presentation.targetSnapshot, same(geometry));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tile source changes and inherited themes refresh shared appearance without layout',
    (tester) async {
      var appearance = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        nodeStyleResolver: (context, _, _) =>
            TreemapAppearance(color: Theme.of(context).primaryColor),
      );
      late _CaptureTiles tiles;
      Future<void> show(Color color) async {
        tiles = _CaptureTiles(appearance);
        await tester.pumpTreemapApp(
          TreemapChart<String>(
            tree: _tree,
            tiles: tiles,
            labels: TreemapCanvasLabels(),
          ),
          theme: ThemeData(primaryColor: color),
        );
        await tester.pumpAndSettle();
      }

      await show(Colors.red);
      final target = tiles.visual.presentation.targetSnapshot;
      expect(_labels(tester).appearances.values.first.color, Colors.red);
      await show(Colors.green);
      expect(_labels(tester).appearances.values.first.color, Colors.green);
      expect(_labels(tester).appearances, same(_tiles(tester).appearances));
      expect(tiles.visual.presentation.targetSnapshot, same(target));
      appearance = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        style: const TreemapStyle(
          tileAppearance: TreemapAppearance(color: Colors.blue),
        ),
      );
      await show(Colors.green);
      expect(_labels(tester).appearances.values.first.color, Colors.blue);
      expect(tiles.visual.presentation.targetSnapshot, same(target));
    },
  );

  testWidgets(
    'invisible tiles own the background supplied to custom canvas lines',
    (tester) async {
      final appearance = TreemapAppearanceResolver<String>(colorScale: _scale);
      var calls = 0;
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree,
          tiles: TreemapNoopTileLayer(appearance: appearance),
          labels: TreemapCanvasLabels(
            config: TreemapLabelConfig(
              linesBuilder: (_, appearance, _, styles) {
                calls++;
                expect(appearance.color, Colors.white);
                return [
                  TreemapCanvasLabelLine(
                    text: 'Custom',
                    style: styles.titleStyle!,
                  ),
                ];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, greaterThan(0));
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<TreemapTilePainter<String>>(),
        isEmpty,
      );
      expect(_labels(tester).appearances.values.first.color, Colors.white);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['invisible', 'widgets', 'composite']) {
    testWidgets('$kind tiles without a source report an actionable error', (
      tester,
    ) async {
      final TreemapTileLayer<String> tiles = switch (kind) {
        'widgets' => TreemapBuilderTileLayer(
          builder: (_, _, _) => const SizedBox(),
        ),
        'composite' => TreemapCompositeTileLayer([
          TreemapTiles(
            appearance: TreemapAppearanceResolver(colorScale: _scale),
          ),
        ]),
        _ => const TreemapNoopTileLayer(),
      };
      await tester.pumpTreemapApp(
        TreemapChart<String>(
          tree: _tree,
          tiles: tiles,
          labels: TreemapCanvasLabels(),
        ),
      );
      expect(
        tester.takeException().toString(),
        contains('No tile appearance source'),
      );
    });
  }

  testWidgets(
    'widget and composite declarations supply labels without changing tile paints',
    (tester) async {
      final white = TreemapAppearanceResolver<String>(colorScale: _scale);
      final red = TreemapAppearanceResolver<String>(
        colorScale: _scale,
        style: const TreemapStyle(
          tileAppearance: TreemapAppearance(color: Colors.red),
        ),
      );
      for (final tiles in <TreemapTileLayer<String>>[
        TreemapBuilderTileLayer(
          appearance: white,
          builder: (_, _, _) => const ColoredBox(color: Colors.white),
        ),
        TreemapCompositeTileLayer([
          TreemapTiles(appearance: red),
        ], appearance: white),
      ]) {
        await tester.pumpTreemapApp(
          TreemapChart<String>(
            tree: _tree,
            tiles: tiles,
            labels: TreemapCanvasLabels(),
          ),
        );
        await tester.pumpAndSettle();
        expect(_labels(tester).appearances.values.first.color, Colors.white);
        if (tiles is TreemapCompositeTileLayer<String>) {
          expect(_tiles(tester).appearances.values.first.color, Colors.red);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'standalone labels can build before tiles with an explicit context source',
    (tester) async {
      final appearance = TreemapAppearanceResolver<String>(colorScale: _scale);
      final tiles = _CaptureTiles(appearance);
      await tester.pumpTreemapApp(
        TreemapChart<String>(tree: _tree, tiles: tiles),
      );
      await tester.pumpAndSettle();
      final prior = tiles.visual;
      await tester.pumpTreemapApp(
        Builder(
          builder: (context) {
            final tileLayer = TreemapTiles<String>(appearance: appearance);
            final visual = TreemapVisualContext<String>(
              presentation: prior.presentation,
              actions: prior.actions,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              tileAppearance: tileLayer.appearance,
            );
            final labels = TreemapCanvasLabels<String>().build(context, visual);
            final tiles = tileLayer.build(context, visual);
            return Stack(
              children: [
                Positioned.fill(child: tiles),
                Positioned.fill(child: labels),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(_labels(tester).appearances, same(_tiles(tester).appearances));
      expect(tester.takeException(), isNull);
    },
  );
}
