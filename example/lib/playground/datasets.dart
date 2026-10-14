import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import 'config.dart';

final class PlaygroundDataset {
  const PlaygroundDataset(this.key, this.title, this.description, this.create);
  final String key;
  final String title;
  final String description;
  final TreemapNode<String> Function(PlaygroundConfig) create;
}

final datasets = <PlaygroundDataset>[
  PlaygroundDataset(
    'markets',
    'Markets',
    'Consumer 100 and Business 80; six leaves with weights 55, 30, 15, 38, 24 and 18.',
    (config) => marketTree(revision: config.integer('data.revision')),
  ),
  PlaygroundDataset(
    'sales-records',
    'Sales records',
    'Four records grouped by North/South, totaling 85 and 56.',
    _salesTree,
  ),
  PlaygroundDataset(
    'color-domain',
    'Color domain',
    'A = 10 + 30 = 40; B = 60. Revision 1 changes 30 to 90.',
    _domainTree,
  ),
  PlaygroundDataset(
    'categories',
    'Merchant categories',
    'Expenses 19 (Food 6, Transport 5, Other expenses 8) and Unassigned 1.',
    (_) => categoryTree(),
  ),
  PlaygroundDataset(
    'many-nodes',
    'Generated nodes',
    'Stable item keys with repeating weights 1–11. Node count is configurable.',
    (config) => generatedTree(
      config.integer('data.count'),
      revision: config.integer('data.revision'),
    ),
  ),
  PlaygroundDataset(
    'dense-tail',
    'Dense tail',
    '79 substantial nodes followed by tiny .08-weight nodes, demonstrating aggregation and widget limits.',
    _denseTree,
  ),
  PlaygroundDataset(
    'direct-colors',
    'Direct colors',
    'Indigo, teal and purple Flutter colors on leaves of weights 50, 30 and 20.',
    (_) => TreemapNode(
      key: 'root',
      children: [
        TreemapNode(
          key: 'direct-indigo',
          label: 'Direct indigo',
          weight: 50,
          color: Colors.indigo,
        ),
        TreemapNode(
          key: 'direct-teal',
          label: 'Direct teal',
          weight: 30,
          color: Colors.teal,
        ),
        TreemapNode(
          key: 'direct-purple',
          label: 'Direct purple',
          weight: 20,
          color: Colors.deepPurple,
        ),
      ],
    ),
  ),
  PlaygroundDataset(
    'opacity-groups',
    'Opacity groups',
    'Two groups with eight substantial leaves and eight tiny leaves, using blue and pink opacity palettes.',
    (_) => opacityTree(),
  ),
  PlaygroundDataset(
    'standalone-values',
    'Standalone values',
    'Three numeric leaves: 15, 30 and 55.',
    (_) => TreemapNode(
      key: 'root',
      children: [
        for (final value in [15.0, 30.0, 55.0])
          TreemapNode(
            key: value.toString(),
            label: value.round().toString(),
            weight: value,
          ),
      ],
    ),
  ),
  PlaygroundDataset(
    'all-zero',
    'All zero',
    'One zero-weight leaf; no positive geometry is produced.',
    (_) => TreemapNode(
      key: 'root',
      children: [TreemapNode(key: 'zero', weight: 0)],
    ),
  ),
  PlaygroundDataset(
    'invalid-weight',
    'Invalid weight',
    'Deliberately supplies NaN for key bad; validation mode displays the typed error.',
    (_) => TreemapNode(
      key: 'root',
      children: [TreemapNode(key: 'bad', weight: double.nan)],
    ),
  ),
];

final datasetsByKey = {for (final dataset in datasets) dataset.key: dataset};

TreemapNode<String> createData(PlaygroundConfig config) {
  var root = datasetsByKey[config.text('data')]!.create(config);
  final grouping = config.text('data.grouping');
  if (grouping != 'hierarchy') {
    root = root.copyWith(
      children: grouping == 'flat'
          ? sourceLeaves(root).toList()
          : [
              for (final child in root.children)
                if (child.isLeaf) child else ...child.children,
            ],
    );
  }
  final input = config.text('color.input');
  if (input == 'source' || config.text('data') == 'invalid-weight') return root;
  final normalized = TreemapNormalizer.normalize(root);
  TreemapNode<String> convert(TreemapNode<String> node, int index) =>
      TreemapNode(
        key: node.key,
        weight: node.weight,
        label: node.label,
        valueLabel: node.valueLabel,
        semanticLabel: node.semanticLabel,
        data: node.data,
        color: switch (input) {
          'numeric' => normalized.totals[node.key],
          'category' => node.key,
          'direct' =>
            hierarchyPalette[node.key] ??
                generatedPalette[index % generatedPalette.length],
          _ => null,
        },
        children: node.children.indexed.map(
          (entry) => convert(entry.$2, index + entry.$1 + 1),
        ),
      );
  return convert(root, 0);
}

