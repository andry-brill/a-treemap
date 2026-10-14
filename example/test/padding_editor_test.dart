import 'package:any_treemap_example/main.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/padding_input.dart';
import 'package:any_treemap_example/playground/padding_values.dart';
import 'package:any_treemap_example/playground/property_editor.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _prefix = 'layout.outerPadding';
const _fieldKey = ValueKey('field-$_prefix');
const _sliderKey = ValueKey('slider-$_prefix');

List<double> _values(PlaygroundConfig config, [String prefix = _prefix]) =>
    paddingKeys(prefix).map(config.number).toList();

Widget _editor(PlaygroundStore store, {String prefix = _prefix}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: ListenableBuilder(
          listenable: store,
          builder: (_, _) => PropertyEditorField(
            key: ValueKey(store.formGeneration),
            property: propertiesByKey['$prefix.left']!,
            store: store,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'padding shorthand expands horizontal/vertical and LTRB integer input',
    () {
      expect(parsePaddingValues('5'), [5, 5, 5, 5]);
      expect(parsePaddingValues(' 5 , 10 '), [5, 10, 5, 10]);
      expect(parsePaddingValues('1,2,3,4'), [1, 2, 3, 4]);
      expect(parsePaddingValues('0,256'), [0, 256, 0, 256]);
      expect(formatPaddingValues([5, 5, 5, 5]), '5');
      expect(formatPaddingValues([5, 10, 5, 10]), '5,10');
      expect(formatPaddingValues([1, 2, 3, 4]), '1,2,3,4');
      expect(formatPaddingValues([1.5, 2.5, 1.5, 2.5]), '1.5,2.5');
    },
  );

  test(
    'invalid and incomplete padding input is rejected without filtering',
    () {
      for (final raw in [
        '',
        '5,',
        '1,2,3',
        '1,2,3,4,5',
        '1,,2,3',
        '1.5',
        '1e2',
        '-1',
        '257',
        'abc',
        'Infinity',
      ]) {
        expect(
          () => parsePaddingValues(raw),
          throwsFormatException,
          reason: raw,
        );
      }
    },
  );

  test(
    'padding drafts preview and commit all four existing URL fields atomically',
    () {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      final original = store.location.uri;
      var pushes = 0;
      store.addListener(() {
        if (store.historyIntent == HistoryIntent.push) pushes++;
      });
      store.draftPadding(_prefix, '5,10');
      expect(_values(store.preview), [5, 10, 5, 10]);
      expect(store.preview.values['$_prefix.left'], isA<double>());
      expect(store.location.uri, original);
      expect(store.hasDrafts, isTrue);
      store.commitPadding(_prefix);
      expect(pushes, 1);
      expect(store.exampleKey, isNull);
      expect(store.paddingDraft(_prefix), isNull);
      expect(store.hasDrafts, isFalse);
      final query = store.location.uri.queryParameters;
      expect(query['$_prefix.left'], '5');
      expect(query['$_prefix.top'], '10');
      expect(query['$_prefix.right'], '5');
      expect(query['$_prefix.bottom'], '10');
      expect(query.containsKey(_prefix), isFalse);
      expect(
        PlaygroundLocationCodec.decode(store.location.uri).config,
        store.committed,
      );
    },
  );

  test(
    'copy commits valid padding and leaves invalid padding drafts out of links',
    () {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      store.draftPadding(_prefix, '5,');
      store.draftPadding('labels.padding', '2,4,6,8');
      store.draftRaw('labels.titleSize', '16');
      store.commitValidDrafts();
      expect(_values(store.committed), [0, 0, 0, 0]);
      expect(_values(store.committed, 'labels.padding'), [2, 4, 6, 8]);
      expect(store.committed.number('labels.titleSize'), 16);
      expect(store.paddingDraft(_prefix), '5,');
      expect(store.errors, contains(_prefix));
      expect(store.hasDrafts, isTrue);
      expect(store.location.uri.queryParameters['$_prefix.left'], '0');
      store.restore(PlaygroundLocationCodec.decode(store.location.uri));
      expect(store.paddingDraft(_prefix), isNull);
      expect(store.errors, isEmpty);
      expect(store.hasDrafts, isFalse);
    },
  );

  testWidgets(
    'one field previews shorthand and disables the slider for unequal sides',
    (tester) async {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(_editor(store));
      final field = find.byKey(_fieldKey);
      TextField input() => tester.widget<TextField>(field);
      Slider slider() => tester.widget<Slider>(find.byKey(_sliderKey));
      expect(input().controller!.text, '0');
      expect(slider().onChanged, isNotNull);
      await tester.enterText(field, '5,10');
      await tester.pump();
      expect(_values(store.preview), [5, 10, 5, 10]);
      expect(slider().onChanged, isNull);
      expect(slider().semanticFormatterCallback!(5), contains('disabled'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(input().controller!.text, '5,10');
      await tester.enterText(field, '1,2,3,4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_values(store.committed), [1, 2, 3, 4]);
      await tester.enterText(field, '7,7,7,7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(input().controller!.text, '7');
      expect(slider().onChanged, isNotNull);
      await tester.enterText(field, '5,');
      await tester.pump();
      expect(input().controller!.text, '5,');
      expect(input().decoration!.errorText, isNotNull);
      expect(slider().onChanged, isNull);
      expect(_values(store.preview), [7, 7, 7, 7]);
    },
  );

  testWidgets('a focused draft and slider drag produce one committed update', (
    tester,
  ) async {
    final store = PlaygroundStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_editor(store));
    final original = store.location.uri;
    var pushes = 0;
    store.addListener(() {
      if (store.historyIntent == HistoryIntent.push) pushes++;
    });
    await tester.enterText(find.byKey(_fieldKey), '5');
    await tester.pump();
    final slider = tester.widget<Slider>(find.byKey(_sliderKey));
    slider.onChangeStart!(5);
    slider.onChanged!(9);
    slider.onChanged!(12);
    await tester.pump();
    expect(_values(store.preview), [12, 12, 12, 12]);
    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
      '12',
    );
    expect(store.location.uri, original);
    expect(pushes, 0);
    tester.widget<Slider>(find.byKey(_sliderKey)).onChangeEnd!(12);
    await tester.pumpAndSettle();
    expect(pushes, 1);
    expect(_values(store.committed), [12, 12, 12, 12]);
    expect(store.hasDrafts, isFalse);
  });

  testWidgets(
    'a pointer drag from a focused input waits for release to commit',
    (tester) async {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(_editor(store));
      final original = store.location.uri;
      var pushes = 0;
      store.addListener(() {
        if (store.historyIntent == HistoryIntent.push) pushes++;
      });
      await tester.enterText(find.byKey(_fieldKey), '5');
      await tester.pump();
      final bounds = tester.getRect(find.byKey(_sliderKey));
      final gesture = await tester.startGesture(
        Offset(bounds.left + bounds.width * .25, bounds.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveTo(
        Offset(bounds.left + bounds.width * .65, bounds.center.dy),
      );
      await tester.pump();
      expect(store.location.uri, original);
      expect(pushes, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pushes, 1);
      expect(_values(store.committed).toSet(), hasLength(1));
    },
  );

  testWidgets(
    'blur commits padding and route restoration updates the single field',
    (tester) async {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(_editor(store));
      final compact = store.location;
      await tester.enterText(find.byKey(_fieldKey), '5,10');
      tester.widget<TextField>(find.byKey(_fieldKey)).focusNode!.unfocus();
      await tester.pumpAndSettle();
      final edited = store.location;
      expect(_values(store.committed), [5, 10, 5, 10]);
      store.restore(compact);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
        '0',
      );
      store.restore(PlaygroundLocationCodec.decode(edited.uri));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
        '5,10',
      );
      expect(store.historyIntent, HistoryIntent.replace);
    },
  );

  testWidgets('fractional URL values remain lossless until padding is edited', (
    tester,
  ) async {
    final config = PlaygroundConfig.fromOverrides({
      for (final key in paddingKeys(_prefix)) key: 1.5,
    });
    final store = PlaygroundStore(initial: PlaygroundLocation(config: config));
    addTearDown(store.dispose);
    await tester.pumpWidget(_editor(store));
    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
      '1.5',
    );
    store.change('labels.titleSize', 16);
    expect(_values(store.committed), [1.5, 1.5, 1.5, 1.5]);
    await tester.enterText(find.byKey(_fieldKey), '1.25');
    await tester.pump();
    expect(store.errors, contains(_prefix));
    expect(tester.widget<Slider>(find.byKey(_sliderKey)).onChanged, isNull);
  });

  testWidgets('inapplicable padding disables both input and slider', (
    tester,
  ) async {
    final store = PlaygroundStore(
      initial: PlaygroundLocation(
        config: PlaygroundConfig.fromOverrides({'labels.renderer': 'none'}),
      ),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(_editor(store, prefix: 'labels.padding'));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('field-labels.padding')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('slider-labels.padding')))
          .onChanged,
      isNull,
    );
  });

  testWidgets(
    'the property panel groups all paddings and searches individual side keys',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TreemapExampleApp());
      await tester.pumpAndSettle();
      for (final prefix in [
        'layout.outerPadding',
        'layout.levelPadding',
        'labels.padding',
        'surrounding.padding',
      ]) {
        await tester.enterText(
          find.byKey(const ValueKey('property-search')),
          prefix,
        );
        await tester.pumpAndSettle();
        expect(find.byType(PaddingInput), findsOneWidget, reason: prefix);
        expect(find.byKey(ValueKey('field-$prefix')), findsOneWidget);
        expect(find.byKey(ValueKey('field-$prefix.left')), findsNothing);
      }
      await tester.enterText(
        find.byKey(const ValueKey('property-search')),
        'layout.outerPadding.right',
      );
      await tester.pumpAndSettle();
      expect(find.byType(PaddingInput), findsOneWidget);
      expect(
        find.byKey(const ValueKey('field-layout.outerPadding')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
