import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../scenario.dart';

Widget _layoutChart(TreemapLayoutConfig<String> layout) {
  final style = TreemapStyle(
    tileAppearance: const TreemapAppearance(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
  );
  return TreemapChart<String>(
    root: sampleTree(),
    tiles: sampleTiles(style: style),
    labels: sampleLabels(style: style),
    layout: layout,
    transition: const TreemapTransitionSpec(
      duration: Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    ),
    clipBehavior: Clip.hardEdge,
  );
}

ExampleScenario _algorithm({
  required String id,
  required String title,
  required String description,
  required TreemapLayoutAlgorithm algorithm,
}) => ExampleScenario(
  id: id,
  title: title,
  category: 'Layout algorithms',
  description:
      '$description $sampleHierarchyDescription The chart also applies 3 px inner spacing, 8 px outer padding, 6 px corners, and a 450 ms keyed transition.',
  builder: (_) => _layoutChart(
    TreemapLayoutConfig(
      innerSpacing: 3,
      outerPadding: const TreemapInsets.all(8),
      policy: TreemapLayoutPolicy(
        rootRule: TreemapLayoutRule(algorithm: algorithm),
      ),
    ),
  ),
);

final class ExampleEqualColumnsStrategy
    implements ITreemapLayoutStrategy<String> {
  @override
  Map<TreemapKey<String>, TreemapBounds> layout(
    TreemapStrategyInput<String> input,
  ) {
    final width = input.bounds.width / input.items.length;
    return {
      for (final entry in input.items.indexed)
        entry.$2.key: TreemapBounds.fromLTWH(
          input.bounds.left + entry.$1 * width,
          input.bounds.top,
          width,
          input.bounds.height,
        ),
    };
  }
}

final layoutScenarios = <ExampleScenario>[
  _algorithm(
    id: 'layout-squarified',
    title: 'Squarified',
    description:
        'Uses the squarified strategy to keep weighted tiles close to square while preserving their areas.',
    algorithm: TreemapLayoutAlgorithm.squarified,
  ),
  _algorithm(
    id: 'layout-resquarified',
    title: 'Resquarified updates',
    description:
        'Uses topology-stable resquarification so keyed data updates move tiles with less visual disruption.',
    algorithm: TreemapLayoutAlgorithm.resquarified,
  ),
  _algorithm(
    id: 'layout-slice',
    title: 'Slice',
    description:
        'Partitions weighted nodes into horizontal slices spanning the available chart width.',
    algorithm: TreemapLayoutAlgorithm.slice,
  ),
  _algorithm(
    id: 'layout-dice',
    title: 'Dice',
    description:
        'Partitions weighted nodes into vertical columns spanning the available chart height.',
    algorithm: TreemapLayoutAlgorithm.dice,
  ),
  _algorithm(
    id: 'layout-alternating',
    title: 'Alternating slice/dice',
    description:
        'Alternates horizontal and vertical slicing at successive hierarchy depths.',
    algorithm: TreemapLayoutAlgorithm.alternatingSliceDice,
  ),
  _algorithm(
    id: 'layout-strip',
    title: 'Strip',
    description:
        'Arranges nodes into ordered strips while balancing aspect ratio and stable sequence.',
    algorithm: TreemapLayoutAlgorithm.strip,
  ),
  _algorithm(
    id: 'layout-binary-weight',
    title: 'Binary by weight',
    description:
        'Recursively splits the viewport into two groups with approximately balanced total weight.',
    algorithm: TreemapLayoutAlgorithm.binaryByWeight,
  ),
  _algorithm(
    id: 'layout-binary-count',
    title: 'Binary by count',
    description:
        'Recursively splits nodes into similarly sized groups by item count rather than total weight.',
    algorithm: TreemapLayoutAlgorithm.binaryByCount,
  ),
  ExampleScenario(
    id: 'layout-multilevel',
    title: 'Mixed multilevel policy',
    category: 'Layout policy',
    description:
        'Combines a binary-by-weight root, strip at child depth 2, dice under parent key “business”, and squarified when a resolver sees more than four children. $sampleHierarchyDescription',
    builder: (_) => _layoutChart(
      TreemapLayoutConfig(
        innerSpacing: 3,
        policy: TreemapLayoutPolicy(
          rootRule: const TreemapLayoutRule(
            algorithm: TreemapLayoutAlgorithm.binaryByWeight,
          ),
          byChildDepth: const {
            2: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.strip),
          },
          byParentKey: const {
            'business': TreemapLayoutRule(
              algorithm: TreemapLayoutAlgorithm.dice,
            ),
          },
          resolver: (context) => context.children.length > 4
              ? const TreemapLayoutRule(
                  algorithm: TreemapLayoutAlgorithm.squarified,
                )
              : null,
        ),
      ),
    ),
  ),
  ExampleScenario(
    id: 'layout-sort-policies',
    title: 'Stable ascending sort',
    category: 'Layout policy',
    description:
        'Orders siblings by ascending weight while retaining source order for ties. In Consumer the visible order is Desktop 15, Web 30, Mobile 55; Business is Enterprise 18, Medium 24, Small 38.',
    builder: (_) => _layoutChart(
      TreemapLayoutConfig(
        policy: TreemapLayoutPolicy(
          rootRule: const TreemapLayoutRule(sort: TreemapSortPolicy.ascending),
        ),
      ),
    ),
  ),
  ExampleScenario(
    id: 'layout-four-origins',
    title: 'Four origins',
    category: 'Layout policy',
    description:
        'Renders the same six weighted leaves in a 2 × 2 grid using top-left, top-right, bottom-left, and bottom-right origins. Top-row labels sit before their charts and bottom-row labels after them, keeping every title outside painted geometry. $sampleHierarchyDescription',
    builder: (_) => Column(
      children: [
        for (var row = 0; row < 2; row++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++)
                  Expanded(
                    child: _OriginCard(
                      direction:
                          TreemapLayoutDirection.values[row * 2 + column],
                      captionAbove: row == 0,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  ),
  ExampleScenario(
    id: 'layout-axis-orders',
    title: 'Primary-axis orders',
    category: 'Layout policy',
    description:
        'Compares horizontal-first and vertical-first binary-by-weight splitting in square viewports over the same 180 total weight. Binary layout normally splits the longer side; equal width and height make axisOrder choose whether Consumer 100 and Business 80 begin as columns or rows. $sampleHierarchyDescription',
    builder: (_) => Row(
      children: [
        for (final axis in TreemapAxisOrder.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _ChartCaption(axis.name),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _layoutChart(
                          TreemapLayoutConfig(
                            policy: TreemapLayoutPolicy(
                              rootRule: TreemapLayoutRule(
                                algorithm:
                                    TreemapLayoutAlgorithm.binaryByWeight,
                                axisOrder: axis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ),
  ExampleScenario(
    id: 'layout-minimum-aggregation',
    title: 'Minimum size and Other',
    category: 'Responsive layout',
    description:
        'Lays out 40 leaves whose weights cycle from 1 through 11. Tiles below the explicit 70 × 32 layout minimum are combined into a generated Other node; labels include the active locale code and aggregate weight.',
    builder: (_) => TreemapChart<String>(
      root: manyNodeTree(),
      tiles: sampleTiles(colorScale: manyNodeColorScale()),
      labels: sampleLabels(
        colorScale: manyNodeColorScale(),
        config: TreemapLabelConfig(
          localizedValueFormatter: (details, locale) =>
              '${locale.languageCode}: ${details.weight}',
        ),
      ),
      layout: TreemapLayoutConfig(
        minimumWidth: 70,
        minimumHeight: 32,
        minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
        insufficientSpacePolicy: TreemapInsufficientSpacePolicy.show,
      ),
    ),
  ),
  ExampleScenario(
    id: 'layout-custom-strategy',
    title: 'Custom strategy',
    category: 'Extension points',
    description:
        'Implements ITreemapLayoutStrategy directly: each parent divides its bounds into equal-width columns by child count, independent of weight. Compare those columns against Mobile 55, Web 30, Desktop 15 and the Business values 38, 24, 18.',
    builder: (_) => _layoutChart(
      TreemapLayoutConfig(
        policy: TreemapLayoutPolicy(
          rootRule: TreemapLayoutRule(strategy: ExampleEqualColumnsStrategy()),
        ),
      ),
    ),
  ),
];

class _ChartCaption extends StatelessWidget {
  const _ChartCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.direction, required this.captionAbove});

  final TreemapLayoutDirection direction;
  final bool captionAbove;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        if (captionAbove) _ChartCaption(direction.name),
        Expanded(
          child: _layoutChart(
            TreemapLayoutConfig(
              policy: TreemapLayoutPolicy(
                rootRule: TreemapLayoutRule(direction: direction),
              ),
            ),
          ),
        ),
        if (!captionAbove) _ChartCaption(direction.name),
      ],
    ),
  );
}
