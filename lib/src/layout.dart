import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'geometry.dart';
import 'model.dart';

/// Built-in algorithms for partitioning sibling weights into rectangles.
enum TreemapLayoutAlgorithm {
  /// Groups nodes into rows chosen to keep rectangles close to square.
  squarified,

  /// Preserves previous squarified topology when geometry is updated.
  resquarified,

  /// Divides available height into horizontal slices.
  slice,

  /// Divides available width into vertical slices.
  dice,

  /// Alternates between [slice] and [dice] at successive tree depths.
  alternatingSliceDice,

  /// Builds ordered strips while optimizing their aspect ratios.
  strip,

  /// Recursively splits siblings into groups with balanced total weight.
  binaryByWeight,

  /// Recursively splits siblings into groups with balanced item counts.
  binaryByCount,
}

/// Determines the sibling order supplied to a layout algorithm.
enum TreemapSortPolicy {
  /// Retains the order from the source hierarchy.
  sourceOrder,

  /// Orders siblings from the smallest weight to the largest.
  ascending,

  /// Orders siblings from the largest weight to the smallest.
  descending,

  /// Uses the comparator supplied by [TreemapLayoutRule.comparator].
  custom,
}

/// Selects the corner from which an algorithm starts placing nodes.
enum TreemapLayoutDirection {
  /// Starts at the top-left corner.
  topLeft,

  /// Starts at the top-right corner.
  topRight,

  /// Starts at the bottom-left corner.
  bottomLeft,

  /// Starts at the bottom-right corner.
  bottomRight,
}

/// Selects the preferred first/primary flow axis for strategies that support it.
///
/// Binary strategies continue splitting the longer side to preserve aspect
/// ratio and use this preference when width and height are equal. A square
/// viewport therefore makes the difference between both values explicit.
enum TreemapAxisOrder {
  /// Prefers horizontal flow when the strategy has an axis choice.
  horizontalFirst,

  /// Prefers vertical flow when the strategy has an axis choice.
  verticalFirst,
}

/// Determines how nodes below configured minimum dimensions are represented.
enum TreemapMinimumNodePolicy {
  /// Keeps every node regardless of its resulting dimensions.
  show,

  /// Removes nodes whose rectangles are below a configured minimum.
  hide,

  /// Combines undersized siblings into a generated aggregate node.
  aggregate,
}

/// Handles a sibling set when every node is below its configured minimum.
enum TreemapInsufficientSpacePolicy {
  /// Keeps the result selected by [TreemapMinimumNodePolicy].
  show,

  /// Removes all undersized nodes from the affected sibling set.
  hide,

  /// Throws a [TreemapLayoutException].
  error,
}

typedef TreemapNodeComparator<K> =
    int Function(TreemapNode<K> a, TreemapNode<K> b);

typedef TreemapLayoutRuleResolver<K> =
    TreemapLayoutRule<K>? Function(TreemapLayoutContext<K> context);

/// Describes optional layout choices that can inherit from another rule.
final class TreemapLayoutRule<K> {
  const TreemapLayoutRule({
    this.algorithm,
    this.sort,
    this.comparator,
    this.direction,
    this.axisOrder,
    this.strategy,
  });

  final TreemapLayoutAlgorithm? algorithm;
  final TreemapSortPolicy? sort;
  final TreemapNodeComparator<K>? comparator;
  final TreemapLayoutDirection? direction;
  final TreemapAxisOrder? axisOrder;
  final ITreemapLayoutStrategy<K>? strategy;

  TreemapResolvedLayoutRule<K> resolve([
    TreemapResolvedLayoutRule<K>? fallback,
  ]) {
    final base = fallback ?? TreemapResolvedLayoutRule<K>.defaults();
    return TreemapResolvedLayoutRule<K>(
      algorithm: algorithm ?? base.algorithm,
      sort: sort ?? base.sort,
      comparator: comparator ?? base.comparator,
      direction: direction ?? base.direction,
      axisOrder: axisOrder ?? base.axisOrder,
      strategy: strategy ?? base.strategy,
    );
  }
}

/// Contains the complete, non-null layout choices used by the engine.
final class TreemapResolvedLayoutRule<K> {
  const TreemapResolvedLayoutRule({
    required this.algorithm,
    required this.sort,
    required this.direction,
    required this.axisOrder,
    this.comparator,
    this.strategy,
  });

