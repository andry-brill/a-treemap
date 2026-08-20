import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

const sampleHierarchyDescription =
    'Data: Consumer totals 100 from Mobile 55, Web 30, and Desktop 15; '
    'Business totals 80 from Small 38, Medium 24, and Enterprise 18.';

/// The default catalog palette uses one hue per branch and a distinct tone for
/// every child. This makes adjacent tiles easy to distinguish while preserving
/// their visual relationship to the parent branch.
final sampleHierarchyColorScale = TreemapColorScale.exact(const {
  'consumer': Color(0xFF303F9F),
  'consumer/mobile': Color(0xFF4F5FC4),
  'consumer/web': Color(0xFF6978D1),
  'consumer/desktop': Color(0xFF8994DE),
  'business': Color(0xFFE65100),
  'business/small': Color(0xFFF57C00),
  'business/medium': Color(0xFFFF9800),
  'business/enterprise': Color(0xFFFFB74D),
}, fallback: const Color(0xFF607D8B));

final salesHierarchyColorScale = TreemapColorScale.exact(const {
  'region:North': Color(0xFF303F9F),
  'product:North/Mobile': Color(0xFF4F5FC4),
  'product:North/Web': Color(0xFF8994DE),
  'region:South': Color(0xFFE65100),
  'product:South/Small business': Color(0xFFF57C00),
  'product:South/Enterprise': Color(0xFFFFB74D),
}, fallback: const Color(0xFF607D8B));

TreemapAppearanceResolver<String> sampleAppearance({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<String>? nodeStyleResolver,
}) => TreemapAppearanceResolver<String>(
  colorScale: colorScale ?? sampleHierarchyColorScale,
  style: style,
  nodeStyleResolver: nodeStyleResolver,
);

TreemapTiles<String> sampleTiles({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<String>? nodeStyleResolver,
}) => TreemapTiles(
  appearance: sampleAppearance(
    colorScale: colorScale,
    style: style,
    nodeStyleResolver: nodeStyleResolver,
  ),
);

TreemapCanvasLabels<String> sampleLabels({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<String>? nodeStyleResolver,
  TreemapLabelConfig<String> config = const TreemapLabelConfig(),
}) => TreemapCanvasLabels(
  appearance: sampleAppearance(
    colorScale: colorScale,
    style: style,
    nodeStyleResolver: nodeStyleResolver,
  ),
  config: config,
);

TreemapColorScale manyNodeColorScale([int count = 40]) =>
    TreemapColorScale.interpolated(
      minimum: 0,
      maximum: (count <= 1 ? 1 : count - 1).toDouble(),
      colors: const [
        Color(0xFF4527A0),
        Color(0xFF3949AB),
        Color(0xFF039BE5),
        Color(0xFF00897B),
      ],
      fallback: const Color(0xFF607D8B),
    );

TreemapNode<String> sampleTree({
  double revision = 0,
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
          weight: 55 + revision,
          color: numericColors ? 55 + revision : 'consumer/mobile',
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

TreemapNode<String> manyNodeTree([int count = 40]) => TreemapNode(
  key: 'root',
  label: 'Many nodes',
  children: [
    for (var index = 0; index < count; index++)
      TreemapNode(
        key: 'item-$index',
        label: 'Item $index',
        weight: (index % 11 + 1).toDouble(),
        color: index.toDouble(),
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
