import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

final class _EqualColumns implements ITreemapLayoutStrategy<String> {
  @override
  Map<TreemapKey<String>, TreemapBounds> layout(
    TreemapStrategyInput<String> input,
  ) {
    final width = input.bounds.width / input.items.length;
    return {
      for (final entry in input.items.indexed)
        entry.$2.key: TreemapBounds.fromLTWH(
          input.bounds.left + width * entry.$1,
          input.bounds.top,
          width,
          input.bounds.height,
        ),
    };
  }
}

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(key: 'a', label: 'A', weight: 8),
    TreemapNode(key: 'b', label: 'B', weight: 2),
  ],
);

void main() {
  test('custom strategy substitutes behind the public invariant contract', () {
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: _tree(),
      viewport: const TreemapBounds.fromLTWH(0, 0, 200, 100),
      config: TreemapLayoutConfig(
        policy: TreemapLayoutPolicy(
          rootRule: TreemapLayoutRule(strategy: _EqualColumns()),
        ),
      ),
    );
    expect(snapshot.index[const TreemapKey.source('a')]!.bounds.width, 100);
    expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
  });

  test('optional isolate layout preserves keys and geometry', () async {
    final engine = TreemapLayoutEngine<String>();
    final synchronous = engine.layout(
      root: _tree(),
      viewport: const TreemapBounds.fromLTWH(0, 0, 200, 100),
    );
    final isolated = await engine.layoutAsync(
      root: _tree(),
      viewport: const TreemapBounds.fromLTWH(0, 0, 200, 100),
      fallbackToSynchronous: false,
    );
    expect(isolated.index.keys, unorderedEquals(synchronous.index.keys));
    for (final key in synchronous.index.keys) {
      expect(isolated.index[key]!.bounds, synchronous.index[key]!.bounds);
    }
  });

  testWidgets('a fromRecords node uses the standard chart contract', (
    tester,
  ) async {
    final records = [
      (region: 'North', item: 'A', value: 3.0),
      (region: 'South', item: 'B', value: 2.0),
    ];
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      TreemapChart<String>(
        root:
            TreemapNode.fromRecords<
              ({String region, String item, double value}),
              String
            >(
              rootKey: 'root',
              records: records,
              leafKey: (record) => record.item,
              weight: (record) => record.value,
              levels: [
                TreemapRecordLevel(
                  key: (record) => 'region:${record.region}',
                  label: (record) => record.region,
                ),
              ],
            ),
        tiles: testTreemapTiles(),
        labels: testTreemapLabels(),
        onSnapshot: (value) => snapshot = value,
      ),
    );
    expect(snapshot!.nodes, hasLength(4));
    expect(TreemapGeometryDiagnostics.validate(snapshot!), isEmpty);
  });

  test('configuration copies retain callbacks and compare stable values', () {
    void tap(TreemapNodeDetails<String> _) {}
    final interaction = TreemapInteractionConfig<String>(onNodeTap: tap);
    expect(interaction.copyWith(enabled: false).onNodeTap, same(tap));

    const tooltip = TreemapTooltipConfig();
    expect(
      tooltip.copyWith(placement: TreemapTooltipPlacement.left),
      tooltip.copyWith(placement: TreemapTooltipPlacement.left),
    );
    expect(
      const TreemapAppearance(color: Colors.blue),
      const TreemapAppearance(color: Colors.blue),
    );
  });
}
