import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:any_treemap_example/playground/property_editor.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _spacing = 'labels.spacing';
const _preset = 'appearance-title-value-spacing';
const _expenses = TreemapKey.source('expenses');

TreemapPresentationState<String> _state(WidgetTester tester) =>
    TreemapPresentationScope.of<String>(
      tester.element(
        find
            .descendant(
              of: find.byType(TreemapChart<String>),
              matching: find.byType(Listener),
            )
            .last,
      ),
    );

void main() {
  test(
    'spacing is validated, round-trips, and supports custom canvas lines',
    () {
      expect(PlaygroundConfig.defaults().number(_spacing), 0);
      final preset = presetsByKey[_preset]!.config;
      expect(preset.number(_spacing), 6);
      for (final value in [0.0, 6.0, 6.5]) {
        final config = preset.withValues({_spacing: value});
        expect(
          PlaygroundLocationCodec.decode(
            PlaygroundLocation(config: config).uri,
          ).config,
          config,
        );
      }
      final custom = preset.withValues({
        'labels.linesBuilder': 'titleValueDepth',
      });
      final property = propertiesByKey[_spacing]!;
      expect(property.enabled(custom), isTrue);
      expect(property.disabledReason(custom), isNull);
      expect(
        property.enabled(custom.withValues({'labels.renderer': 'widgets'})),
        isTrue,
      );
      for (final value in [-1.0, double.nan, double.infinity]) {
        expect(
          () => preset.withValues({_spacing: value}),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'spacing control commits fractional edits and reflects custom mode',
    (tester) async {
      final store = PlaygroundStore(
        initial: PlaygroundLocation(config: presetsByKey[_preset]!.config),
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => PropertyEditorField(
                    key: ValueKey(store.formGeneration),
                    property: propertiesByKey[_spacing]!,
                    store: store,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('field-$_spacing'));
      await tester.enterText(field, '6.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(store.committed.number(_spacing), 6.5);
      expect(
        PlaygroundLocationCodec.decode(store.location.uri).config,
        store.committed,
      );
      store.change('labels.linesBuilder', 'titleValueDepth');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).enabled, isTrue);
      store.change('labels.renderer', 'widgets');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).enabled, isTrue);
    },
  );

  testWidgets('renderer switches share base styles and render-only overrides', (
    tester,
  ) async {
    const titleColor = Color(0xFF4CAF50);
    const valueColor = Color(0xFF2196F3);
    var config = presetsByKey[_preset]!.config.withValues({
      'labels.titleSize': 14,
      'labels.titleWeight': 'w700',
      'labels.titleHeight': 1.5,
      'labels.valueSize': 10,
      'labels.valueHeight': 1.5,
      'labels.titleColor': titleColor,
      'labels.valueColor': valueColor,
      'labels.titleFormatter': 'uppercase',
      'labels.valueFormatter': 'percent',
      'labels.alignment': 'bottomRight',
      'labels.maxLines': 3,
      'labels.overflow': 'clip',
      'labels.hover.titleSize': 30,
      'labels.selected.valueSize': 22,
    });
    Future<TreemapPresentationState<String>> show(String renderer) async {
      config = config.withValues({'labels.renderer': renderer});
      await tester.pumpTreemapApp(
        Material(child: PlaygroundPreview(config: config, showToolbar: false)),
        surfaceSize: const Size(600, 450),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return _state(tester);
    }

    final canvas = (await show('canvas')).details[_expenses]!.headerBounds;
    final widgets = await show('widgets');
    expect(widgets.details[_expenses]!.headerBounds, canvas);
    final title = tester.widget<Text>(find.text('EXPENSES'));
    final value = tester.widget<Text>(find.text('19.0%'));
    expect(title.style!.fontSize, 14);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.style!.height, 1.5);
    expect(title.style!.color, titleColor);
    expect(value.style!.fontSize, 10);
    expect(value.style!.color, valueColor);
    expect(title.maxLines, 1); // Automatic parent headers remain single-line.
    final child = tester.widget<Text>(find.text('GROCERIES'));
    expect(child.maxLines, 3);
    expect(child.overflow, TextOverflow.clip);
    expect(value.maxLines, 1);
    expect(value.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .widget<Align>(
            find
                .ancestor(
                  of: find.text('EXPENSES'),
                  matching: find.byType(Align),
                )
                .first,
          )
          .alignment,
      Alignment.bottomRight,
    );
    final actions = TreemapPresentationScope.actionsOf<String>(
      tester.element(find.text('EXPENSES')),
    );
    actions.hover(_expenses);
    actions.select(_expenses);
    actions.focus(_expenses);
    await tester.pumpAndSettle();
    expect(_state(tester).targetSnapshot, same(widgets.targetSnapshot));
    expect(tester.widget<Text>(find.text('EXPENSES')).style!.fontSize, 30);
    expect(tester.widget<Text>(find.text('19.0%')).style!.fontSize, 22);
    expect(
      tester.widget<Text>(find.text('EXPENSES')).style!.color,
      isNot(titleColor),
    );
    expect(
      tester.widget<Text>(find.text('EXPENSES')).style!.fontWeight,
      isNull,
    ); // Whole-style replacement.
    expect(tester.takeException(), isNull);

    // Base typography changes resize both renderers, unlike state overrides.
    config = config.withValues({
      'labels.titleSize': 24,
      'labels.valueSize': 18,
    });
    final baseCanvas = (await show('canvas')).details[_expenses]!.headerBounds;
    final baseWidgets = await show('widgets');
    expect(baseWidgets.details[_expenses]!.headerBounds, baseCanvas);
    expect(baseCanvas!.height, isNot(canvas!.height));
  });

  for (final renderer in ['canvas', 'widgets']) {
    testWidgets('$renderer shares padding across children and parent headers', (
      tester,
    ) async {
      for (final side in ['left', 'top', 'right', 'bottom']) {
        expect(PlaygroundConfig.defaults().number('labels.padding.$side'), 0);
      }
      var config = presetsByKey[_preset]!.config.withValues({
        'labels.renderer': renderer,
        'labels.padding.left': 0,
        'labels.padding.top': 0,
        'labels.padding.right': 0,
        'labels.padding.bottom': 0,
      });
      Future<TreemapPresentationState<String>> show() async {
        expect(
          PlaygroundLocationCodec.decode(
            PlaygroundLocation(config: config).uri,
          ).config,
          config,
        );
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
          surfaceSize: const Size(600, 450),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return _state(tester);
      }

      final initial = (await show()).details[_expenses]!;
      config = config.withValues({
        'labels.padding.left': 3,
        'labels.padding.top': 4,
        'labels.padding.right': 5,
        'labels.padding.bottom': 6,
      });
      final padded = await show();
      expect(padded.details[_expenses]!.bounds, initial.bounds);
      expect(
        padded.details[_expenses]!.headerBounds!.height,
        initial.headerBounds!.height + 10,
      );
      if (renderer == 'widgets') {
        for (final (key, title) in [
          ('expenses', 'Expenses'),
          ('groceries', 'Groceries'),
        ]) {
          final details = padded.details[TreemapKey.source(key)]!;
          final bounds = details.headerBounds ?? details.bounds;
          final position = tester.getTopLeft(find.text(title));
          expect(position.dx - bounds.left, closeTo(3, 1e-6));
          expect(position.dy - bounds.top, closeTo(4, 1e-6));
        }
      }
      config = config.withValues({'labels.parents.height': 56});
      final fixed = (await show()).targetSnapshot;
      config = config.withValues({
        'labels.padding.top': 0,
        'labels.padding.bottom': 0,
      });
      expect((await show()).targetSnapshot, same(fixed));
    });

    testWidgets(
      '$renderer preview shares spacing and includes it in header allocation',
      (tester) async {
        var config = presetsByKey[_preset]!.config.withValues({
          'labels.renderer': renderer,
          'preview.showHierarchy': false,
          _spacing: 0,
        });
        Future<TreemapPresentationState<String>> show() async {
          await tester.pumpTreemapApp(
            Material(
              child: PlaygroundPreview(config: config, showToolbar: false),
            ),
            surfaceSize: const Size(600, 450),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          return _state(tester);
        }

        final initial = (await show()).details[_expenses]!;
        config = config.withValues({_spacing: 6});
        final spaced = (await show()).details[_expenses]!;
        expect(spaced.headerBounds!.height, initial.headerBounds!.height + 6);
        expect(spaced.bounds, initial.bounds);
        if (renderer == 'widgets') {
          for (final (title, value) in [
            ('Expenses', '19'),
            ('Groceries', '4'),
          ]) {
            expect(
              tester.getTopLeft(find.text(value)).dy -
                  tester.getBottomLeft(find.text(title)).dy,
              closeTo(6, 1e-6),
            );
          }
        }
        config = config.withValues({'labels.parents.showTitle': false});
        final onePart = (await show()).details[_expenses]!.headerBounds!.height;
        config = config.withValues({_spacing: 0});
        expect(
          (await show()).details[_expenses]!.headerBounds!.height,
          onePart,
        );
        if (renderer == 'widgets') {
          expect(find.text('Expenses'), findsNothing);
          expect(find.text('19'), findsOneWidget);
        }
        // A large spacer must not produce a RenderFlex overflow in small tiles.
        config = config.withValues({_spacing: 64, 'preview.height': 64});
        await show();
      },
    );

    testWidgets('$renderer title/value spacing visual contract', (
      tester,
    ) async {
      final config = presetsByKey[_preset]!.config.withValues({
        'labels.renderer': renderer,
        'preview.showHierarchy': false,
      });
      await tester.pumpTreemapApp(
        RepaintBoundary(
          key: const ValueKey('spacing-golden'),
          child: Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
        ),
        surfaceSize: const Size(600, 450),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('spacing-golden')),
        matchesGoldenFile('goldens/$_preset-$renderer.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
