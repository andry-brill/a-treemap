import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/centered_text_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapCenteredTextPainter<String> _text(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapCenteredTextPainter<String>>()
    .single;

TreemapTilePainter<String> _tiles(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapTilePainter<String>>()
    .single;

void main() {
  test('template and allocation settings validate and round-trip URLs', () {
    var config = PlaygroundConfig.defaults();
    expect(config.flag('tiles.centeredText.enabled'), isFalse);
    expect(
      propertiesByKey['tiles.centeredText.template']!.enabled(config),
      isFalse,
    );
    config = config.withValues({
      'tiles.centeredText.enabled': true,
      'tiles.centeredText.template': 'WWW',
      'tiles.centeredText.widthFactor': .8,
      'tiles.centeredText.heightFactor': .4,
      'tiles.centeredText.aspect': 2,
      'tiles.centeredText.minimumEnabled': true,
      'tiles.centeredText.minimumWidth': 24,
      'tiles.centeredText.minimumHeight': 16,
    });
    expect(
      PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: config).uri,
      ).config,
      config,
    );
    expect(
      propertiesByKey['tiles.centeredText.template']!.enabled(config),
      isTrue,
    );
    expect(
      propertiesByKey['tiles.centeredText.minimumWidth']!.enabled(config),
      isTrue,
    );
    for (final template in ['', 'W\nW', 'W\rW', 'W\u2028W']) {
      expect(
        () => config.withValues({'tiles.centeredText.template': template}),
        throwsFormatException,
      );
    }
    for (final key in [
      'tiles.centeredText.widthFactor',
      'tiles.centeredText.heightFactor',
    ]) {
      for (final value in [-1.0, 1.1, double.nan, double.infinity]) {
        expect(() => config.withValues({key: value}), throwsFormatException);
      }
    }
    expect(
      () => config.withValues({'tiles.centeredText.aspect': 0}),
      throwsFormatException,
    );
  });

  for (final surface in [const Size(1000, 700), const Size(360, 700)]) {
    testWidgets(
      'fixed template example follows template length at ${surface.width} px',
      (tester) async {
        final preset = presetsByKey['appearance-centered-text-fixed']!;
        final config = preset.config.withValues({'animation.enabled': false});
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
          surfaceSize: surface,
        );
        await tester.pumpAndSettle();
        final before = _text(tester);
        expect(before.entries, hasLength(3));
        expect(
          before.entries.every((e) => e.painter.plainText == 'DD'),
          isTrue,
        );
        final bounds = {
          for (final n in _tiles(tester).snapshot.visibleNodes) n.key: n.bounds,
        };
        for (final entry in before.entries) {
          final tile = bounds[entry.key]!;
          expect(entry.bounds.center.dx, closeTo(tile.centerX, .001));
          expect(entry.bounds.center.dy, closeTo(tile.centerY, .001));
          expect(entry.bounds.width, closeTo(tile.width * .65, .001));
          expect(entry.bounds.height, closeTo(tile.height * .65, .001));
          expect(entry.painter.height, before.referenceSize.height);
        }
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(
              config: config.withValues({'tiles.centeredText.template': 'WWW'}),
              showToolbar: false,
            ),
          ),
          surfaceSize: surface,
        );
        await tester.pumpAndSettle();
        final longer = _text(tester);
        expect(
          longer.referenceSize.width,
          greaterThan(before.referenceSize.width),
        );
        expect(longer.referenceSize.height, before.referenceSize.height);
        expect(
          longer.entries.every((e) => e.painter.plainText == 'DDD'),
          isTrue,
        );
        final chartOrigin = tester.getTopLeft(
          find.byType(TreemapChart<String>),
        );
        await tester.tapAt(chartOrigin + longer.entries.first.bounds.center);
        await tester.pumpAndSettle();
        expect(_text(tester).entries.first.painter.plainText, 'WWW');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cutoff omits text while small tiles remain visible', (
    tester,
  ) async {
    final config = presetsByKey['appearance-centered-text-fixed']!.config
        .withValues({
          'animation.enabled': false,
          'data': 'dense-tail',
          'data.count': 120,
          'layout.minimumWidth': 0,
          'layout.minimumHeight': 0,
          'layout.minimumArea': 0,
          'layout.innerSpacing': 0,
        });
    Future<void> pump(PlaygroundConfig value) async {
      await tester.pumpTreemapApp(
        Material(child: PlaygroundPreview(config: value, showToolbar: false)),
      );
      await tester.pumpAndSettle();
    }

    await pump(config);
    expect(_text(tester).entries, hasLength(120));
    final bounds = {
      for (final n in _tiles(tester).snapshot.visibleNodes) n.key: n.bounds,
    };
    await pump(
      config.withValues({
        'tiles.centeredText.minimumEnabled': true,
        'tiles.centeredText.minimumWidth': 24,
        'tiles.centeredText.minimumHeight': 16,
      }),
    );
    expect(_text(tester).entries.length, allOf(greaterThan(0), lessThan(120)));
    expect(_tiles(tester).snapshot.visibleNodes, hasLength(120));
    for (final n in _tiles(tester).snapshot.visibleNodes) {
      expect(n.bounds, bounds[n.key]);
    }
  });
}
