import 'dart:async';

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/main.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:any_treemap_example/playground/property_editor.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<TreemapChart<String>> _charts(WidgetTester tester) => tester
    .widgetList<TreemapChart<String>>(find.byType(TreemapChart<String>))
    .toList();
List<TreemapPresentationScope<String>> _scopes(WidgetTester tester) => tester
    .widgetList<TreemapPresentationScope<String>>(
      find.byType(TreemapPresentationScope<String>),
    )
    .toList();

void main() {
  test('promotion is a data input with complete URL serialization', () {
    final original = PlaygroundConfig.defaults();
    final promoted = original.withValues({'data.singleChildPolicy': 'promote'});
    expect(original.text('data.singleChildPolicy'), 'preserve');
    expect(promoted.dataSignature, isNot(original.dataSignature));
    expect(
      promoted.withValues({'tiles.background': Colors.red}).dataSignature,
      promoted.dataSignature,
    );
    final custom = PlaygroundLocation(config: promoted).uri;
    expect(custom.queryParameters['data.singleChildPolicy'], 'promote');
    expect(PlaygroundLocationCodec.decode(custom).config, promoted);
    final compact = PlaygroundLocationCodec.decode(
      Uri.parse('/?example=data-single-child-promotion'),
    );
    expect(compact.config.text('data.singleChildPolicy'), 'promote');
    expect(compact.uri.queryParameters, {
      'example': 'data-single-child-promotion',
    });
    final mixed = PlaygroundLocationCodec.decode(
      Uri.parse(
        '/?example=data-single-child-promotion&data.singleChildPolicy=preserve',
      ),
    );
    expect(mixed.exampleKey, isNull);
    expect(mixed.config.text('data.singleChildPolicy'), 'preserve');
    final invalid = PlaygroundLocationCodec.decode(
      Uri.parse('/?data=color-domain&data.singleChildPolicy=invalid'),
    );
    expect(invalid.config.text('data.singleChildPolicy'), 'preserve');
    expect(invalid.config.text('data'), 'color-domain');
    expect(invalid.notices, isNotEmpty);
  });

  for (final preset in [
    'data-single-child-promotion',
    'appearance-auto-saturation',
  ]) {
    testWidgets('$preset displays Sixty at depth 1 and stays at root on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(
              config: presetsByKey[preset]!.config.withValues({
                'environment.reducedMotion': true,
              }),
              showToolbar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = _charts(tester).single;
      final state = _scopes(tester).single.notifier!.value;
      expect(chart.tree.nodes.containsKey('b'), isFalse);
      expect(chart.tree.root.children.map((n) => n.key), ['a', 'sixty']);
      expect(state.targetSnapshot!.visibleNodes.map((n) => n.key).toSet(), {
        const TreemapKey.source('a'),
        const TreemapKey.source('sixty'),
      });
      final tile =
          state.targetSnapshot!.index[const TreemapKey.source('sixty')]!;
      final chartOrigin = tester.getTopLeft(find.byType(TreemapChart<String>));
      await tester.tapAt(
        chartOrigin + Offset(tile.bounds.centerX, tile.bounds.centerY),
      );
      await tester.pumpAndSettle();
      expect(chart.controller!.focusKey, const TreemapKey.source('root'));
      expect(chart.controller!.canZoomOut, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'property control commits, resets interaction and restores from history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = PlaygroundStore()..selectPreset('appearance-auto-visible');
      addTearDown(store.dispose);
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
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      await tester.pumpWidget(TreemapExampleApp(store: store));
      await tester.pumpAndSettle();
      final compact = store.location;
      final oldTree = _charts(tester).single.tree;
      _charts(tester).single.controller!.zoomTo('a');
      _charts(tester).single.controller!.select('ten');
      await tester.pumpAndSettle();
      _scopes(tester).single.actions!.hover(const TreemapKey.source('ten'));
      _scopes(tester).single.actions!.focus(const TreemapKey.source('ten'));
      await tester.pumpAndSettle();
      expect(
        _scopes(tester).single.notifier!.value.hoveredKey,
        const TreemapKey.source('ten'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('property-search')),
        'Single-child branches',
      );
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) =>
            w is PropertyEditorField &&
            w.property.key == 'data.singleChildPolicy',
      );
      await tester.tap(
        find.descendant(
          of: field,
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      final pushesBefore = reports.where((r) => r['replace'] == false).length;
      await tester.tap(find.text('Promote').last);
      await tester.pumpAndSettle();
      final state = _scopes(tester).single.notifier!.value;
      expect(store.exampleKey, isNull);
      expect(
        reports.where((r) => r['replace'] == false),
        hasLength(pushesBefore + 1),
      );
      expect(
        store.location.uri.queryParameters['data.singleChildPolicy'],
        'promote',
      );
      expect(_charts(tester).single.tree, isNot(same(oldTree)));
      expect(state.focusKey, const TreemapKey.source('root'));
      expect(state.selectedEntries, isEmpty);
      expect(state.hoveredKey, isNull);
      expect(state.keyboardFocusedKey, isNull);
      expect(state.tooltipKey, isNull);
      final custom = store.location;
      store.restore(compact);
      await tester.pumpAndSettle();
      expect(store.preview.text('data.singleChildPolicy'), 'preserve');
      expect(_charts(tester).single.tree.nodes, contains('b'));
      store.restore(PlaygroundLocationCodec.decode(custom.uri));
      await tester.pumpAndSettle();
      expect(store.historyIntent, HistoryIntent.replace);
      expect(
        reports.where((r) => r['replace'] == false),
        hasLength(pushesBefore + 1),
      );
      expect(store.preview.text('data.singleChildPolicy'), 'promote');
      expect(_charts(tester).single.tree.nodes.containsKey('b'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'policy changes reprepare shared data and reset both charts; style reuses it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var config = presetsByKey['data-prepared-tree']!.config.withValues({
        'tooltip.enabled': true,
      });
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(config: config, showToolbar: false),
          ),
        ),
      );
      await show();
      await tester.pumpAndSettle();
      for (final chart in _charts(tester)) {
        chart.controller!.zoomTo('a');
        chart.controller!.select('ten');
      }
      await tester.pumpAndSettle();
      for (final scope in _scopes(tester)) {
        scope.actions!.hover(const TreemapKey.source('ten'));
      }
      await tester.pumpAndSettle();
      expect(
        _scopes(tester).first.notifier!.value.tooltipKey,
        const TreemapKey.source('ten'),
      );
      final oldTree = _charts(tester).first.tree;
      config = config.withValues({'data.singleChildPolicy': 'promote'});
      await show();
      await tester.pumpAndSettle();
      final tree = _charts(tester).first.tree;
      expect(tree, isNot(same(oldTree)));
      expect(_charts(tester).last.tree, same(tree));
      for (final scope in _scopes(tester)) {
        final state = scope.notifier!.value;
        expect(state.focusKey, const TreemapKey.source('root'));
        expect(state.selectedEntries, isEmpty);
        expect(state.hoveredKey, isNull);
        expect(state.tooltipKey, isNull);
      }
      config = config.withValues({
        'tiles.background': Colors.yellow,
        'layout.innerSpacing': 5,
      });
      await show();
      await tester.pumpAndSettle();
      expect(_charts(tester).first.tree, same(tree));
      expect(_charts(tester).last.tree, same(tree));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing promotion ignores pending isolate results and supplies newly prepared data',
    (tester) async {
      final pending = Completer<TreemapGeometrySnapshot<String>>();
      final inputs = <TreemapNormalizedTree<String>>[];
      TreemapGeometrySnapshot<String>? oldResult;
      var config = presetsByKey['performance-isolate-layout']!.config
          .withValues({'data': 'color-domain'});
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(
              config: config,
              layoutRunner: (tree, viewport, layout) {
                inputs.add(tree);
                final result = TreemapLayoutEngine<String>().layout(
                  tree: tree,
                  viewport: viewport,
                  config: layout,
                );
                if (inputs.length == 1) {
                  oldResult = result;
                  return pending.future;
                }
                return Future.value(result);
              },
            ),
          ),
        ),
      );
      await show();
      await tester.tap(find.byKey(const ValueKey('run-isolate')));
      await tester.pump();
      expect(inputs.single.nodes, contains('b'));
      config = config.withValues({'data.singleChildPolicy': 'promote'});
      await show();
      pending.complete(oldResult!);
      await tester.pumpAndSettle();
      expect(find.byType(ComputedSnapshotView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('run-isolate')));
      await tester.pumpAndSettle();
      expect(inputs, hasLength(2));
      expect(inputs.last.nodes.containsKey('b'), isFalse);
      expect(find.byType(ComputedSnapshotView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
