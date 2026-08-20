import 'dart:collection';

/// Identifies either a caller-owned node or a collision-free generated node.
final class TreemapKey<K> {
  const TreemapKey.source(this.sourceKey)
    : aggregateParent = null,
      aggregateSignature = null;

  const TreemapKey.aggregate({
    required this.aggregateParent,
    required this.aggregateSignature,
  }) : sourceKey = null;

  final K? sourceKey;
  final TreemapKey<K>? aggregateParent;
  final int? aggregateSignature;

  bool get isSource => aggregateSignature == null;
  bool get isAggregate => !isSource;

  @override
  bool operator ==(Object other) {
    return other is TreemapKey<K> &&
        other.sourceKey == sourceKey &&
        other.aggregateParent == aggregateParent &&
        other.aggregateSignature == aggregateSignature;
  }

  @override
  int get hashCode =>
      Object.hash(sourceKey, aggregateParent, aggregateSignature);

  @override
  String toString() => isSource
      ? 'TreemapKey.source($sourceKey)'
      : 'TreemapKey.aggregate(parent: $aggregateParent, signature: $aggregateSignature)';
}

/// Immutable caller-owned hierarchy input.
final class TreemapNode<K> {
  /// Creates one immutable node in the caller-owned hierarchy.
  TreemapNode({
    required this.key,
    this.weight = 0,
    this.label,
    this.valueLabel,
    this.semanticLabel,
    this.color,
    this.data,
    Iterable<TreemapNode<K>> children = const [],
  }) : children = List.unmodifiable(children);

  /// Stable identity used for indexing, navigation, selection, and visual
  /// state.
  ///
  /// Keys must be non-null and globally unique within the hierarchy. Unlike
  /// [label], a key is application data and does not need to be human-readable.
  final K key;

  /// Non-negative finite value that determines a leaf node's relative area.
  ///
  /// For a branch, layout uses the sum of descendant leaf weights instead of
  /// this stored value. Use [valueLabel] when the displayed value should differ
  /// from the numeric weight.
  final double weight;

  /// Optional human-readable title used by built-in labels, breadcrumbs, and
  /// other visual presentation.
  ///
  /// This does not identify the node; [key] is used for identity and state.
  final String? label;

  /// Optional preformatted value shown by the built-in canvas label layer.
  ///
  /// This affects only displayed text. It does not change layout, which uses
  /// [weight], or the default accessibility value, which is derived from the
  /// resolved numeric weight.
  final String? valueLabel;

  /// Optional accessibility label announced for this node by the standard
  /// semantics layer.
  ///
  /// This can be more descriptive than [label] and has no visual or layout
  /// effect. When absent, the semantics layer falls back to [label] or [key].
  final String? semanticLabel;

  /// Optional direct Flutter `Color` or input for a color scale.
  ///
  /// The treemap core does not interpret this value. The included appearance
  /// resolver uses a Flutter `Color` directly, passes any other non-null value
  /// to its configured color scale, and uses [weight] when this is null.
  final Object? color;

  /// Optional opaque application payload retained with the node.
  ///
  /// The treemap does not interpret this value. Builders and callbacks can
  /// access it through the node in their `TreemapNodeDetails`.
  final Object? data;

  /// Immutable direct descendants that define hierarchy and navigation.
  ///
  /// An empty list makes this a leaf. For a branch, descendant leaf weights
  /// determine its effective layout weight; the constructor defensively copies
  /// this iterable into an unmodifiable list.
  final List<TreemapNode<K>> children;

  /// Whether this node has no [children].
  bool get isLeaf => children.isEmpty;