Iterable<TreemapNode<String>> sourceLeaves(TreemapNode<String> node) sync* {
  if (node.isLeaf) {
    yield node;
  } else {
    for (final child in node.children) {
      yield* sourceLeaves(child);
    }
  }
}

const hierarchyPalette = <String, Color>{
  'consumer': Color(0xFF303F9F),
  'mobile': Color(0xFF4F5FC4),
  'web': Color(0xFF6978D1),
  'desktop': Color(0xFF8994DE),
  'business': Color(0xFFE65100),
  'small': Color(0xFFF57C00),
  'medium': Color(0xFFFF9800),
  'enterprise': Color(0xFFFFB74D),
};
const generatedPalette = [
  Color(0xFF4527A0),
  Color(0xFF3949AB),
  Color(0xFF039BE5),
  Color(0xFF00897B),
];

TreemapColorScale suggestedScale(TreemapNode<String> root, Color fallback) {
  final colors = <Object?, Color>{};
  final totals = TreemapNormalizer.normalize(root).totals;
  void visit(TreemapNode<String> node, int index) {
    final value = node.color ?? totals[node.key];
    colors[value] =
        hierarchyPalette[node.key] ??
        generatedPalette[index % generatedPalette.length];
    for (final entry in node.children.indexed) {
      visit(entry.$2, index + entry.$1 + 1);
    }
  }

  for (final entry in root.children.indexed) {
    visit(entry.$2, entry.$1);
  }
  return TreemapColorScale.exact(colors, fallback: fallback);
}

TreemapNode<String> marketTree({
  int revision = 0,
  bool numericColors = false,
}) => TreemapNode(
  key: 'root',
  label: 'All markets',
  children: [
    TreemapNode(
      key: 'consumer',
      label: 'Consumer',
      color: 'consumer',
      children: [
        TreemapNode(
          key: 'mobile',
          label: 'Mobile',
          weight: 55 + revision * 20.0,
          color: numericColors ? 55 + revision * 20.0 : 'consumer/mobile',
        ),
        TreemapNode(
          key: 'web',
          label: 'Web',
          weight: 30,
          color: numericColors ? 30 : 'consumer/web',
        ),
        TreemapNode(
          key: 'desktop',
          label: 'Desktop',
          weight: 15,
          color: numericColors ? 15 : 'consumer/desktop',
        ),
      ],
    ),
    TreemapNode(
      key: 'business',
      label: 'Business',
      color: 'business',
      children: [
        TreemapNode(
          key: 'small',
          label: 'Small',
          weight: 38,
          color: numericColors ? 38 : 'business/small',
        ),
        TreemapNode(
          key: 'medium',
          label: 'Medium',
          weight: 24,
          color: numericColors ? 24 : 'business/medium',
        ),
        TreemapNode(
          key: 'enterprise',
          label: 'Enterprise',
          weight: 18,
          color: numericColors ? 18 : 'business/enterprise',
        ),
      ],
    ),
  ],
);

typedef SalesRecord = ({String region, String product, double sales});
const salesRecords = <SalesRecord>[
  (region: 'North', product: 'Mobile', sales: 55),
  (region: 'North', product: 'Web', sales: 30),
  (region: 'South', product: 'Small business', sales: 38),
  (region: 'South', product: 'Enterprise', sales: 18),
];

TreemapNode<String> _salesTree(PlaygroundConfig config) {
  if (config.text('data.construction') == 'fromRecords') {
    return TreemapNode.fromRecords<SalesRecord, String>(
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
    );
  }
  return TreemapNode(
    key: 'root',
    label: 'Sales',
    children: [
      for (final region in ['North', 'South'])
        TreemapNode(
          key: 'region:$region',
          label: region,
          color: 'region:$region',
          children: [
            for (final record in salesRecords.where(
              (record) => record.region == region,
            ))
              TreemapNode(
                key: 'product:${record.product}',
                label: record.product,
                weight: record.sales,
                color: 'product:$region/${record.product}',
              ),
          ],
        ),
    ],
  );
}

