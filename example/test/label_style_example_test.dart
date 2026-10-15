import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:any_treemap_example/playground/property_editor.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _preset = 'appearance-label-style-overrides';
const _expenses = TreemapKey.source('expenses');
const _food = TreemapKey.source('food');

BuildContext _context(WidgetTester tester) => tester.element(
  find
      .descendant(
        of: find.byType(TreemapChart<String>),
        matching: find.byType(Listener),
      )
      .last,
);
TreemapPresentationState<String> _state(WidgetTester tester) =>
    TreemapPresentationScope.of<String>(_context(tester));

void main() {
  test(
    'new typography URL keys round-trip and obsolete keys report notices',
    () {
      final config = presetsByKey[_preset]!.config;
      final restored = PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: config).uri,
      );
      expect(restored.config, config);
      expect(restored.notices, isEmpty);
      for (final state in ['normal', 'hover', 'selected', 'focused']) {
        for (final part in ['title', 'value']) {
          final key = 'tiles.$state.${part}Size';
          expect(propertiesByKey, isNot(contains(key)));
          final result = PlaygroundLocationCodec.decode(
            Uri(queryParameters: {key: '30'}),
          );
          expect(result.notices, contains('Ignored unknown property: $key'));
        }
      }
      for (final state in ['hover', 'selected', 'focused']) {
        for (final part in ['title', 'value']) {
          final key = 'labels.$state.${part}Size';
          final edited = config.withValues({key: 15.5});
          expect(
            PlaygroundLocationCodec.decode(
              PlaygroundLocation(config: edited).uri,
            ).config,
            edited,
          );
        }
      }
    },
  );

  testWidgets('label state control edits commit and round-trip', (
    tester,
  ) async {
    final store = PlaygroundStore(
      initial: PlaygroundLocation(config: presetsByKey[_preset]!.config),
    );
    addTearDown(store.dispose);
    const key = 'labels.hover.titleSize';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ListenableBuilder(
              listenable: store,
              builder: (_, _) => PropertyEditorField(
                key: ValueKey(store.formGeneration),
                property: propertiesByKey[key]!,
                store: store,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('field-$key')), '15.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.committed.number(key), 15.5);
    expect(
      PlaygroundLocationCodec.decode(store.location.uri).config,
      store.committed,
    );
  });

  for (final renderer in ['canvas', 'widgets']) {
    testWidgets('$renderer label override styles and visual contract', (
      tester,
    ) async {
      final config = presetsByKey[_preset]!.config.withValues({
        'labels.renderer': renderer,
        'preview.showHierarchy': false,
      });
      await tester.pumpTreemapApp(
        RepaintBoundary(
          key: const ValueKey('style-golden'),
          child: Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
        ),
        surfaceSize: const Size(600, 450),
      );
      await tester.pumpAndSettle();
      final initial = _state(tester).targetSnapshot;
      final actions = TreemapPresentationScope.actionsOf<String>(
        _context(tester),
      );
      actions.hover(_food);
      actions.select(_food);
      actions.focus(_expenses);
      await tester.pumpAndSettle();
      expect(_state(tester).targetSnapshot, same(initial));
      if (renderer == 'widgets') {
        final food = tester.widget<Text>(find.text('Food'));
        expect(food.style!.fontSize, 16);
        expect(food.style!.color, Colors.deepPurple);
        expect(tester.widget<Text>(find.text('6')).style!.fontSize, 14);
        expect(tester.widget<Text>(find.text('Expenses')).style!.fontSize, 17);
      } else {
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<TreemapCanvasLabelPainter<String>>()
            .single;
        expect(painter.styles[_food]!.titleStyle!.fontSize, 16);
        expect(painter.styles[_food]!.titleStyle!.color, Colors.deepPurple);
        expect(painter.styles[_food]!.valueStyle!.fontSize, 14);
        expect(painter.styles[_expenses]!.titleStyle!.fontSize, 17);
      }
      await expectLater(
        find.byKey(const ValueKey('style-golden')),
        matchesGoldenFile('goldens/$_preset-$renderer.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
