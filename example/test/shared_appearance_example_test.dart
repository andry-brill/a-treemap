import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

BuildContext _context(WidgetTester tester) => tester.element(
  find
      .descendant(
        of: find.byType(TreemapChart<String>),
        matching: find.byType(Listener),
      )
      .last,
);
TreemapCanvasLabelPainter<String> _labels(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<TreemapCanvasLabelPainter<String>>()
    .single;

void main() {
  for (final renderer in ['canvas', 'widgets', 'composite']) {
    testWidgets('$renderer tiles share background changes with labels', (
      tester,
    ) async {
      final config = presetsByKey['appearance-shared-tile-labels']!.config
          .withValues({
            'tiles.renderer': renderer,
            'preview.showHierarchy': false,
          });
      expect(
        PlaygroundLocationCodec.decode(
          PlaygroundLocation(config: config).uri,
        ).config,
        config,
      );
      await tester.pumpTreemapApp(
        Material(child: PlaygroundPreview(config: config, showToolbar: false)),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<TreemapChart<String>>(
        find.byType(TreemapChart<String>),
      );
      expect(chart.labels, isA<TreemapCanvasLabels<String>>());
      expect(chart.tiles.appearance, isNotNull);
      final context = _context(tester);
      final target = TreemapPresentationScope.of<String>(
        context,
      ).targetSnapshot;
      final actions = TreemapPresentationScope.actionsOf<String>(context);
      const key = TreemapKey.source('groceries');
      actions.hover(key);
      await tester.pumpAndSettle();
      var painter = _labels(tester);
      expect(painter.appearances[key]!.color, Colors.white);
      expect(
        painter.config
            .resolveLines(
              painter.details[key]!,
              painter.appearances[key]!,
              null,
              styles: painter.styles[key]!,
            )
            .first
            .style
            .color,
        Colors.black,
      );
      actions.select(key);
      await tester.pumpAndSettle();
      painter = _labels(tester);
      expect(painter.appearances[key]!.color, Colors.black);
      expect(
        painter.config
            .resolveLines(
              painter.details[key]!,
              painter.appearances[key]!,
              null,
              styles: painter.styles[key]!,
            )
            .first
            .style
            .color,
        Colors.white,
      );
      if (renderer != 'widgets') {
        final tiles = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<TreemapTilePainter<String>>()
            .single;
        expect(painter.appearances, same(tiles.appearances));
      }
      expect(
        TreemapPresentationScope.of<String>(_context(tester)).targetSnapshot,
        same(target),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invisible and painted tiles both own their label background', (
    tester,
  ) async {
    var config = presetsByKey['appearance-label-fallback']!.config;
    for (final renderer in ['noop', 'canvas']) {
      config = config.withValues({'tiles.renderer': renderer});
      await tester.pumpTreemapApp(
        Material(child: PlaygroundPreview(config: config, showToolbar: false)),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<TreemapChart<String>>(
        find.byType(TreemapChart<String>),
      );
      expect(chart.labels, isA<TreemapCanvasLabels<String>>());
      expect(chart.tiles.appearance, isNotNull);
      expect(
        _labels(
          tester,
        ).appearances.values.every((a) => a.color == Colors.white),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