  factory TreemapResolvedLayoutRule.defaults() => TreemapResolvedLayoutRule<K>(
    algorithm: TreemapLayoutAlgorithm.squarified,
    sort: TreemapSortPolicy.descending,
    direction: TreemapLayoutDirection.topLeft,
    axisOrder: TreemapAxisOrder.horizontalFirst,
  );

  final TreemapLayoutAlgorithm algorithm;
  final TreemapSortPolicy sort;
  final TreemapNodeComparator<K>? comparator;
  final TreemapLayoutDirection direction;
  final TreemapAxisOrder axisOrder;
  final ITreemapLayoutStrategy<K>? strategy;
}

/// Supplies branch-specific state to a layout-rule resolver.
final class TreemapLayoutContext<K> {
  TreemapLayoutContext({
    required this.parent,
    required Iterable<TreemapNode<K>> children,
    required this.childDepth,
    required this.bounds,
    required this.focusKey,
    required this.inheritedRule,
  }) : children = List.unmodifiable(children);

  final TreemapNode<K> parent;
  final List<TreemapNode<K>> children;
  final int childDepth;
  final TreemapBounds bounds;
  final TreemapKey<K>? focusKey;
  final TreemapResolvedLayoutRule<K> inheritedRule;
}

/// Resolves layout rules by root, depth, parent key, and callback.
final class TreemapLayoutPolicy<K> {
  const TreemapLayoutPolicy({
    TreemapLayoutRule<K>? rootRule,
    this.byChildDepth = const {},
    this.byParentKey = const {},
    this.resolver,
    this.inheritResolvedRule = true,
  }) : _rootRule = rootRule;

  final TreemapLayoutRule<K>? _rootRule;
  TreemapLayoutRule<K> get rootRule => _rootRule ?? TreemapLayoutRule<K>();
  final Map<int, TreemapLayoutRule<K>> byChildDepth;
  final Map<K, TreemapLayoutRule<K>> byParentKey;
  final TreemapLayoutRuleResolver<K>? resolver;
  final bool inheritResolvedRule;

  TreemapResolvedLayoutRule<K> resolve(TreemapLayoutContext<K> context) {
    var resolved = inheritResolvedRule
        ? context.inheritedRule
        : rootRule.resolve();
    resolved = (byChildDepth[context.childDepth] ?? TreemapLayoutRule<K>())
        .resolve(resolved);
    resolved = (byParentKey[context.parent.key] ?? TreemapLayoutRule<K>())
        .resolve(resolved);
    resolved = (resolver?.call(context) ?? TreemapLayoutRule<K>()).resolve(
      resolved,
    );
    return resolved;
  }
}

/// Configures geometry, minimum-node handling, and rule resolution.
final class TreemapLayoutConfig<K> {
  const TreemapLayoutConfig({
    TreemapLayoutPolicy<K>? policy,
    this.outerPadding = TreemapInsets.zero,
    this.levelPadding = TreemapInsets.zero,
    this.innerSpacing = 0,
    this.minimumWidth = 0,
    this.minimumHeight = 0,
    this.minimumArea = 0,
    this.minimumNodePolicy = TreemapMinimumNodePolicy.show,
    this.insufficientSpacePolicy = TreemapInsufficientSpacePolicy.show,
  }) : _policy = policy;

  final TreemapLayoutPolicy<K>? _policy;
  TreemapLayoutPolicy<K> get policy => _policy ?? TreemapLayoutPolicy<K>();
  final TreemapInsets outerPadding;
  final TreemapInsets levelPadding;
  final double innerSpacing;

  /// Global minimum visible width and height for a node.
  ///
  /// These thresholds are evaluated when [minimumNodePolicy] is
  /// [TreemapMinimumNodePolicy.hide] or [TreemapMinimumNodePolicy.aggregate].
  final double minimumWidth;
  final double minimumHeight;
  final double minimumArea;
  final TreemapMinimumNodePolicy minimumNodePolicy;
  final TreemapInsufficientSpacePolicy insufficientSpacePolicy;

  TreemapLayoutConfig<K> copyWith({
    TreemapLayoutPolicy<K>? policy,
    TreemapInsets? outerPadding,
    TreemapInsets? levelPadding,
    double? innerSpacing,
    double? minimumWidth,
    double? minimumHeight,
    double? minimumArea,
    TreemapMinimumNodePolicy? minimumNodePolicy,
    TreemapInsufficientSpacePolicy? insufficientSpacePolicy,
  }) {
    return TreemapLayoutConfig<K>(
      policy: policy ?? this.policy,
      outerPadding: outerPadding ?? this.outerPadding,
      levelPadding: levelPadding ?? this.levelPadding,
      innerSpacing: innerSpacing ?? this.innerSpacing,
      minimumWidth: minimumWidth ?? this.minimumWidth,
      minimumHeight: minimumHeight ?? this.minimumHeight,
      minimumArea: minimumArea ?? this.minimumArea,
      minimumNodePolicy: minimumNodePolicy ?? this.minimumNodePolicy,
      insufficientSpacePolicy:
          insufficientSpacePolicy ?? this.insufficientSpacePolicy,
    );
  }

