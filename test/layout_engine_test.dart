import 'dart:math' as math;

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNode<String> _flat(List<double> weights) => TreemapNode(
  key: 'root',
  children: [
    for (final entry in weights.indexed)
      TreemapNode(key: 'n${entry.$1}', weight: entry.$2),
  ],
);

TreemapLayoutConfig<String> _config(
  TreemapLayoutAlgorithm algorithm, {
  TreemapSortPolicy sort = TreemapSortPolicy.sourceOrder,
  TreemapLayoutDirection direction = TreemapLayoutDirection.topLeft,
  TreemapAxisOrder axis = TreemapAxisOrder.horizontalFirst,
  double spacing = 0,
}) => TreemapLayoutConfig(
  innerSpacing: spacing,
  policy: TreemapLayoutPolicy(
    rootRule: TreemapLayoutRule(
      algorithm: algorithm,
      sort: sort,
      direction: direction,
      axisOrder: axis,
    ),
  ),
);

void _expectValid(TreemapGeometrySnapshot<String> snapshot) {
  expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
  for (final node in snapshot.nodes) {
    expect(node.bounds.isFinite, isTrue, reason: '${node.key}');
    expect(node.bounds.width, greaterThanOrEqualTo(0));
    expect(node.bounds.height, greaterThanOrEqualTo(0));
  }
}

