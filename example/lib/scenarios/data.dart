import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../scenario.dart';

final dataScenarios = <ExampleScenario>[
  ExampleScenario(
    id: 'data-explicit-tree',
    title: 'Explicit immutable tree',
    category: 'Data',
    description:
        'Builds a typed, immutable TreemapNode hierarchy with branch-specific colors. $sampleHierarchyDescription Tile area is proportional to each leaf weight.',
    builder: (_) => TreemapChart<String>(
      root: sampleTree(),
      tiles: sampleTiles(),
      labels: sampleLabels(),
    ),
  ),
  ExampleScenario(
    id: 'data-from-records',
    title: 'Flat records factory',
    category: 'Data',
    description:
        'Groups four flat sales records through TreemapNode.fromRecords: North totals 85 from Mobile 55 and Web 30; South totals 56 from Small business 38 and Enterprise 18. Record mappers provide keys, labels, weights, levels, and colors, then the resulting immutable root is passed to the standard chart constructor.',
    builder: (_) => TreemapChart<String>(
      root: TreemapNode.fromRecords<SalesRecord, String>(
        rootKey: 'root',
        rootLabel: 'Sales',
        records: salesRecords,
        leafKey: (record) => 'product:${record.product}',
        leafLabel: (record) => record.product,
        weight: (record) => record.sales,
        leafColor: (record) => 'product:${record.region}/${record.product}',
        levels: [
          TreemapRecordLevel(
            key: (record) => 'region:${record.region}',
            label: (record) => record.region,
            color: (record) => 'region:${record.region}',
          ),
        ],
      ),
      tiles: sampleTiles(colorScale: salesHierarchyColorScale),
      labels: sampleLabels(colorScale: salesHierarchyColorScale),
    ),
  ),
  ExampleScenario(
    id: 'data-empty-state',
    title: 'Empty and all-zero state',
    category: 'Data and errors',
    description:
        'Supplies one leaf named zero with weight 0. Because the normalized total is also 0, no tile is laid out and the chart returns a neutral SizedBox.shrink. The explicit TreemapNoopTileLayer keeps this geometry-only case free of package-defined text or other visuals.',
    builder: (_) => TreemapChart<String>(
      root: TreemapNode(
        key: 'root',
        children: [TreemapNode(key: 'zero', weight: 0)],
      ),
      tiles: const TreemapNoopTileLayer(),
    ),
  ),
  ExampleScenario(
    id: 'data-invalid-errors',
    title: 'Actionable invalid-input errors',
    category: 'Data and errors',
    description:
        'Attempts to normalize leaf key “bad” with weight double.nan. The page catches TreemapValidationException and displays its typed error code, offending key, explanation, and correction guidance.',
    builder: (_) {
      try {
        TreemapNormalizer.normalize(
          TreemapNode<String>(
            key: 'root',
            children: [TreemapNode(key: 'bad', weight: double.nan)],
          ),
        );
        return const SizedBox.shrink();
      } on TreemapValidationException<String> catch (error) {
        return SelectionArea(child: Text(error.toString()));
      }
    },
  ),
  ExampleScenario(
    id: 'performance-isolate-layout',
    title: 'Optional isolate layout',
    category: 'Performance',
    description:
        'Press the button to lay out 10,000 leaves in a 1,600 × 900 logical-pixel viewport off the UI isolate. Leaf weights repeat from 1 through 11; completion reports the immutable geometry-node count.',
    builder: (_) => const _IsolateLayoutExample(),
  ),
];

class _IsolateLayoutExample extends StatefulWidget {
  const _IsolateLayoutExample();

  @override
  State<_IsolateLayoutExample> createState() => _IsolateLayoutExampleState();
}

class _IsolateLayoutExampleState extends State<_IsolateLayoutExample> {
  Future<TreemapGeometrySnapshot<String>>? pending;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilledButton(
        onPressed: () => setState(() {
          pending = TreemapLayoutEngine<String>().layoutAsync(
            root: manyNodeTree(10000),
            viewport: const TreemapBounds.fromLTWH(0, 0, 1600, 900),
          );
        }),
        child: const Text('Layout 10,000 nodes off the UI isolate'),
      ),
      Expanded(
        child: pending == null
            ? const Center(child: Text('Press the button to start.'))
            : FutureBuilder(
                future: pending,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('${snapshot.error}');
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: Text(
                      'Computed ${snapshot.data!.nodes.length} geometry nodes.',
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