  void validate() {
    final values = {
      'innerSpacing': innerSpacing,
      'minimumWidth': minimumWidth,
      'minimumHeight': minimumHeight,
      'minimumArea': minimumArea,
    };
    for (final entry in values.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw TreemapLayoutException(
          '${entry.key} must be finite and greater than or equal to zero.',
        );
      }
    }
    if (!outerPadding.isFinite ||
        !outerPadding.isNonNegative ||
        !levelPadding.isFinite ||
        !levelPadding.isNonNegative) {
      throw const TreemapLayoutException(
        'Padding must contain finite, non-negative values.',
      );
    }
  }

  @override
  String toString() =>
      'TreemapLayoutConfig(spacing: $innerSpacing, padding: $outerPadding, '
      'minimum: ${minimumWidth}x$minimumHeight/$minimumArea, '
      'policy: ${minimumNodePolicy.name})';
}

/// Reports invalid layout configuration or geometry that cannot be resolved.
final class TreemapLayoutException implements Exception {
  const TreemapLayoutException(this.message);
  final String message;
  @override
  String toString() => 'TreemapLayoutException: $message';
}

/// Identifies the source or generated aggregate branch to lay out as the root.
final class TreemapFocus<K> {
  TreemapFocus.source(K key)
    : key = TreemapKey<K>.source(key),
      aggregateMembers = const [],
      path = const [];

  TreemapFocus.aggregate({
    required this.key,
    required Iterable<TreemapNode<K>> members,
    required Iterable<TreemapPathEntry<K>> path,
  }) : aggregateMembers = List.unmodifiable(members),
       path = List.unmodifiable(path);

  final TreemapKey<K> key;
  final List<TreemapNode<K>> aggregateMembers;
  final List<TreemapPathEntry<K>> path;
}

/// Adapts a source or generated node for an immediate-children strategy.
final class TreemapLayoutItem<K> {
  const TreemapLayoutItem({
    required this.key,
    required this.weight,
    required this.sourceIndex,
    this.node,
  });

  final TreemapKey<K> key;
  final TreemapNode<K>? node;
  final double weight;
  final int sourceIndex;
}

/// Provides immutable sibling data and bounds to a custom layout strategy.
final class TreemapStrategyInput<K> {
  TreemapStrategyInput({
    required Iterable<TreemapLayoutItem<K>> items,
    required this.bounds,
    required this.childDepth,
    required this.axisOrder,
  }) : items = List.unmodifiable(items);

  final List<TreemapLayoutItem<K>> items;
  final TreemapBounds bounds;
  final int childDepth;
  final TreemapAxisOrder axisOrder;
}

/// Contract for laying out one level of sibling items within fixed bounds.
abstract interface class ITreemapLayoutStrategy<K> {
  Map<TreemapKey<K>, TreemapBounds> layout(TreemapStrategyInput<K> input);
}

/// Converts validated hierarchical data into an immutable geometry snapshot.
final class TreemapLayoutEngine<K> {
  int _revision = 0;

