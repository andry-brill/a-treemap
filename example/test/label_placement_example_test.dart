import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/centered_text_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  const ids = [
    'appearance-centered-full-tile',
    'appearance-centered-footer',
    'appearance-centered-widget-header',
    'appearance-centered-parent-headers',
  ];
  test('shared placement scenarios and controls round-trip URLs', () {
    for (final id in ids) {
      final config = presetsByKey[id]!.config;
      expect(
        PlaygroundLocationCodec.decode(
          PlaygroundLocation(config: config).uri,
        ).config,
        config,
      );
    }
    final config = presetsByKey[ids.first]!.config.withValues({
      'labels.reservation': 'bottom',
      'labels.reservedHeight': 48,
      'tiles.centered.region': 'available',
      'tiles.centeredText.region': 'tile',
    });
    expect(
      PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: config).uri,
      ).config,
      config,
    );
  });

  for (final id in ids) {
    for (final surface in [const Size(1000, 700), const Size(360, 700)]) {
      testWidgets('$id shares available bounds at ${surface.width} px', (
        tester,
      ) async {
        final config = presetsByKey[id]!.config.withValues({
          'animation.enabled': false,
          'preview.showHierarchy': false,
        });
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
          surfaceSize: surface,
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<TreemapChart<String>>(
          find.byType(TreemapChart<String>),
        );
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .toList();
        final snapshot = painters
            .whereType<TreemapTilePainter<String>>()
            .single
            .snapshot;
        final text = painters
            .whereType<TreemapCenteredTextPainter<String>>()
            .firstOrNull;
        final labels = painters
            .whereType<TreemapCanvasLabelPainter<String>>()
            .firstOrNull;
        final layers =
            (chart.tiles as TreemapCompositeTileLayer<String>).layers;
        final widgetLayer = layers
            .whereType<TreemapCenteredWidgetLayer<String>>()
            .single;
        final origin = tester.getTopLeft(find.byType(TreemapChart<String>));
        final parents = snapshot.visibleNodes
            .map((node) => node.parentKey)
            .toSet();
        final leaves = snapshot.visibleNodes.where(
          (node) => !parents.contains(node.key),
        );
        for (final node in leaves) {
          final tile = Rect.fromLTWH(
            node.bounds.left,
            node.bounds.top,
            node.bounds.width,
            node.bounds.height,
          );
          final Rect body;
          if (id == ids.first) {
            body = tile;
          } else if (id == ids[2]) {
            body = Rect.fromLTRB(
              tile.left,
              tile.top + 56,
              tile.right,
              tile.bottom,
            );
          } else {
            body = labels!.prepare().contentBounds[node.key] ?? tile;
          }
          final finder = find.byKey(ValueKey('centered-${node.key}'));
          if (body.isEmpty) {
            expect(finder, findsNothing);
            continue;
          }
          final expected = Rect.fromCenter(
            center: body.center + origin,
            width: body.width * widgetLayer.widthFactor,
            height: body.height * widgetLayer.heightFactor,
          );
          final actual = tester.getRect(finder);
          expect(actual.left, closeTo(expected.left, .001));
          expect(actual.top, closeTo(expected.top, .001));
          expect(actual.width, closeTo(expected.width, .001));
          expect(actual.height, closeTo(expected.height, .001));
          if (text != null) {
            final entry = text.entries.singleWhere(
              (entry) => entry.key == node.key,
            );
            expect(entry.bounds.center.dx, closeTo(body.center.dx, .001));
            expect(entry.bounds.center.dy, closeTo(body.center.dy, .001));
          }
          if (id == ids[1]) {
            expect(body.top, tile.top);
            expect(body.bottom, lessThan(tile.bottom));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