TreemapNode<String> _domainTree(PlaygroundConfig config) => TreemapNode(
  key: 'root',
  label: 'All',
  children: [
    TreemapNode(
      key: 'a',
      label: 'A',
      children: [
        TreemapNode(key: 'ten', label: 'Ten', weight: 10),
        TreemapNode(
          key: 'changing',
          label: config.integer('data.revision').isOdd ? 'Ninety' : 'Thirty',
          weight: config.integer('data.revision').isOdd ? 90 : 30,
        ),
      ],
    ),
    TreemapNode(
      key: 'b',
      label: 'B',
      children: [TreemapNode(key: 'sixty', label: 'Sixty', weight: 60)],
    ),
  ],
);

TreemapNode<String> categoryTree() => TreemapNode(
  key: 'merchants',
  label: 'All merchants',
  children: [
    TreemapNode(
      key: 'expenses',
      label: 'Expenses',
      children: [
        TreemapNode(
          key: 'food',
          label: 'Food',
          children: [
            TreemapNode(key: 'groceries', label: 'Groceries', weight: 4),
            TreemapNode(key: 'cafes', label: 'Cafes', weight: 2),
          ],
        ),
        TreemapNode(key: 'transport', label: 'Transport', weight: 5),
        TreemapNode(
          key: 'other-expenses',
          label: 'Other expenses',
          children: [
            for (final entry in [
              ('rent', 'Rent'),
              ('utilities', 'Utilities'),
              ('pharmacy', 'Pharmacy'),
              ('games', 'Games'),
            ])
              TreemapNode(key: entry.$1, label: entry.$2, weight: 2),
          ],
        ),
      ],
    ),
    TreemapNode(key: 'unassigned', label: 'Unassigned', weight: 1),
  ],
);

TreemapNode<String> generatedTree(int count, {int revision = 0}) => TreemapNode(
  key: 'root',
  label: 'Many nodes',
  children: [
    for (var index = 0; index < count; index++)
      TreemapNode(
        key: 'item-$index',
        label: 'Item $index',
        weight: (index % 11 + 1 + (index == 0 ? revision : 0)).toDouble(),
        color: index.toDouble(),
      ),
  ],
);

TreemapNode<String> _denseTree(PlaygroundConfig config) => TreemapNode(
  key: 'root',
  label: 'Virtualized items',
  children: [
    for (var index = 0; index < config.integer('data.count'); index++)
      TreemapNode(
        key: 'item-$index',
        label: 'Item $index',
        weight: index < 79 ? (8 + index % 4).toDouble() : .08,
        color: index.toDouble(),
      ),
  ],
);

const blueOpacityPalette = [
  Color(0xFF0B63F6),
  Color(0xE00B63F6),
  Color(0xC20B63F6),
  Color(0xA30B63F6),
  Color(0x850B63F6),
  Color(0x660B63F6),
  Color(0x4D0B63F6),
  Color(0x330B63F6),
];
const pinkOpacityPalette = [
  Color(0xFFEC168C),
  Color(0xE0EC168C),
  Color(0xC2EC168C),
  Color(0xA3EC168C),
  Color(0x85EC168C),
  Color(0x66EC168C),
  Color(0x4DEC168C),
  Color(0x33EC168C),
];

TreemapNode<String> opacityTree() => TreemapNode(
  key: 'screenshot-root',
  label: 'Level 2',
  children: [
    for (final entry in [
      ('screenshot-blue', 'Blue', blueOpacityPalette),
      ('screenshot-pink', 'Pink', pinkOpacityPalette),
    ])
      TreemapNode(
        key: entry.$1,
        label: entry.$2,
        color: Colors.transparent,
        children: [
          for (var index = 0; index < 16; index++)
            TreemapNode(
              key: '${entry.$1}-item-$index',
              label: '${entry.$2} ${index + 1}',
              weight: index < 8
                  ? [28.0, 24.0, 20.0, 18.0, 16.0, 14.0, 12.0, 10.0][index]
                  : .9,
              color: entry.$3[index % 8],
            ),
        ],
      ),
  ],
);
