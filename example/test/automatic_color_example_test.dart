import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preset in allPresets.where(
    (preset) =>
        preset.id.startsWith('appearance-auto-') ||
        preset.id == 'appearance-presentation-state',
  )) {
    testWidgets('${preset.id} preserves its documented domain', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var config = preset.config;
      Future<void> show() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PlaygroundPreview(config: config)),
          ),
        );
        await tester.pumpAndSettle();
      }

      TreemapColorScale resolved() {
        final view = tester.widget<TreemapLegendView<String>>(
          find.byType(TreemapLegendView<String>),
        );
        final scope = tester.widget<TreemapPresentationScope<String>>(
          find.byType(TreemapPresentationScope<String>),
        );
        return (view.presentation ?? scope.notifier!.value).resolveColorScale(
          view.scale,
        );
      }

      await show();
      if (preset.id == 'appearance-auto-standalone') {
        expect(resolved().minimum, 15);
        expect(resolved().maximum, 55);
      } else {
        final visible =
            preset.id == 'appearance-auto-visible' ||
            preset.id == 'appearance-presentation-state';
        final mixed = preset.id == 'appearance-auto-mixed-bounds';
        expect(
          resolved().minimum,
          visible
              ? 40
              : mixed
              ? 0
              : 10,
        );
        expect(resolved().maximum, 60);
        config = config.withValues({'layout.maxVisibleDepth': 2});
        await show();
        expect(resolved().minimum, mixed ? 0 : 10);
        config = config.withValues({'data.revision': 1});
        await show();
        expect(resolved().maximum, 100);
        if (mixed) {
          config = config.withValues({
            'color.minimum': null,
            'color.maximum': 100,
          });
          await show();
          expect(resolved().minimum, 10);
        }
        config = config.withValues({
          'data.revision': 0,
          'layout.maxVisibleDepth': 1,
        });
        await show();
        final chart = tester.widget<TreemapChart<String>>(
          find.byType(TreemapChart<String>),
        );
        chart.controller!.zoomTo('a');
        await tester.pumpAndSettle();
        expect(
          resolved().maximum,
          visible
              ? 30
              : mixed
              ? 100
              : 60,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
