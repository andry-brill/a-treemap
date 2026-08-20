import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';
// ignore: avoid_relative_lib_imports
import '../example/lib/sample_data.dart';

Future<void> _pumpScenario(
  WidgetTester tester,
  String id, {
  Size size = const Size(900, 760),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final scenario = allScenarios.singleWhere((item) => item.id == id);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('layout-example'),
          child: Builder(builder: scenario.builder),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpLabelFreeGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(900, 760),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('layout-example'),
          child: ColoredBox(color: Colors.white, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _labelFreeChart(TreemapLayoutConfig<String> layout) =>
    TreemapChart<String>(
      root: sampleTree(),
      tiles: sampleTiles(),
      layout: layout,
      transition: const TreemapTransitionSpec(
        duration: Duration.zero,
        curve: Curves.linear,
      ),
      clipBehavior: Clip.hardEdge,
    );

void main() {
  testWidgets('four-origin captions stay outside their chart rectangles', (
    tester,
  ) async {
    await _pumpScenario(tester, 'layout-four-origins');

    final charts = find.byType(TreemapChart<String>);
    expect(charts, findsNWidgets(4));
    final chartElements = charts.evaluate().toList();

    for (final entry in TreemapLayoutDirection.values.indexed) {
      final labelRect = tester.getRect(find.text(entry.$2.name));
      final chartRect = tester.getRect(
        find.byWidget(chartElements[entry.$1].widget),
      );
      if (entry.$1 < 2) {
        expect(labelRect.bottom, lessThanOrEqualTo(chartRect.top));
      } else {
        expect(labelRect.top, greaterThanOrEqualTo(chartRect.bottom));
      }
      expect(labelRect.overlaps(chartRect), isFalse);
    }
  });

  testWidgets('four-origin geometry visual contract without labels', (
    tester,
  ) async {
    await _pumpLabelFreeGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var row = 0; row < 2; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < 2; column++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _labelFreeChart(
                            TreemapLayoutConfig(
                              policy: TreemapLayoutPolicy(
                                rootRule: TreemapLayoutRule(
                                  direction: TreemapLayoutDirection
                                      .values[row * 2 + column],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('layout-example')),
      matchesGoldenFile('goldens/example_four_origins.png'),
    );
  });

  testWidgets('axis-order comparison supplies square chart viewports', (
    tester,
  ) async {
    await _pumpScenario(tester, 'layout-axis-orders');

    expect(find.text('horizontalFirst'), findsOneWidget);
    expect(find.text('verticalFirst'), findsOneWidget);
    final charts = find.byType(TreemapChart<String>);
    expect(charts, findsNWidgets(2));
    for (final chart in charts.evaluate()) {
      final size = tester.getSize(find.byWidget(chart.widget));
      expect(size.width, closeTo(size.height, .001));
    }
  });

  testWidgets('axis-order geometry visual contract without labels', (
    tester,
  ) async {
    await _pumpLabelFreeGolden(
      tester,
      Row(
        children: [
          for (final axis in TreemapAxisOrder.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _labelFreeChart(
                      TreemapLayoutConfig(
                        policy: TreemapLayoutPolicy(
                          rootRule: TreemapLayoutRule(
                            algorithm: TreemapLayoutAlgorithm.binaryByWeight,
                            axisOrder: axis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('layout-example')),
      matchesGoldenFile('goldens/example_axis_orders.png'),
    );
  });
}