  TreemapGeometrySnapshot<K> layout({
    required TreemapNode<K> root,
    required TreemapBounds viewport,
    TreemapLayoutConfig<K>? config,
    TreemapFocus<K>? focus,
    TreemapGeometrySnapshot<K>? previous,
  }) {
    final effectiveConfig = config ?? TreemapLayoutConfig<K>();
    effectiveConfig.validate();
    if (!viewport.isFinite || viewport.width < 0 || viewport.height < 0) {
      throw const TreemapLayoutException(
        'Viewport coordinates and dimensions must be finite and non-negative.',
      );
    }
    final tree = TreemapNormalizer.normalize(root);
    final contentBounds = viewport.inset(effectiveConfig.outerPadding);
    if (contentBounds.isEmpty || tree.totals[root.key] == 0) {
      return TreemapGeometrySnapshot<K>(
        viewport: viewport,
        nodes: const [],
        path: [
          TreemapPathEntry(
            key: TreemapKey.source(root.key),
            label: root.label,
            depth: 0,
          ),
        ],
        focusKey: TreemapKey.source(root.key),
        revision: ++_revision,
      );
    }

    final resolvedFocus = _resolveFocus(tree, focus);
    final nodes = <TreemapGeometryNode<K>>[];
    final defaultRule = effectiveConfig.policy.rootRule.resolve();
    final stack = <_LayoutWork<K>>[
      _LayoutWork(
        parent: resolvedFocus.parent,
        children: resolvedFocus.children,
        bounds: contentBounds,
        parentGeometryKey: null,
        childDepth: resolvedFocus.childDepth,
        inheritedRule: defaultRule,
      ),
    ];

    while (stack.isNotEmpty) {
      final work = stack.removeLast();
      if (work.children.isEmpty || work.bounds.isEmpty) continue;
      final context = TreemapLayoutContext<K>(
        parent: work.parent,
        children: work.children,
        childDepth: work.childDepth,
        bounds: work.bounds,
        focusKey: resolvedFocus.key,
        inheritedRule: work.inheritedRule,
      );
      final rule = effectiveConfig.policy.resolve(context);
      final partition = _partition(
        parent: work.parent,
        children: work.children,
        bounds: work.bounds,
        depth: work.childDepth,
        rule: rule,
        config: effectiveConfig,
        totals: tree.totals,
        previous: previous,
        parentGeometryKey: work.parentGeometryKey,
      );

      for (final item in partition.items) {
        final bounds = partition.bounds[item.key] ?? TreemapBounds.zero();
        final aggregate = partition.aggregates[item.key];
        final geometry = TreemapGeometryNode<K>(
          key: item.key,
          node: item.node,
          bounds: bounds,
          weight: item.weight,
          depth: work.childDepth,
          kind: aggregate == null
              ? TreemapGeometryKind.source
              : TreemapGeometryKind.aggregate,
          label: aggregate == null ? item.node?.label : null,
          parentKey: work.parentGeometryKey,
          opacity: bounds.isEmpty ? 0 : 1,
          aggregateMembers: aggregate ?? const [],
        );
        nodes.add(geometry);
      }

      for (final item in partition.items.reversed) {
        final node = item.node;
        final bounds = partition.bounds[item.key];
        if (node == null || node.children.isEmpty || bounds == null) continue;
        stack.add(
          _LayoutWork(
            parent: node,
            children: node.children,
            bounds: bounds.inset(effectiveConfig.levelPadding),
            parentGeometryKey: item.key,
            childDepth: work.childDepth + 1,
            inheritedRule: rule,
          ),
        );
      }
    }

    final snapshot = TreemapGeometrySnapshot<K>(
      viewport: viewport,
      nodes: nodes,
      path: resolvedFocus.path,
      focusKey: resolvedFocus.key,
      revision: ++_revision,
    );
    final issues = TreemapGeometryDiagnostics.validate(snapshot);
    if (issues.isNotEmpty) {
      throw TreemapLayoutException(
        'Generated invalid geometry: ${issues.first.message}',
      );
    }
    return snapshot;
  }

  Future<TreemapGeometrySnapshot<K>> layoutAsync({
    required TreemapNode<K> root,
    required TreemapBounds viewport,
    TreemapLayoutConfig<K>? config,
    TreemapFocus<K>? focus,
    TreemapGeometrySnapshot<K>? previous,
    bool fallbackToSynchronous = true,
  }) async {
    try {
      return await Isolate.run(
        () => TreemapLayoutEngine<K>().layout(
          root: root,
          viewport: viewport,
          config: config,
          focus: focus,
          previous: previous,
        ),
      );
    } on Object {
      if (!fallbackToSynchronous) rethrow;
      return layout(
        root: root,
        viewport: viewport,
        config: config,
        focus: focus,
        previous: previous,
      );
    }
  }

