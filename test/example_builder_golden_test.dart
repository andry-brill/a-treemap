import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('builder example keeps Other near its minimum visual contract', (
    tester,
  ) async {
    final scenario = allScenarios.singleWhere(
      (item) => item.id == 'appearance-builders-virtualized',
    );
    await tester.pumpTreemapApp(
      Material(child: Builder(builder: scenario.builder)),
      surfaceSize: const Size(1000, 700),
    );
    await tester.pump();
    final scenarioChart = tester.widget<TreemapChart<String>>(
      find.byType(TreemapChart<String>),
    );

    TreemapGeometrySnapshot<String>? snapshot;
    final appearance = TreemapAppearanceResolver<String>(
      colorScale: TreemapColorScale.interpolated(
        minimum: 0,
        maximum: 119,
        colors: const [Color(0xFF314A91), Color(0xFF5B8FE0)],
        fallback: const Color(0xFF4568B2),
      ),
      style: const TreemapStyle(backgroundColor: Colors.white),
      nodeStyleResolver: (context, details, states) => details.isAggregate
          ? const TreemapAppearance(color: Color(0xFFF28C28))
          : null,
    );
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('builder-aggregation-golden'),
        child: TreemapChart<String>(
          root: scenarioChart.root,
          layout: scenarioChart.layout,
          tiles: TreemapTiles(appearance: appearance),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
      surfaceSize: const Size(1000, 700),
    );
    await tester.pump();

    final visibleNodes = snapshot!.visibleNodes.toList(growable: false);
    final aggregate = visibleNodes.singleWhere((node) => node.isAggregate);
    expect(visibleNodes, hasLength(80));
    expect(aggregate.aggregateMembers, hasLength(41));
    expect(aggregate.bounds.width, inInclusiveRange(70, 100));
    expect(aggregate.bounds.height, inInclusiveRange(25, 55));

    await expectLater(
      find.byKey(const ValueKey('builder-aggregation-golden')),
      matchesGoldenFile('goldens/example_builder_aggregation.png'),
    );
  });
}
