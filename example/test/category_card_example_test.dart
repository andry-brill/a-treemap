import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category depth, grouping and drill-down share configuration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var config = presetsByKey['layout-category-card']!.config;
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlaygroundPreview(config: config)),
        ),
      );
      await tester.pumpAndSettle();
    }

    final chartFinder = find.byType(TreemapChart<String>);
    TreemapChart<String> chart() => tester.widget(chartFinder);
    Finder chartText(String text) =>
        find.descendant(of: chartFinder, matching: find.text(text));
    await show();
    expect(chartText('Groceries'), findsOneWidget);
    for (final label in [
      'Expenses',
      '19',
      'Food',
      '6',
      'Other expenses',
      '8',
    ]) {
      expect(chartText(label), findsOneWidget);
    }
    config = config.withValues({'layout.maxVisibleDepth': 1});
    await show();
    expect(chartText('Expenses'), findsOneWidget);
    expect(chartText('19'), findsOneWidget);
    expect(chartText('Groceries'), findsNothing);
    expect(
      find.text('Groceries'),
      findsOneWidget,
    ); // Hierarchy retains hidden source data.
    config = config.withValues({'layout.maxVisibleDepth': 2});
    await show();
    for (final label in ['Food', 'Transport', 'Other expenses', 'Unassigned']) {
      expect(chartText(label), findsOneWidget);
    }
    config = config.withValues({'layout.maxVisibleDepth': 1});
    await show();
    await tester.tapAt(tester.getCenter(chartText('Expenses')));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('expenses'));
    await tester.tapAt(tester.getCenter(chartText('Food')));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('food'));
    expect(chartText('Groceries'), findsOneWidget);
    config = config.withValues({'layout.maxVisibleDepth': null});
    await show();
    expect(chart().controller!.focusKey, const TreemapKey.source('food'));
    await tester.tap(find.byKey(const ValueKey('preview-back')));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('expenses'));
    config = config.withValues({
      'data.grouping': 'level2',
      'layout.maxVisibleDepth': 1,
    });
    await show();
    expect(chart().controller!.focusKey, const TreemapKey.source('merchants'));
    expect(chartText('Food'), findsOneWidget);
    expect(chartText('Groceries'), findsNothing);
    config = config.withValues({'data.grouping': 'flat'});
    await show();
    expect(chartText('Groceries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