  _ResolvedFocus<K> _resolveFocus(
    TreemapNormalizedTree<K> tree,
    TreemapFocus<K>? focus,
  ) {
    if (focus?.key.isAggregate == true && focus!.aggregateMembers.isNotEmpty) {
      final path = focus.path.isEmpty
          ? [
              TreemapPathEntry<K>(
                key: TreemapKey.source(tree.root.key),
                label: tree.root.label,
                depth: 0,
              ),
              TreemapPathEntry<K>(key: focus.key, depth: 1),
            ]
          : focus.path;
      return _ResolvedFocus(
        key: focus.key,
        parent: TreemapNode<K>(
          key: tree.root.key,
          children: focus.aggregateMembers,
        ),
        children: focus.aggregateMembers,
        childDepth: path.last.depth + 1,
        path: path,
      );
    }

    final requested = focus?.key.sourceKey;
    final node = requested == null
        ? tree.root
        : tree.nodes[requested] ?? tree.root;
    final sourcePath = tree.pathTo(node.key);
    final path = List<TreemapPathEntry<K>>.unmodifiable(
      sourcePath.indexed.map(
        (entry) => TreemapPathEntry(
          key: TreemapKey.source(entry.$2.key),
          label: entry.$2.label,
          depth: entry.$1,
        ),
      ),
    );
    return _ResolvedFocus(
      key: TreemapKey.source(node.key),
      parent: node,
      children: node.children,
      childDepth: tree.depths[node.key]! + 1,
      path: path,
    );
  }

  _PartitionResult<K> _partition({
    required TreemapNode<K> parent,
    required List<TreemapNode<K>> children,
    required TreemapBounds bounds,
    required int depth,
    required TreemapResolvedLayoutRule<K> rule,
    required TreemapLayoutConfig<K> config,
    required Map<K, double> totals,
    required TreemapGeometrySnapshot<K>? previous,
    required TreemapKey<K>? parentGeometryKey,
  }) {
    var items = <TreemapLayoutItem<K>>[
      for (final entry in children.indexed)
        TreemapLayoutItem(
          key: TreemapKey.source(entry.$2.key),
          node: entry.$2,
          weight: totals[entry.$2.key] ?? entry.$2.weight,
          sourceIndex: entry.$1,
        ),
    ];
    items = _sort(items, rule, previous);
    var raw = _layoutItems(items, bounds, depth, rule);
    final aggregates = <TreemapKey<K>, List<TreemapNode<K>>>{};

    if (config.minimumNodePolicy != TreemapMinimumNodePolicy.show &&
        items.length > 1 &&
        (config.minimumWidth > 0 ||
            config.minimumHeight > 0 ||
            config.minimumArea > 0)) {
      final small = items.where((item) {
        final itemBounds = raw[item.key] ?? TreemapBounds.zero();
        return itemBounds.width < config.minimumWidth ||
            itemBounds.height < config.minimumHeight ||
            itemBounds.area < config.minimumArea;
      }).toList();

      if (small.isNotEmpty) {
        if (small.length == items.length &&
            config.insufficientSpacePolicy ==
                TreemapInsufficientSpacePolicy.error) {
          throw const TreemapLayoutException(
            'The viewport cannot satisfy the configured minimum node size.',
          );
        }
        if (config.minimumNodePolicy == TreemapMinimumNodePolicy.hide ||
            (small.length == items.length &&
                config.insufficientSpacePolicy ==
                    TreemapInsufficientSpacePolicy.hide)) {
          final smallKeys = small.map((item) => item.key).toSet();
          items = items.where((item) => !smallKeys.contains(item.key)).toList();
        } else {
          final smallKeys = small.map((item) => item.key).toSet();
          final members = small
              .map((item) => item.node!)
              .toList(growable: false);
          final signature = Object.hashAll(
            members.map((node) => Object.hash(node.key, totals[node.key])),
          );
          final aggregateKey = TreemapKey<K>.aggregate(
            aggregateParent: parentGeometryKey ?? TreemapKey.source(parent.key),
            aggregateSignature: signature,
          );
          final aggregate = TreemapLayoutItem<K>(
            key: aggregateKey,
            weight: small.fold(0, (sum, item) => sum + item.weight),
            sourceIndex: small.first.sourceIndex,
          );
          items = [
            ...items.where((item) => !smallKeys.contains(item.key)),
            aggregate,
          ];
          aggregates[aggregateKey] = members;
        }
        raw = _layoutItems(items, bounds, depth, rule);
      }
    }

    final adjusted = <TreemapKey<K>, TreemapBounds>{};
    for (final item in items) {
      var itemBounds = raw[item.key] ?? TreemapBounds.zero();
      itemBounds = _applySpacing(itemBounds, bounds, config.innerSpacing);
      itemBounds = itemBounds.clampTo(bounds);
      adjusted[item.key] = itemBounds;
    }
    return _PartitionResult(items, adjusted, aggregates);
  }