void main() {
  test('layout configuration has canonical const neutral defaults', () {
    const first = TreemapLayoutConfig<String>();
    const second = TreemapLayoutConfig<String>();

    expect(identical(first, second), isTrue);
    expect(first.outerPadding, TreemapInsets.zero);
    expect(first.levelPadding, TreemapInsets.zero);
    expect(first.innerSpacing, 0);
    expect(first.minimumWidth, 0);
    expect(first.minimumHeight, 0);
    expect(first.minimumArea, 0);
  });

  const algorithms = TreemapLayoutAlgorithm.values;
  for (final algorithm in algorithms) {
    test('$algorithm satisfies geometry invariants', () {
      final snapshot = TreemapLayoutEngine<String>().layout(
        root: _flat([9, 7, 5, 3, 2, 1]),
        viewport: const TreemapBounds.fromLTWH(.25, .5, 401.5, 239.25),
        config: _config(algorithm),
      );
      _expectValid(snapshot);
      expect(snapshot.nodes, hasLength(6));
      final area = snapshot.nodes.fold<double>(
        0,
        (sum, node) => sum + node.bounds.area,
      );
      expect(area, closeTo(snapshot.viewport.area, 1));
    });
  }

  test('slice and dice preserve exact proportional flow', () {
    final engine = TreemapLayoutEngine<String>();
    final slice = engine.layout(
      root: _flat([1, 3]),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 80),
      config: _config(TreemapLayoutAlgorithm.slice),
    );
    final dice = engine.layout(
      root: _flat([1, 3]),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 80),
      config: _config(TreemapLayoutAlgorithm.dice),
    );
    expect(slice.nodes.first.bounds.height, closeTo(20, .001));
    expect(dice.nodes.first.bounds.width, closeTo(25, .001));
  });

  test('layout preserves device-independent fractional coordinates', () {
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: _flat([1, 2]),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 80),
      config: _config(TreemapLayoutAlgorithm.dice),
    );

    expect(snapshot.nodes.first.bounds.width, closeTo(100 / 3, 1e-10));
  });

  test('all four origins mirror stable source geometry', () {
    TreemapGeometrySnapshot<String> run(TreemapLayoutDirection direction) =>
        TreemapLayoutEngine<String>().layout(
          root: _flat([1, 3]),
          viewport: const TreemapBounds.fromLTWH(10, 20, 100, 80),
          config: _config(TreemapLayoutAlgorithm.dice, direction: direction),
        );
    final topLeft = run(TreemapLayoutDirection.topLeft).nodes.first.bounds;
    final topRight = run(TreemapLayoutDirection.topRight).nodes.first.bounds;
    final bottomRight = run(
      TreemapLayoutDirection.bottomRight,
    ).nodes.first.bounds;
    expect(topLeft.left, 10);
    expect(topRight.right, 110);
    expect(bottomRight.right, 110);
    expect(bottomRight.bottom, 100);
  });

  test('binary axis order chooses the first split for square bounds', () {
    TreemapGeometrySnapshot<String> run(TreemapAxisOrder axis) =>
        TreemapLayoutEngine<String>().layout(
          root: _flat([5, 3, 2]),
          viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
          config: _config(TreemapLayoutAlgorithm.binaryByWeight, axis: axis),
        );

    final horizontal = run(TreemapAxisOrder.horizontalFirst).nodes.first.bounds;
    final vertical = run(TreemapAxisOrder.verticalFirst).nodes.first.bounds;

    expect(horizontal.height, 100);
    expect(horizontal.width, closeTo(50, .001));
    expect(vertical.width, 100);
    expect(vertical.height, closeTo(50, .001));
    expect(horizontal, isNot(vertical));
  });

  test('sort policies are deterministic and key-tied', () {
    List<String?> keys(TreemapSortPolicy sort) => TreemapLayoutEngine<String>()
        .layout(
          root: TreemapNode(
            key: 'root',
            children: [
              TreemapNode(key: 'z', weight: 2),
              TreemapNode(key: 'a', weight: 1),
              TreemapNode(key: 'b', weight: 2),
            ],
          ),
          viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
          config: _config(TreemapLayoutAlgorithm.slice, sort: sort),
        )
        .nodes
        .map((node) => node.node?.key)
        .toList();
    expect(keys(TreemapSortPolicy.sourceOrder), ['z', 'a', 'b']);
    expect(keys(TreemapSortPolicy.ascending), ['a', 'b', 'z']);
    expect(keys(TreemapSortPolicy.descending), ['b', 'z', 'a']);
  });

  test('mixed parent and depth rules obey precedence', () {
    final root = TreemapNode<String>(
      key: 'root',
      children: [
        TreemapNode(
          key: 'special',
          children: [
            TreemapNode(key: 'a', weight: 1),
            TreemapNode(key: 'b', weight: 1),
          ],
        ),
      ],
    );
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: root,
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
      config: TreemapLayoutConfig(
        policy: TreemapLayoutPolicy(
          rootRule: const TreemapLayoutRule(
            algorithm: TreemapLayoutAlgorithm.squarified,
          ),
          byChildDepth: const {
            2: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.slice),
          },
          byParentKey: const {
            'special': TreemapLayoutRule(
              algorithm: TreemapLayoutAlgorithm.dice,
            ),
          },
        ),
      ),
    );
    final a = snapshot.index[const TreemapKey.source('a')]!.bounds;
    final b = snapshot.index[const TreemapKey.source('b')]!.bounds;
    expect(a.top, b.top);
    expect(a.left, isNot(b.left));
  });

  test('minimum visibility aggregates with collision-free membership', () {
    final engine = TreemapLayoutEngine<String>();
    final root = _flat([100, 1, 1, 1]);
    TreemapGeometrySnapshot<String> run(double width) => engine.layout(
      root: root,
      viewport: TreemapBounds.fromLTWH(0, 0, width, 100),
      config: TreemapLayoutConfig(
        minimumWidth: 20,
        minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
      ),
    );
    final narrow = run(100);
    final aggregate = narrow.nodes.singleWhere((node) => node.isAggregate);
    expect(aggregate.aggregateMembers.map((node) => node.key), {
      'n1',
      'n2',
      'n3',
    });
    expect(aggregate.key, isNot(const TreemapKey.source('root')));
    final wide = run(2000);
    expect(wide.nodes.where((node) => node.isAggregate), isEmpty);
  });

  test('outer padding and symmetric spacing stay bounded', () {
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: _flat([1, 1, 1, 1]),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
      config: TreemapLayoutConfig(
        outerPadding: const TreemapInsets.fromLTRB(10, 5, 20, 15),
        innerSpacing: 4,
      ),
    );
    _expectValid(snapshot);
    expect(snapshot.nodes.every((node) => node.bounds.left >= 10), isTrue);
    expect(snapshot.nodes.every((node) => node.bounds.right <= 80), isTrue);
  });

  test('spacing preserves mathematically collinear outer edges', () {
    final root = _flat([
      28,
      24,
      20,
      18,
      16,
      14,
      12,
      10,
      .45,
      .45,
      .45,
      .45,
      .45,
      .45,
      .45,
      .45,
    ]);
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: root,
      viewport: const TreemapBounds.fromLTWH(16, 16, 408, 488),
      config: TreemapLayoutConfig(
        innerSpacing: 16,
        minimumWidth: 48,
        minimumHeight: 32,
        minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
      ),
    );
    final leaf = snapshot.index[const TreemapKey.source('n7')]!;
    final aggregate = snapshot.nodes.singleWhere((node) => node.isAggregate);

    expect(aggregate.aggregateMembers, hasLength(8));
    expect(leaf.bounds.left, closeTo(aggregate.bounds.left, 1e-9));
    expect(leaf.bounds.right, closeTo(aggregate.bounds.right, 1e-9));
    expect(aggregate.bounds.right, closeTo(snapshot.viewport.right, 1e-9));
    expect(aggregate.bounds.bottom, closeTo(snapshot.viewport.bottom, 1e-9));
  });

  test('seeded randomized geometry remains finite and non-overlapping', () {
    final random = math.Random(4815162342);
    for (var iteration = 0; iteration < 50; iteration++) {
      final weights = [
        for (var i = 0; i < 1 + random.nextInt(40); i++)
          random.nextDouble() * 1000,
      ];
      for (final algorithm in algorithms) {
        final snapshot = TreemapLayoutEngine<String>().layout(
          root: _flat(weights),
          viewport: TreemapBounds.fromLTWH(
            0,
            0,
            10 + random.nextDouble() * 1000,
            10 + random.nextDouble() * 800,
          ),
          config: _config(algorithm, spacing: random.nextDouble() * 3),
        );
        _expectValid(snapshot);
      }
    }
  });

  test('keyed transition handles reorder, enter and exit', () {
    final engine = TreemapLayoutEngine<String>();
    final a = engine.layout(
      root: _flat([1, 2]),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
    );
    final b = engine.layout(
      root: TreemapNode(
        key: 'root',
        children: [
          TreemapNode(key: 'n1', weight: 2),
          TreemapNode(key: 'new', weight: 3),
        ],
      ),
      viewport: const TreemapBounds.fromLTWH(0, 0, 100, 100),
    );
    final middle = TreemapGeometryTransition.lerp(a, b, .5);
    expect(middle.index.keys, contains(const TreemapKey.source('n0')));
    expect(middle.index.keys, contains(const TreemapKey.source('new')));
    expect(middle.index[const TreemapKey.source('n0')]!.opacity, .5);
    expect(middle.index[const TreemapKey.source('new')]!.opacity, .5);
  });
}
