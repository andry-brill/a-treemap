import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapCenteredWidgetLayer<String> _overlay(WidgetTester tester) =>
    (tester
                .widget<TreemapChart<String>>(find.byType(TreemapChart<String>))
                .tiles
            as TreemapCompositeTileLayer<String>)
        .layers
        .whereType<TreemapCenteredWidgetLayer<String>>()
        .single;

TreemapTilePainter<String> _tiles(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<TreemapTilePainter<String>>()
    .single;

Finder _content(TreemapKey<String> key) =>
    find.byKey(ValueKey('centered-$key'));

void main() {
  test('controls validate and survive URL round trips', () {
    var config = PlaygroundConfig.defaults();
    expect(config.flag('tiles.centered.enabled'), isFalse);
    expect(config.text('tiles.centered.region'), 'available');
    expect(config.number('tiles.centered.widthFactor'), 1);
    expect(config.number('tiles.centered.heightFactor'), 1);
    expect(config.optionalNumber('tiles.centered.aspect'), isNull);
    expect(config.flag('tiles.centered.minimumEnabled'), isFalse);
    expect(
      propertiesByKey['tiles.centered.widthFactor']!.enabled(config),
      isFalse,
    );
    config = config.withValues({
      'tiles.centered.enabled': true,
      'tiles.centered.region': 'tile',
      'tiles.centered.widthFactor': .75,
      'tiles.centered.heightFactor': .25,
      'tiles.centered.aspect': 1.5,
      'tiles.centered.minimumEnabled': true,
      'tiles.centered.minimumWidth': 24,
      'tiles.centered.minimumHeight': 16,
    });
    expect(
      PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: config).uri,
      ).config,
      config,
    );
    expect(
      propertiesByKey['tiles.centered.minimumWidth']!.enabled(config),
      isTrue,
    );
    expect(
      propertiesByKey['tiles.centered.minimumWidth']!.enabled(
        config.withValues({'tiles.centered.minimumEnabled': false}),
      ),
      isFalse,
    );
    for (final key in [
      'tiles.centered.widthFactor',
      'tiles.centered.heightFactor',
    ]) {
      for (final value in [-.1, 1.1, double.nan, double.infinity]) {
        expect(() => config.withValues({key: value}), throwsFormatException);
      }
    }
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => config.withValues({'tiles.centered.aspect': value}),
        throwsFormatException,
      );
    }
  });

  for (final id in [
    'appearance-centered-widget-defaults',
    'appearance-centered-widget-aspect',
    'appearance-centered-widget-minimum',
  ]) {
    for (final surface in [const Size(1000, 700), const Size(360, 700)]) {
      testWidgets('$id allocates centered content at ${surface.width} px', (
        tester,
      ) async {
        final config = presetsByKey[id]!.config.withValues({
          'preview.showHierarchy': false,
          'animation.enabled': false,
        });
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
          surfaceSize: surface,
        );
        await tester.pumpAndSettle();
        final layer = _overlay(tester);
        final tilePainter = _tiles(tester);
        final labels = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<TreemapCanvasLabelPainter<String>>()
            .single;
        final leaves = tilePainter.snapshot.visibleNodes.where(
          (node) => !node.hasChildren,
        );
        expect(leaves, hasLength(id.endsWith('minimum') ? 120 : 3));
        final origin = tester.getTopLeft(find.byType(TreemapChart<String>));
        var shown = 0;
        var hidden = 0;
        for (final node in leaves) {
          final body =
              labels.prepare().contentBounds[node.key] ??
              Rect.fromLTWH(
                node.bounds.left,
                node.bounds.top,
                node.bounds.width,
                node.bounds.height,
              );
          final factoredWidth = body.width * layer.widthFactor;
          final factoredHeight = body.height * layer.heightFactor;
          final isSquare = id.endsWith('aspect');
          final side = factoredWidth < factoredHeight
              ? factoredWidth
              : factoredHeight;
          final width = isSquare ? side : factoredWidth;
          final height = isSquare ? side : factoredHeight;
          final minimum = layer.minimumSize;
          final visible =
              width > 0 &&
              height > 0 &&
              (minimum == null ||
                  (width >= minimum.width && height >= minimum.height));
          expect(_content(node.key), visible ? findsOneWidget : findsNothing);
          if (visible) {
            shown++;
            expect(tester.getSize(_content(node.key)), Size(width, height));
            expect(
              tester.getCenter(_content(node.key)).dx,
              closeTo(origin.dx + body.center.dx, .001),
            );
            expect(
              tester.getCenter(_content(node.key)).dy,
              closeTo(origin.dy + body.center.dy, .001),
            );
          } else {
            hidden++;
          }
        }
        expect(shown, greaterThan(0));
        expect(labels.config.alignment, Alignment.topLeft);
        if (id.endsWith('aspect')) {
          expect(layer.aspect, 1);
          expect(layer.widthFactor, .65);
          expect(layer.heightFactor, .5);
          expect(layer.minimumSize, isNull);
          expect(hidden, 0);
        } else if (id.endsWith('defaults')) {
          expect(layer.aspect, isNull);
          expect(layer.minimumSize, isNull);
          expect(layer.widthFactor, 1);
          expect(layer.heightFactor, 1);
          expect(hidden, 0);
        } else {
          expect(layer.minimumSize, const Size(24, 16));
          expect(hidden, greaterThan(0));
          final bounds = {for (final node in leaves) node.key: node.bounds};
          await tester.pumpTreemapApp(
            Material(
              child: PlaygroundPreview(
                config: config.withValues({
                  'tiles.centered.minimumEnabled': false,
                }),
                showToolbar: false,
              ),
            ),
            surfaceSize: surface,
          );
          await tester.pumpAndSettle();
          expect(_overlay(tester).minimumSize, isNull);
          for (final node in _tiles(tester).snapshot.visibleNodes) {
            expect(node.bounds, bounds[node.key]);
            expect(_content(node.key), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