  List<TreemapLayoutItem<K>> _sort(
    List<TreemapLayoutItem<K>> source,
    TreemapResolvedLayoutRule<K> rule,
    TreemapGeometrySnapshot<K>? previous,
  ) {
    final result = List<TreemapLayoutItem<K>>.of(source);
    if (rule.algorithm == TreemapLayoutAlgorithm.resquarified &&
        previous != null) {
      result.sort((a, b) {
        final ar = previous.index[a.key]?.bounds;
        final br = previous.index[b.key]?.bounds;
        if (ar == null && br == null) {
          return a.sourceIndex.compareTo(b.sourceIndex);
        }
        if (ar == null) return 1;
        if (br == null) return -1;
        final row = ar.top.compareTo(br.top);
        return row != 0 ? row : ar.left.compareTo(br.left);
      });
      return result;
    }
    int compare(TreemapLayoutItem<K> a, TreemapLayoutItem<K> b) {
      var value = switch (rule.sort) {
        TreemapSortPolicy.sourceOrder => a.sourceIndex.compareTo(b.sourceIndex),
        TreemapSortPolicy.ascending => a.weight.compareTo(b.weight),
        TreemapSortPolicy.descending => b.weight.compareTo(a.weight),
        TreemapSortPolicy.custom => rule.comparator!(a.node!, b.node!),
      };
      if (value == 0) value = a.key.toString().compareTo(b.key.toString());
      return value;
    }

    if (rule.sort == TreemapSortPolicy.custom && rule.comparator == null) {
      throw const TreemapLayoutException(
        'TreemapSortPolicy.custom requires a comparator.',
      );
    }
    result.sort(compare);
    return result;
  }

  Map<TreemapKey<K>, TreemapBounds> _layoutItems(
    List<TreemapLayoutItem<K>> items,
    TreemapBounds bounds,
    int depth,
    TreemapResolvedLayoutRule<K> rule,
  ) {
    if (items.isEmpty) return const {};
    final custom = rule.strategy;
    var output = custom?.layout(
      TreemapStrategyInput(
        items: items,
        bounds: bounds,
        childDepth: depth,
        axisOrder: rule.axisOrder,
      ),
    );
    output ??= switch (rule.algorithm) {
      TreemapLayoutAlgorithm.slice => _stack(items, bounds, vertical: true),
      TreemapLayoutAlgorithm.dice => _stack(items, bounds, vertical: false),
      TreemapLayoutAlgorithm.alternatingSliceDice => _stack(
        items,
        bounds,
        vertical:
            (depth.isEven) ==
            (rule.axisOrder == TreemapAxisOrder.horizontalFirst),
      ),
      TreemapLayoutAlgorithm.strip => _squarify(
        items,
        bounds,
        fixedHorizontal: rule.axisOrder == TreemapAxisOrder.horizontalFirst,
      ),
      TreemapLayoutAlgorithm.binaryByWeight => _binary(
        items,
        bounds,
        byCount: false,
        axisOrder: rule.axisOrder,
      ),
      TreemapLayoutAlgorithm.binaryByCount => _binary(
        items,
        bounds,
        byCount: true,
        axisOrder: rule.axisOrder,
      ),
      TreemapLayoutAlgorithm.squarified ||
      TreemapLayoutAlgorithm.resquarified => _squarify(items, bounds),
    };
    return {
      for (final entry in output.entries)
        entry.key: _mirror(entry.value, bounds, rule.direction),
    };
  }

  Map<TreemapKey<K>, TreemapBounds> _stack(
    List<TreemapLayoutItem<K>> items,
    TreemapBounds bounds, {
    required bool vertical,
  }) {
    final total = items.fold<double>(0, (sum, item) => sum + item.weight);
    final result = <TreemapKey<K>, TreemapBounds>{};
    var cursor = vertical ? bounds.top : bounds.left;
    for (final entry in items.indexed) {
      final item = entry.$2;
      final isLast = entry.$1 == items.length - 1;
      final extent = total <= 0
          ? 0
          : (vertical ? bounds.height : bounds.width) * item.weight / total;
      if (vertical) {
        final bottom = isLast ? bounds.bottom : cursor + extent;
        result[item.key] = TreemapBounds.fromLTWH(
          bounds.left,
          cursor,
          bounds.width,
          math.max(0, bottom - cursor),
        );
        cursor = bottom;
      } else {
        final right = isLast ? bounds.right : cursor + extent;
        result[item.key] = TreemapBounds.fromLTWH(
          cursor,
          bounds.top,
          math.max(0, right - cursor),
          bounds.height,
        );
        cursor = right;
      }
    }
    return result;
  }