  /// Builds an immutable hierarchy by grouping flat [records] through [levels].
  static TreemapNode<K2> fromRecords<T, K2>({
    required K2 rootKey,
    required Iterable<T> records,
    required TreemapRecordMapper<T, K2> leafKey,
    required TreemapRecordMapper<T, double> weight,
    required List<TreemapRecordLevel<T, K2>> levels,
    TreemapRecordMapper<T, String?>? leafLabel,
    TreemapRecordMapper<T, String?>? leafValueLabel,
    TreemapRecordMapper<T, String?>? leafSemanticLabel,
    TreemapRecordMapper<T, Object?>? leafColor,
    TreemapRecordMapper<T, Object?>? leafData,
    String? rootLabel,
  }) {
    final source = List<T>.unmodifiable(records);

    List<TreemapNode<K2>> buildLevel(List<T> values, int levelIndex) {
      if (levelIndex >= levels.length) {
        return List.unmodifiable(
          values.map(
            (record) => TreemapNode<K2>(
              key: leafKey(record),
              weight: weight(record),
              label: leafLabel?.call(record),
              valueLabel: leafValueLabel?.call(record),
              semanticLabel: leafSemanticLabel?.call(record),
              color: leafColor?.call(record),
              data: leafData?.call(record) ?? record,
            ),
          ),
        );
      }

      final level = levels[levelIndex];
      final groups = <K2, List<T>>{};
      for (final record in values) {
        groups.putIfAbsent(level.key(record), () => <T>[]).add(record);
      }
      return List.unmodifiable(
        groups.entries.map((entry) {
          final first = entry.value.first;
          return TreemapNode<K2>(
            key: entry.key,
            label: level.label?.call(first),
            semanticLabel: level.semanticLabel?.call(first),
            color: level.color?.call(first),
            children: buildLevel(entry.value, levelIndex + 1),
          );
        }),
      );
    }

    return TreemapNode<K2>(
      key: rootKey,
      label: rootLabel,
      children: buildLevel(source, 0),
    );
  }

  TreemapNode<K> copyWith({
    K? key,
    double? weight,
    String? label,
    String? valueLabel,
    String? semanticLabel,
    Object? color,
    Object? data,
    Iterable<TreemapNode<K>>? children,
  }) {
    return TreemapNode<K>(
      key: key ?? this.key,
      weight: weight ?? this.weight,
      label: label ?? this.label,
      valueLabel: valueLabel ?? this.valueLabel,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      color: color ?? this.color,
      data: data ?? this.data,
      children: children ?? this.children,
    );
  }

  @override
  String toString() =>
      'TreemapNode(key: $key, weight: $weight, children: ${children.length})';
}

typedef TreemapRecordMapper<T, R> = R Function(T record);

/// Describes one grouping level used by [TreemapNode.fromRecords].
final class TreemapRecordLevel<T, K> {
  const TreemapRecordLevel({
    required this.key,
    this.label,
    this.semanticLabel,
    this.color,
  });

  final TreemapRecordMapper<T, K> key;
  final TreemapRecordMapper<T, String?>? label;
  final TreemapRecordMapper<T, String?>? semanticLabel;
  final TreemapRecordMapper<T, Object?>? color;
}

/// Categorizes invalid source hierarchy data.
enum TreemapValidationCode {
  /// A key is null at runtime or is an empty string.
  emptyKey,

  /// The same key occurs more than once in the hierarchy.
  duplicateKey,

  /// A node instance occurs more than once and would form a cycle or alias.
  cycle,

  /// A weight is negative or not finite.
  invalidWeight,
}

/// Describes one source-data problem and its suggested correction.
final class TreemapValidationIssue<K> {
  const TreemapValidationIssue({
    required this.code,
    required this.message,
    required this.correction,
    this.key,
  });

  final TreemapValidationCode code;
  final K? key;
  final String message;
  final String correction;

  @override
  String toString() =>
      '${code.name}${key == null ? '' : ' ($key)'}: '
      '$message Correction: $correction';
}

/// Collects all hierarchy validation issues found during normalization.
final class TreemapValidationException<K> implements Exception {
  TreemapValidationException(Iterable<TreemapValidationIssue<K>> issues)
    : issues = List.unmodifiable(issues);

  final List<TreemapValidationIssue<K>> issues;

  @override
  String toString() =>
      'TreemapValidationException:\n${issues.map((issue) => '- $issue').join('\n')}';
}

