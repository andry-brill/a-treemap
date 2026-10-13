import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/category_card_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visible depth controls the chart independently of grouping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CategoryCardExample())),
    );
    await tester.pumpAndSettle();
    final chartFinder = find.byType(TreemapChart<String>);
    TreemapChart<String> chart() => tester.widget(chartFinder);
    Finder chartText(String text) =>
        find.descendant(of: chartFinder, matching: find.text(text));
    final control = find.byType(SegmentedButton<int?>);
    expect(chart().layout.maxVisibleDepth, isNull);
    expect(tester.widget<SegmentedButton<int?>>(control).selected, {null});
    expect(
      tester.getBottomLeft(control).dy,
      lessThan(tester.getTopLeft(chartFinder).dy),
    );
    expect(chartText('Groceries'), findsOneWidget);

    await tester.tap(find.text('Depth 1'));
    await tester.pumpAndSettle();
    expect(chart().layout.maxVisibleDepth, 1);
    expect(chartText('Expenses'), findsOneWidget);
    expect(chartText('19'), findsOneWidget);
    expect(chartText('Unassigned'), findsOneWidget);
    expect(chartText('Groceries'), findsNothing);
    // The source hierarchy below the chart still includes hidden descendants.
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Depth 2'));
    await tester.pumpAndSettle();
    expect(chart().layout.maxVisibleDepth, 2);
    for (final label in ['Food', 'Transport', 'Other expenses', 'Unassigned']) {
      expect(chartText(label), findsOneWidget);
    }
    expect(chartText('Groceries'), findsNothing);

    await tester.tap(find.text('Depth 1'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(chartText('Expenses')));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('expenses'));
    expect(chartText('Food'), findsOneWidget);
    await tester.tapAt(tester.getCenter(chartText('Food')));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('food'));
    expect(chartText('Groceries'), findsOneWidget);
    expect(chartText('Cafes'), findsOneWidget);

    await tester.tap(find.text('All (null)'));
    await tester.pumpAndSettle();
    expect(chart().layout.maxVisibleDepth, isNull);
    expect(chart().controller!.focusKey, const TreemapKey.source('food'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('expenses'));

    await tester.tap(find.text('Depth 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();
    expect(chart().controller!.focusKey, const TreemapKey.source('merchants'));
    expect(chart().layout.maxVisibleDepth, 1);
    expect(chartText('Food'), findsOneWidget);
    expect(chartText('Groceries'), findsNothing);
    await tester.tap(find.text('Flat'));
    await tester.pumpAndSettle();
    expect(chart().layout.maxVisibleDepth, 1);
    expect(chartText('Groceries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