  Map<TreemapKey<K>, TreemapBounds> _squarify(
    List<TreemapLayoutItem<K>> items,
    TreemapBounds bounds, {
    bool? fixedHorizontal,
  }) {
    final result = <TreemapKey<K>, TreemapBounds>{};
    final positive = items.where((item) => item.weight > 0).toList();
    for (final item in items.where((item) => item.weight <= 0)) {
      result[item.key] = TreemapBounds.fromLTWH(
        bounds.right,
        bounds.bottom,
        0,
        0,
      );
    }
    if (positive.isEmpty || bounds.isEmpty) return result;
    final total = positive.fold<double>(0, (sum, item) => sum + item.weight);
    final scale = bounds.area / total;
    var remaining = bounds;
    var index = 0;
    while (index < positive.length && !remaining.isEmpty) {
      final horizontal = fixedHorizontal ?? remaining.width >= remaining.height;
      final side = horizontal ? remaining.height : remaining.width;
      final row = <TreemapLayoutItem<K>>[positive[index++]];
      var currentWorst = _worst(row, side, scale);
      while (index < positive.length) {
        final candidate = [...row, positive[index]];
        final nextWorst = _worst(candidate, side, scale);
        if (nextWorst > currentWorst) break;
        row.add(positive[index++]);
        currentWorst = nextWorst;
      }
      final rowWeight = row.fold<double>(0, (sum, item) => sum + item.weight);
      final rowArea = rowWeight * scale;
      if (horizontal) {
        final columnWidth = remaining.height == 0
            ? 0.0
            : rowArea / remaining.height;
        var y = remaining.top;
        for (final entry in row.indexed) {
          final item = entry.$2;
          final height = entry.$1 == row.length - 1
              ? remaining.bottom - y
              : (item.weight * scale) / math.max(columnWidth, 1e-300);
          result[item.key] = TreemapBounds.fromLTWH(
            remaining.left,
            y,
            columnWidth,
            math.max(0.0, height),
          );
          y += height;
        }
        remaining = TreemapBounds.fromLTWH(
          remaining.left + columnWidth,
          remaining.top,
          math.max(0.0, remaining.width - columnWidth),
          remaining.height,
        );
      } else {
        final rowHeight = remaining.width == 0
            ? 0.0
            : rowArea / remaining.width;
        var x = remaining.left;
        for (final entry in row.indexed) {
          final item = entry.$2;
          final width = entry.$1 == row.length - 1
              ? remaining.right - x
              : (item.weight * scale) / math.max(rowHeight, 1e-300);
          result[item.key] = TreemapBounds.fromLTWH(
            x,
            remaining.top,
            math.max(0.0, width),
            rowHeight,
          );
          x += width;
        }
        remaining = TreemapBounds.fromLTWH(
          remaining.left,
          remaining.top + rowHeight,
          remaining.width,
          math.max(0, remaining.height - rowHeight),
        );
      }
    }
    return result;
  }

  double _worst(List<TreemapLayoutItem<K>> row, double side, double scale) {
    final weights = row.map((item) => item.weight).where((value) => value > 0);
    final sum = weights.fold<double>(0, (a, b) => a + b);
    final minWeight = weights.fold<double>(double.infinity, math.min);
    final maxWeight = weights.fold<double>(0, math.max);
    if (sum == 0 || side == 0 || minWeight == double.infinity) {
      return double.infinity;
    }
    final area = sum * scale;
    final sideSquared = side * side;
    return math.max(
      sideSquared * maxWeight * scale / (area * area),
      (area * area) / (sideSquared * minWeight * scale),
    );
  }

