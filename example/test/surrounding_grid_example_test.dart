import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/scenarios/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screenshot scenario catalogs the surrounding grid', (
    tester,
  ) async {
    final scenario = appearanceScenarios.singleWhere(
      (item) => item.id == 'appearance-screenshot',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: Builder(builder: scenario.builder)),
      ),
    );
    await tester.pump();

    final chart = tester.widget<TreemapChart<String>>(
      find.byType(TreemapChart<String>),
    );
    final grid = chart.surrounding! as TreemapSurroundingGrid<String>;
    expect(grid.topStart, isNotNull);
    expect(grid.topEnd, isNotNull);
    expect(grid.columnGap, 16);
    expect(grid.middleStart, isNull);
    expect(grid.middleEnd, isNull);
    expect(
      find.ancestor(
        of: find.byType(TreemapBreadcrumbsView<String>),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 56,
        ),
      ),
      findsOneWidget,
    );
  });
}
