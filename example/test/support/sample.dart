import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/datasets.dart';
import 'package:flutter/material.dart';

TreemapNode<String> sampleTree() => marketTree();
final sampleHierarchyColorScale = suggestedScale(
  marketTree(),
  const Color(0xFF607D8B),
);
TreemapTiles<String> sampleTiles() => TreemapTiles(
  appearance: TreemapAppearanceResolver(colorScale: sampleHierarchyColorScale),
);
