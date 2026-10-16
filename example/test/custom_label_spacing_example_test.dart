import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _preset = 'appearance-custom-label-spacing';

void main() {
  test('three-line preset and custom spacing round-trip through URLs', () {
    final preset = presetsByKey[_preset]!.config;
    expect(preset.text('labels.linesBuilder'), 'twoLabelsValue');
    expect(preset.number('labels.spacing'), 6);
    expect(preset.flag('tiles.centered.enabled'), isTrue);
    for (final spacing in [0.0, 6.0, 6.5]) {
      final config = preset.withValues({'labels.spacing': spacing});
      expect(propertiesByKey['labels.spacing']!.enabled(config), isTrue);
      expect(
        PlaygroundLocationCodec.decode(
          PlaygroundLocation(config: config).uri,
        ).config,
        config,
      );
    }
  });

  for (final surface in [const Size(1000, 700), const Size(360, 700)]) {
    testWidgets('three styled lines reserve both gaps at ${surface.width} px', (
      tester,
    ) async {
      final config = presetsByKey[_preset]!.config.withValues({
        'animation.enabled': false,
        'preview.showHierarchy': false,
      });
      final originalTiles = <TreemapKey<String>, Rect>{};
      for (final spacing in [0.0, 6.0, 6.5]) {
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(
              config: config.withValues({'labels.spacing': spacing}),
              showToolbar: false,
            ),
          ),
          surfaceSize: surface,
        );
        await tester.pumpAndSettle();
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<TreemapCanvasLabelPainter<String>>()
            .single;
        final plan = painter.prepare();
        expect(plan.contentBounds, isNotEmpty);
        final origin = tester.getTopLeft(find.byType(TreemapChart<String>));
        for (final key in plan.contentBounds.keys) {
          final lines = plan.entries
              .where((entry) => entry.key == key)
              .toList();
          expect(lines, hasLength(3));
          expect(lines[0].painter.text!.style!.fontWeight, FontWeight.w700);
          expect(lines[0].painter.text!.style!.fontSize, 18);
          expect(lines[1].painter.text!.toPlainText(), startsWith('Depth '));
          expect(lines[1].painter.text!.style!.fontStyle, FontStyle.italic);
          expect(lines[1].painter.text!.style!.fontSize, 12);
          expect(lines[2].painter.text!.style!.fontSize, 12);
          for (var i = 1; i < lines.length; i++) {
            expect(
              lines[i].offset.dy -
                  lines[i - 1].offset.dy -
                  lines[i - 1].painter.height,
              closeTo(spacing, .001),
            );
          }
          final tile = lines.first.bounds;
          if (spacing == 0) originalTiles[key] = tile;
          expect(tile, originalTiles[key]);
          final textHeight = lines.fold<double>(
            0,
            (height, entry) => height + entry.painter.height,
          );
          final body = plan.contentBounds[key]!;
          expect(
            body.top - tile.top,
            closeTo(textHeight + 2 * spacing + 12, .001),
          );
          expect(body.bottom, tile.bottom);
          final widget = tester.getRect(find.byKey(ValueKey('centered-$key')));
          final expected = body.shift(origin);
          expect(widget.top, closeTo(expected.top, .001));
          expect(widget.left, closeTo(expected.left, .001));
          expect(widget.width, closeTo(expected.width, .001));
          expect(widget.height, closeTo(expected.height, .001));
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}
