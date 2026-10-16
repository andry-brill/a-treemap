import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/main.dart';
import 'package:any_treemap_example/playground/router.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'edits push once, drafts replace, and browser history restores controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = PlaygroundStore();
      final provider = PlaygroundRouteProvider(
        store: store,
        initialRouteInformation: RouteInformation(uri: Uri(path: '/')),
      );
      final reports = <Map<String, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(Map<String, Object?>.from(call.arguments as Map));
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        );
        provider.dispose();
        store.dispose();
      });
      await tester.pumpWidget(
        TreemapExampleApp(store: store, routeProvider: provider),
      );
      await tester.pumpAndSettle();
      expect(reports.last['replace'], true);
      final compact = store.location.uri;
      final chartFinder = find.byType(TreemapChart<String>);
      final chart = tester.widget<TreemapChart<String>>(chartFinder);
      final root = chart.tree.root;
      chart.controller!.zoomTo('consumer');
      await tester.pumpAndSettle();
      expect(store.location.uri, compact);
      final pushesBefore = reports
          .where((report) => report['replace'] == false)
          .length;
      await tester.enterText(
        find.byKey(const ValueKey('property-search')),
        'Inner spacing',
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('field-layout.innerSpacing'));
      await tester.enterText(field, '6');
      await tester.pumpAndSettle();
      expect(store.preview.number('layout.innerSpacing'), 6);
      expect(store.location.uri, compact);
      expect(
        reports.where((report) => report['replace'] == false),
        hasLength(pushesBefore),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(store.exampleKey, isNull);
      expect(store.location.uri.queryParameters['data'], 'markets');
      expect(
        reports.where((report) => report['replace'] == false),
        hasLength(pushesBefore + 1),
      );
      final edited = store.location.uri;
      final editedChart = tester.widget<TreemapChart<String>>(chartFinder);
      expect(editedChart.tree.root, same(root));
      expect(
        editedChart.controller!.focusKey,
        const TreemapKey.source('consumer'),
      );
      // Drag callbacks preview repeatedly but commit only at gesture completion.
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('slider-layout.innerSpacing')),
      );
      slider.onChanged!(8);
      slider.onChanged!(10);
      await tester.pumpAndSettle();
      expect(store.location.uri, edited);
      slider.onChangeEnd!(10);
      await tester.pumpAndSettle();
      expect(
        reports.where((report) => report['replace'] == false),
        hasLength(pushesBefore + 2),
      );
      final dragged = store.location.uri;
      await provider.didPushRouteInformation(RouteInformation(uri: compact));
      await tester.pumpAndSettle();
      expect(store.exampleKey, 'data-explicit-tree');
      expect(store.preview.number('layout.innerSpacing'), 0);
      expect(
        tester.widget<TreemapChart<String>>(chartFinder).controller!.focusKey,
        const TreemapKey.source('root'),
      );
      await provider.didPushRouteInformation(RouteInformation(uri: dragged));
      await tester.pumpAndSettle();
      expect(store.preview.number('layout.innerSpacing'), 10);
      expect(
        reports.where((report) => report['replace'] == false),
        hasLength(pushesBefore + 2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('searchable preset chooser applies data and complete settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = PlaygroundStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(TreemapExampleApp(store: store));
    await tester.pumpAndSettle();
    final chooser = find.byType(DropdownMenu<String>);
    final input = find.descendant(
      of: chooser,
      matching: find.byType(TextField),
    );
    await tester.tap(input);
    await tester.enterText(input, 'Automatic visible');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic visible color bounds').last);
    await tester.pumpAndSettle();
    expect(store.location.uri.queryParameters, {
      'example': 'appearance-auto-visible',
    });
    expect(store.preview.text('data'), 'color-domain');
    expect(store.preview.optionalNumber('color.minimum'), isNull);
    expect(store.preview.number('layout.maxVisibleDepth'), 1);
    store.change('labels.titleSize', 16);
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsWidgets);
    expect(store.location.uri.queryParameters.containsKey('example'), false);
    store.selectPreset('data-explicit-tree');
    await tester.pumpAndSettle();
    expect(store.preview.number('labels.titleSize'), 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow layouts use a drawer and property help works by click and keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TreemapExampleApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('property-panel')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-properties')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('property-panel')), findsOneWidget);
      final exampleHelp = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message?.startsWith('Choose a saved configuration.') == true,
      );
      await tester.tap(
        find.descendant(of: exampleHelp, matching: find.byType(IconButton)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Editing a property switches to Custom'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid URL settings show a dismissible notice and keep valid values',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        TreemapExampleApp(
          initialUri: Uri.parse(
            '/?data=categories&layout.innerSpacing=bad&unknown=x',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('invalid value'), findsOneWidget);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
      final chart = tester.widget<TreemapChart<String>>(
        find.byType(TreemapChart<String>),
      );
      expect(chart.tree.root.key, 'merchants');
      expect(chart.layout.innerSpacing, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop shows properties first and a bounded preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = PlaygroundStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(TreemapExampleApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('any_treemap playground'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('property-panel'))).width,
      360,
    );
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial selection edits apply and comparison reset reaches every chart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = PlaygroundStore()
        ..selectPreset('interaction-controlled-selection');
      addTearDown(store.dispose);
      await tester.pumpWidget(TreemapExampleApp(store: store));
      await tester.pumpAndSettle();
      store.change('selection.initial', 'web');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TreemapChart<String>>(find.byType(TreemapChart<String>))
            .controller!
            .selectedEntries,
        contains(const TreemapKey.source('web')),
      );
      store.change('preview.mode', 'originsComparison');
      await tester.pumpAndSettle();
      final charts = find.byType(TreemapChart<String>);
      expect(charts, findsNWidgets(4));
      final first = tester
          .widget<TreemapChart<String>>(charts.first)
          .controller!;
      first.zoomTo('consumer');
      await tester.pumpAndSettle();
      store.change('labels.titleSize', 16);
      await tester.pumpAndSettle();
      expect(first.focusKey, const TreemapKey.source('consumer'));
      expect(first.selectedEntries, contains(const TreemapKey.source('web')));
      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pumpAndSettle();
      for (final chart in tester.widgetList<TreemapChart<String>>(charts)) {
        expect(chart.controller!.focusKey, const TreemapKey.source('root'));
        expect(chart.controller!.selectedEntries, isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Copy link commits valid drafts and keeps an invalid field visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = PlaygroundStore()..selectPreset('appearance-auto-visible');
      addTearDown(store.dispose);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(TreemapExampleApp(store: store));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('property-search')),
        'Visible depth',
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('field-layout.maxVisibleDepth'));
      await tester.enterText(field, '0');
      await tester.pump();
      expect(store.errors, contains('layout.maxVisibleDepth'));
      store.draftRaw('labels.titleSize', '16');
      await tester.tap(find.byKey(const ValueKey('copy-link')));
      await tester.pumpAndSettle();
      final parameters = Uri.parse(copied!).queryParameters;
      expect(parameters['example'], isNull);
      expect(parameters['layout.maxVisibleDepth'], '1');
      expect(parameters['labels.titleSize'], '16');
      expect(store.rawDraft('layout.maxVisibleDepth'), '0');
      expect(tester.widget<TextField>(field).controller!.text, '0');
      expect(store.errors, contains('layout.maxVisibleDepth'));
      expect(tester.takeException(), isNull);
    },
  );
}
