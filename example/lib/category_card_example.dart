import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

// Also runnable on its own: flutter run -t lib/category_card_example.dart.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF587EFF)),
    home: const Scaffold(
      backgroundColor: Color(0xFFE7EDFF),
      body: Padding(padding: EdgeInsets.all(16), child: CategoryCardExample()),
    ),
  ),
);

enum _Grouping { level1, level2, flat }

// There are 20 merchants. Only leaf weights contribute to branch totals.
final _categories = TreemapNode<String>(
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
            TreemapNode(key: 'rent', label: 'Rent', weight: 2),
            TreemapNode(key: 'utilities', label: 'Utilities', weight: 2),
            TreemapNode(key: 'pharmacy', label: 'Pharmacy', weight: 2),
            TreemapNode(key: 'games', label: 'Games', weight: 2),
          ],
        ),
      ],
    ),
    TreemapNode(key: 'unassigned', label: 'Unassigned', weight: 1),
  ],
);

Iterable<TreemapNode<String>> _leaves(TreemapNode<String> node) sync* {
  if (node.isLeaf) {
    yield node;
  } else {
    for (final child in node.children) {
      yield* _leaves(child);
    }
  }
}

/// A compact category card demonstrating visible depth and branch drill-down.
class CategoryCardExample extends StatefulWidget {
  const CategoryCardExample({super.key});

  @override
  State<CategoryCardExample> createState() => _CategoryCardExampleState();
}

class _CategoryCardExampleState extends State<CategoryCardExample> {
  final _controller = TreemapController<String>();
  var _grouping = _Grouping.level1;
  int? _maxVisibleDepth;

  TreemapNode<String> get _root => switch (_grouping) {
    _Grouping.level1 => _categories,
    _Grouping.level2 => TreemapNode(
      key: 'merchants',
      label: 'All merchants',
      children: [
        for (final category in _categories.children)
          if (category.isLeaf) category else ...category.children,
      ],
    ),
    _Grouping.flat => TreemapNode(
      key: 'merchants',
      label: 'All merchants',
      children: _leaves(_categories),
    ),
  };

  void _setGrouping(_Grouping value) {
    if (_grouping == value) return;
    setState(() => _grouping = value);
    _controller.synchronize(_root);
    _controller.reset();
  }

  Widget _hierarchyNode(
    BuildContext context,
    TreemapNode<String> node,
    Map<String, double> totals, {
    int depth = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsetsDirectional.only(
          start: depth * 16,
          top: 6,
          bottom: 6,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(
              alpha: (1 - depth * .12).clamp(.55, 1.0),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(node.label ?? node.key)),
              Text(
                '${totals[node.key]!.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      for (final child in node.children)
        _hierarchyNode(context, child, totals, depth: depth + 1),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      const padding = 8.0;
      const lineHeight = 14.0;
      const gutter = 2.0;
      final root = _root;
      final tree = TreemapNormalizer.normalize(root);
      final appearance = TreemapAppearanceResolver<String>(
        colorScale: TreemapColorScale.interpolated(
          minimum: 1,
          maximum: 19,
          colors: const [Color(0xFFE7EDFF), Color(0xFF587EFF)],
          fallback: const Color(0xFFE7EDFF),
        ),
        style: const TreemapStyle(
          tileAppearance: TreemapAppearance(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 440,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Visible depth',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('All (null)')),
                        ButtonSegment(value: 1, label: Text('Depth 1')),
                        ButtonSegment(value: 2, label: Text('Depth 2')),
                      ],
                      selected: {_maxVisibleDepth},
                      onSelectionChanged: (selection) {
                        setState(() => _maxVisibleDepth = selection.single);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: TreemapChart<String>(
                              root: root,
                              controller: _controller,
                              tiles: TreemapTiles(appearance: appearance),
                              labels: TreemapWidgetLabels(
                                builder: (context, details, states) {
                                  final tile = appearance.resolve(
                                    context,
                                    details,
                                    states,
                                  );
                                  final textStyle = TextStyle(
                                    fontSize: 12,
                                    height: lineHeight / 12,
                                    color: treemapContrastingTextColor(
                                      tile.color!,
                                    ),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.all(padding),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            details.label ?? 'Other',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textStyle,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            '${details.weight.toInt()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              layout: TreemapLayoutConfig<String>(
                                maxVisibleDepth: _maxVisibleDepth,
                                innerSpacing: gutter,
                                levelPadding: const TreemapInsets.all(padding),
                                // Keep small categories such as Unassigned as
                                // source tiles; labels clip to available space.
                                minimumNodePolicy:
                                    TreemapMinimumNodePolicy.show,
                              ),
                              interaction: TreemapInteractionConfig<String>(
                                // Keep terminal leaves at the current zoom focus.
                                onNodeTap: (_) {},
                              ),
                              tooltip: TreemapTooltip(
                                builder: (context, details) => Text(
                                  '${details.label ?? 'Other'}: ${details.weight.toInt()}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              semantics: TreemapSemantics<String>(),
                            ),
                          ),
                          if (_controller.canZoomOut)
                            PositionedDirectional(
                              top: 4,
                              end: 4,
                              child: IconButton.filledTonal(
                                tooltip: 'Back',
                                onPressed: _controller.zoomOut,
                                icon: const Icon(Icons.arrow_back),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DefaultTabController(
                      length: _Grouping.values.length,
                      initialIndex: _grouping.index,
                      child: TabBar(
                        onTap: (index) => _setGrouping(_Grouping.values[index]),
                        tabs: const [
                          Tab(text: 'Level 1'),
                          Tab(text: 'Level 2'),
                          Tab(text: 'Flat'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Display the supplied hierarchy, including derived parent totals.
                    _hierarchyNode(context, root, tree.totals),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
