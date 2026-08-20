import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_labels.dart';
import 'support/pump_app.dart';

TreemapNode<String> _goldenTree() => TreemapNode(
  key: 'root',
  label: 'World',
  children: [
    TreemapNode(
      key: 'north',
      label: 'North',
      children: [
        TreemapNode(key: 'alpha', label: 'Alpha', weight: 8),
        TreemapNode(key: 'beta', label: 'Beta', weight: 5),
      ],
    ),
    TreemapNode(
      key: 'south',
      label: 'South',
      children: [
        TreemapNode(key: 'gamma', label: 'Gamma', weight: 4),
        TreemapNode(key: 'delta', label: 'Delta', weight: 2),
      ],
    ),
  ],
);

void main() {
  testWidgets('default chart visual contract', (tester) async {
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: TreemapChart<String>(
          root: _goldenTree(),
          tiles: testTreemapTiles(),
          layout: TreemapLayoutConfig(
            innerSpacing: 2,
            outerPadding: const TreemapInsets.all(8),
          ),
        ),
      ),
      surfaceSize: const Size(600, 400),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/default.png'),
    );
  });

  testWidgets('default canvas labels use deterministic text rendering', (
    tester,
  ) async {
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: TreemapChart<String>(
          root: _goldenTree(),
          tiles: testTreemapTiles(),
          labels: testTreemapLabels(config: goldenLabelConfig<String>()),
          layout: TreemapLayoutConfig(
            innerSpacing: 2,
            outerPadding: const TreemapInsets.all(8),
          ),
        ),
      ),
      surfaceSize: const Size(600, 400),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/default_labels.png'),
    );
  });

  testWidgets('RTL, text scaling, and alternate origin visual contract', (
    tester,
  ) async {
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: TreemapChart<String>(
          root: _goldenTree(),
          tiles: testTreemapTiles(
            colorScale: TreemapColorScale.interpolated(
              minimum: 2,
              maximum: 8,
              colors: const [Colors.teal, Colors.deepPurple],
              fallback: Colors.grey,
            ),
          ),
          labels: testTreemapLabels(
            colorScale: TreemapColorScale.interpolated(
              minimum: 2,
              maximum: 8,
              colors: const [Colors.teal, Colors.deepPurple],
              fallback: Colors.grey,
            ),
            config: goldenLabelConfig<String>(),
          ),
          layout: TreemapLayoutConfig(
            innerSpacing: 2,
            outerPadding: const TreemapInsets.all(8),
            policy: TreemapLayoutPolicy(
              rootRule: const TreemapLayoutRule(
                algorithm: TreemapLayoutAlgorithm.binaryByWeight,
                direction: TreemapLayoutDirection.topRight,
                axisOrder: TreemapAxisOrder.verticalFirst,
              ),
            ),
          ),
        ),
      ),
      surfaceSize: const Size(600, 400),
      textDirection: TextDirection.rtl,
      textScaler: const TextScaler.linear(1.5),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/rtl_text_scale.png'),
    );
  });
}