/// Validated, indexed, derived tree data used by the pure layout engine.
final class TreemapNormalizedTree<K> {
  TreemapNormalizedTree._({
    required this.root,
    required Map<K, TreemapNode<K>> nodes,
    required Map<K, K?> parents,
    required Map<K, int> depths,
    required Map<K, double> totals,
  }) : nodes = UnmodifiableMapView(nodes),
       parents = UnmodifiableMapView(parents),
       depths = UnmodifiableMapView(depths),
       totals = UnmodifiableMapView(totals);

  final TreemapNode<K> root;
  final Map<K, TreemapNode<K>> nodes;
  final Map<K, K?> parents;
  final Map<K, int> depths;
  final Map<K, double> totals;

  List<TreemapNode<K>> pathTo(K key) {
    if (!nodes.containsKey(key)) return const [];
    final reversed = <TreemapNode<K>>[];
    K? cursor = key;
    while (cursor != null) {
      final node = nodes[cursor];
      if (node == null) break;
      reversed.add(node);
      cursor = parents[cursor];
    }
    return List.unmodifiable(reversed.reversed);
  }

  @override
  String toString() =>
      'TreemapNormalizedTree(root: ${root.key}, nodes: ${nodes.length}, '
      'depth: ${depths.values.fold<int>(0, (a, b) => a > b ? a : b)})';
}

/// Validates and indexes an immutable hierarchy for efficient layout access.
abstract final class TreemapNormalizer {
  static TreemapNormalizedTree<K> normalize<K>(TreemapNode<K> root) {
    final issues = <TreemapValidationIssue<K>>[];
    final nodes = <K, TreemapNode<K>>{};
    final parents = <K, K?>{};
    final depths = <K, int>{};
    final totals = <K, double>{};
    final identities = HashSet<TreemapNode<K>>.identity();
    final stack = <({TreemapNode<K> node, K? parent, int depth, bool visited})>[
      (node: root, parent: null, depth: 0, visited: false),
    ];

    while (stack.isNotEmpty) {
      final frame = stack.removeLast();
      final node = frame.node;
      if (frame.visited) {
        totals[node.key] = node.children.isEmpty
            ? node.weight
            : node.children.fold<double>(
                0,
                (sum, child) => sum + (totals[child.key] ?? 0),
              );
        continue;
      }

      if (!identities.add(node)) {
        issues.add(
          TreemapValidationIssue<K>(
            code: TreemapValidationCode.cycle,
            key: node.key,
            message: 'The same node instance occurs more than once.',
            correction: 'Build an acyclic tree with one node instance per key.',
          ),
        );
        continue;
      }
      if (node.key == null ||
          (node.key is String && (node.key as String).trim().isEmpty)) {
        issues.add(
          TreemapValidationIssue<K>(
            code: TreemapValidationCode.emptyKey,
            key: node.key,
            message: 'A node key is null or an empty string.',
            correction: 'Supply a stable, non-empty key for every node.',
          ),
        );
      }
      if (nodes.containsKey(node.key)) {
        issues.add(
          TreemapValidationIssue<K>(
            code: TreemapValidationCode.duplicateKey,
            key: node.key,
            message: 'The key occurs more than once in the hierarchy.',
            correction: 'Use globally unique opaque keys.',
          ),
        );
        continue;
      }
      if (!node.weight.isFinite || node.weight < 0) {
        issues.add(
          TreemapValidationIssue<K>(
            code: TreemapValidationCode.invalidWeight,
            key: node.key,
            message: 'Weight ${node.weight} is negative or non-finite.',
            correction: 'Use a finite weight greater than or equal to zero.',
          ),
        );
      }

      nodes[node.key] = node;
      parents[node.key] = frame.parent;
      depths[node.key] = frame.depth;
      stack.add((
        node: node,
        parent: frame.parent,
        depth: frame.depth,
        visited: true,
      ));
      for (final child in node.children.reversed) {
        stack.add((
          node: child,
          parent: node.key,
          depth: frame.depth + 1,
          visited: false,
        ));
      }
    }

    if (issues.isNotEmpty) throw TreemapValidationException<K>(issues);
    return TreemapNormalizedTree<K>._(
      root: root,
      nodes: nodes,
      parents: parents,
      depths: depths,
      totals: totals,
    );
  }
}