  Map<TreemapKey<K>, TreemapBounds> _binary(
    List<TreemapLayoutItem<K>> items,
    TreemapBounds bounds, {
    required bool byCount,
    required TreemapAxisOrder axisOrder,
  }) {
    final result = <TreemapKey<K>, TreemapBounds>{};
    final work = <({List<TreemapLayoutItem<K>> items, TreemapBounds bounds})>[
      (items: items, bounds: bounds),
    ];
    while (work.isNotEmpty) {
      final current = work.removeLast();
      if (current.items.length == 1) {
        result[current.items.single.key] = current.bounds;
        continue;
      }
      final total = current.items.fold<double>(
        0,
        (sum, item) => sum + item.weight,
      );
      int split;
      if (byCount) {
        split = (current.items.length / 2).ceil();
      } else {
        var bestDifference = double.infinity;
        var prefix = 0.0;
        split = 1;
        for (var i = 1; i < current.items.length; i++) {
          prefix += current.items[i - 1].weight;
          final difference = (total / 2 - prefix).abs();
          if (difference < bestDifference) {
            bestDifference = difference;
            split = i;
          }
        }
      }
      final first = current.items.sublist(0, split);
      final second = current.items.sublist(split);
      final firstWeight = first.fold<double>(
        0,
        (sum, item) => sum + item.weight,
      );
      final ratio = total <= 0
          ? split / current.items.length
          : firstWeight / total;
      final horizontal = current.bounds.width == current.bounds.height
          ? axisOrder == TreemapAxisOrder.horizontalFirst
          : current.bounds.width > current.bounds.height;
      late TreemapBounds firstBounds;
      late TreemapBounds secondBounds;
      if (horizontal) {
        final width = current.bounds.width * ratio;
        firstBounds = TreemapBounds.fromLTWH(
          current.bounds.left,
          current.bounds.top,
          width,
          current.bounds.height,
        );
        secondBounds = TreemapBounds.fromLTWH(
          current.bounds.left + width,
          current.bounds.top,
          current.bounds.width - width,
          current.bounds.height,
        );
      } else {
        final height = current.bounds.height * ratio;
        firstBounds = TreemapBounds.fromLTWH(
          current.bounds.left,
          current.bounds.top,
          current.bounds.width,
          height,
        );
        secondBounds = TreemapBounds.fromLTWH(
          current.bounds.left,
          current.bounds.top + height,
          current.bounds.width,
          current.bounds.height - height,
        );
      }
      work
        ..add((items: second, bounds: secondBounds))
        ..add((items: first, bounds: firstBounds));
    }
    return result;
  }

  TreemapBounds _mirror(
    TreemapBounds value,
    TreemapBounds parent,
    TreemapLayoutDirection direction,
  ) {
    final mirrorX =
        direction == TreemapLayoutDirection.topRight ||
        direction == TreemapLayoutDirection.bottomRight;
    final mirrorY =
        direction == TreemapLayoutDirection.bottomLeft ||
        direction == TreemapLayoutDirection.bottomRight;
    return TreemapBounds.fromLTWH(
      mirrorX ? parent.right - (value.right - parent.left) : value.left,
      mirrorY ? parent.bottom - (value.bottom - parent.top) : value.top,
      value.width,
      value.height,
    );
  }

  TreemapBounds _applySpacing(
    TreemapBounds value,
    TreemapBounds parent,
    double spacing,
  ) {
    if (spacing <= 0 || value.isEmpty) return value;
    final half = spacing / 2;
    // Squarified arithmetic can leave an edge infinitesimally inside its
    // parent. Treating that edge as internal would create a visible half-gap.
    final edgeTolerance =
        math.max(1.0, math.max(parent.width, parent.height)) * 1e-9;
    final left = value.left <= parent.left + edgeTolerance
        ? parent.left
        : value.left + half;
    final top = value.top <= parent.top + edgeTolerance
        ? parent.top
        : value.top + half;
    final right = value.right >= parent.right - edgeTolerance
        ? parent.right
        : value.right - half;
    final bottom = value.bottom >= parent.bottom - edgeTolerance
        ? parent.bottom
        : value.bottom - half;
    return TreemapBounds.fromLTWH(
      left,
      top,
      math.max(0, right - left),
      math.max(0, bottom - top),
    );
  }
}

/// Captures one pending branch in the engine's iterative traversal.
final class _LayoutWork<K> {
  const _LayoutWork({
    required this.parent,
    required this.children,
    required this.bounds,
    required this.parentGeometryKey,
    required this.childDepth,
    required this.inheritedRule,
  });

  final TreemapNode<K> parent;
  final List<TreemapNode<K>> children;
  final TreemapBounds bounds;
  final TreemapKey<K>? parentGeometryKey;
  final int childDepth;
  final TreemapResolvedLayoutRule<K> inheritedRule;
}

/// Groups the items, rectangles, and aggregate membership from one partition.
final class _PartitionResult<K> {
  const _PartitionResult(this.items, this.bounds, this.aggregates);
  final List<TreemapLayoutItem<K>> items;
  final Map<TreemapKey<K>, TreemapBounds> bounds;
  final Map<TreemapKey<K>, List<TreemapNode<K>>> aggregates;
}

/// Holds the normalized branch and path selected as the current layout focus.
final class _ResolvedFocus<K> {
  const _ResolvedFocus({
    required this.key,
    required this.parent,
    required this.children,
    required this.childDepth,
    required this.path,
  });
  final TreemapKey<K> key;
  final TreemapNode<K> parent;
  final List<TreemapNode<K>> children;
  final int childDepth;
  final List<TreemapPathEntry<K>> path;
}
