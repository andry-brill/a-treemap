import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shared-tree preset reuses preparation and keeps each chart independent',
    (tester) async {
      final config = presetsByKey['data-prepared-tree']!.config;
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> show(Color color, {bool flat = false}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(
              config: config.withValues({
                'tiles.background': color,
                'data.grouping': flat ? 'flat' : 'hierarchy',
              }),
              showToolbar: false,
            ),
          ),
        ),
      );
      await show(Colors.white);
      await tester.pumpAndSettle();
      List<TreemapChart<String>> charts() => tester
          .widgetList<TreemapChart<String>>(find.byType(TreemapChart<String>))
          .toList();
      List<TreemapPresentationScope<String>> scopes() => tester
          .widgetList<TreemapPresentationScope<String>>(
            find.byType(TreemapPresentationScope<String>),
          )
          .toList();
      final tree = charts().first.tree;
      expect(charts(), hasLength(2));
      expect(charts().last.tree, same(tree));
      final scale = TreemapColorScale.interpolated(
        colors: const [Colors.blue, Colors.red],
        fallback: Colors.grey,
        domainScope: TreemapColorDomainScope.visible,
      );
      expect(
        scopes().first.notifier!.value.resolveColorScale(scale).minimum,
        40,
      );
      expect(
        scopes().last.notifier!.value.resolveColorScale(scale).minimum,
        40,
      );
      charts().first.controller!.zoomTo('a');
      await tester.pumpAndSettle();
      expect(
        scopes().first.notifier!.value.resolveColorScale(scale).minimum,
        10,
      );
      expect(
        scopes().first.notifier!.value.resolveColorScale(scale).maximum,
        30,
      );
      expect(
        scopes().last.notifier!.value.resolveColorScale(scale).minimum,
        40,
      );
      expect(
        scopes().last.notifier!.value.focusKey,
        const TreemapKey.source('root'),
      );
      final leaf =
          scopes().first.notifier!.value.targetSnapshot!.visibleNodes.first.key;
      scopes().first.actions!.hover(leaf);
      await tester.pumpAndSettle();
      expect(scopes().first.notifier!.value.hoveredKey, leaf);
      expect(scopes().last.notifier!.value.hoveredKey, isNull);
      await show(Colors.yellow);
      await tester.pumpAndSettle();
      expect(charts().first.tree, same(tree));
      expect(charts().last.tree, same(tree));
      expect(scopes().first.notifier!.value.hoveredKey, leaf);
      expect(find.byTooltip('Back in Left chart'), findsOneWidget);
      await show(Colors.yellow, flat: true);
      await tester.pumpAndSettle();
      expect(
        scopes().first.notifier!.value.focusKey,
        const TreemapKey.source('root'),
      );
      expect(find.byTooltip('Back in Left chart'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'presentation preset exposes custom keyed focus and activation actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(
              config: presetsByKey['appearance-presentation-state']!.config,
              showToolbar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byType(TreemapPresentationScope<String>);
      TreemapPresentationState<String> state() => tester
          .widget<TreemapPresentationScope<String>>(finder)
          .notifier!
          .value;
      expect(state().keyboardFocusedKey, isNull);
      await tester.tap(find.byTooltip('Focus a tile'));
      await tester.pumpAndSettle();
      expect(state().keyboardFocusedKey, const TreemapKey.source('a'));
      await tester.tap(find.byTooltip('Activate focused tile'));
      await tester.pumpAndSettle();
      expect(state().focusKey, const TreemapKey.source('a'));
      expect(state().keyboardFocusedKey, isNull);
      expect(
        state().targetSnapshot!.visibleNodes.map((node) => node.weight),
        unorderedEquals([10, 30]),
      );
      expect(find.text('10'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
