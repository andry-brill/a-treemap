import 'package:any_treemap/any_treemap.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = TreemapBounds.fromLTWH(0, 0, 100, 100);
const _tolerance = 1e-9;

class _CountingColumns implements ITreemapLayoutStrategy<String> {
  final itemCounts = <int>[];

  @override
  Map<TreemapKey<String>, TreemapBounds> layout(
    TreemapStrategyInput<String> input,
  ) {
    // Fail promptly if a regression repeatedly regroups an unchanged Other.
    expect(itemCounts.length, lessThan(5));
    itemCounts.add(input.items.length);
    final total = input.items.fold<double>(0, (sum, item) => sum + item.weight);
    var left = input.bounds.left;
    final result = <TreemapKey<String>, TreemapBounds>{};
    for (final item in input.items) {
      final width = input.bounds.width * item.weight / total;
      result[item.key] = TreemapBounds.fromLTWH(
        left,
        input.bounds.top,
        width,
        input.bounds.height,
      );
      left += width;
    }
    return result;
  }
}

TreemapNormalizedTree<String> _tree(List<double> weights) =>
    TreemapNormalizer.normalize(
      TreemapNode(
        key: 'root',
        children: [
          for (final entry in weights.indexed)
            TreemapNode(key: 'n${entry.$1}', weight: entry.$2),
        ],
      ),
    );

TreemapLayoutConfig<String> _config({
  TreemapLayoutAlgorithm algorithm = TreemapLayoutAlgorithm.dice,
  double width = 0,
  double height = 0,
  double area = 0,
  TreemapInsufficientSpacePolicy insufficient =
      TreemapInsufficientSpacePolicy.show,
}) => TreemapLayoutConfig(
  outerPadding: TreemapInsets.zero,
  levelPadding: TreemapInsets.zero,
  innerSpacing: 0,
  minimumWidth: width,
  minimumHeight: height,
  minimumArea: area,
  minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
  insufficientSpacePolicy: insufficient,
  policy: TreemapLayoutPolicy(
    rootRule: TreemapLayoutRule(
      algorithm: algorithm,
      sort: TreemapSortPolicy.sourceOrder,
    ),
  ),
);

void _expectMinimums(
  TreemapGeometrySnapshot<String> snapshot,
  TreemapLayoutConfig<String> config,
) {
  expect(snapshot.visibleNodes, isNotEmpty);
  for (final node in snapshot.visibleNodes) {
    expect(
      node.bounds.width,
      greaterThanOrEqualTo(config.minimumWidth - _tolerance),
      reason: '${node.key} width',
    );
    expect(
      node.bounds.height,
      greaterThanOrEqualTo(config.minimumHeight - _tolerance),
      reason: '${node.key} height',
    );
    expect(
      node.bounds.area,
      greaterThanOrEqualTo(config.minimumArea - _tolerance),
      reason: '${node.key} area',
    );
  }
}

void _expectProportional(
  TreemapGeometrySnapshot<String> snapshot, {
  double total = 100,
}) {
  expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
  expect(snapshot.nodes.fold<double>(0, (sum, n) => sum + n.weight), total);
  expect(
    snapshot.nodes.fold<double>(0, (sum, n) => sum + n.bounds.area),
    closeTo(_viewport.area, _tolerance),
  );
  for (final node in snapshot.nodes) {
    expect(
      node.bounds.area,
      closeTo(node.weight / total * _viewport.area, _tolerance),
    );
    expect(node.bounds.left, greaterThanOrEqualTo(0));
    expect(node.bounds.top, greaterThanOrEqualTo(0));
    expect(node.bounds.right, lessThanOrEqualTo(100));
    expect(node.bounds.bottom, lessThanOrEqualTo(100));
  }
}

void main() {
  for (final algorithm in [
    TreemapLayoutAlgorithm.dice,
    TreemapLayoutAlgorithm.slice,
  ]) {
    test('$algorithm enforces minimum size on Other after regrouping', () {
      final config = _config(
        algorithm: algorithm,
        width: algorithm == TreemapLayoutAlgorithm.dice ? 20 : 0,
        height: algorithm == TreemapLayoutAlgorithm.slice ? 20 : 0,
      );
      final snapshot = TreemapLayoutEngine<String>().layout(
        tree: _tree([70, 25, 3, 2]),
        viewport: _viewport,
        config: config,
      );

      _expectMinimums(snapshot, config);
      expect(snapshot.nodes, hasLength(2));
      expect(snapshot.nodes.singleWhere((n) => !n.isAggregate).weight, 70);
      final other = snapshot.nodes.singleWhere((n) => n.isAggregate);
      expect(other.weight, 30);
      expect(other.aggregateMembers.map((n) => n.key), ['n1', 'n2', 'n3']);
      expect(other.aggregateMembers.map((n) => n.weight), [25, 3, 2]);
      _expectProportional(snapshot);
    });
  }

  for (final config in [
    _config(width: 20, height: 80),
    _config(algorithm: TreemapLayoutAlgorithm.slice, width: 80, height: 20),
    _config(area: 2000),
  ]) {
    test('enforces combined dimensions or area: $config', () {
      final snapshot = TreemapLayoutEngine<String>().layout(
        tree: _tree([70, 25, 3, 2]),
        viewport: _viewport,
        config: config,
      );
      _expectMinimums(snapshot, config);
      _expectProportional(snapshot);
      expect(
        snapshot.nodes
            .singleWhere((n) => n.isAggregate)
            .aggregateMembers
            .map((n) => n.weight),
        [25, 3, 2],
      );
    });
  }

  test('an undersized single-member Other absorbs the next sibling', () {
    final config = _config(width: 20);
    final snapshot = TreemapLayoutEngine<String>().layout(
      tree: _tree([70, 25, 5]),
      viewport: _viewport,
      config: config,
    );
    _expectMinimums(snapshot, config);
    _expectProportional(snapshot);
    expect(
      snapshot.nodes
          .singleWhere((n) => n.isAggregate)
          .aggregateMembers
          .map((n) => n.weight),
      [25, 5],
    );
  });

  test('custom layouts make bounded progress even for impossible minimums', () {
    for (final width in [20.0, 101.0]) {
      final strategy = _CountingColumns();
      final config = _config(width: width).copyWith(
        policy: TreemapLayoutPolicy(
          rootRule: TreemapLayoutRule(strategy: strategy),
        ),
      );
      final snapshot = TreemapLayoutEngine<String>().layout(
        tree: _tree([70, 25, 5]),
        viewport: _viewport,
        config: config,
      );
      expect(strategy.itemCounts, width == 20 ? [3, 3, 2] : [3, 1]);
      _expectProportional(snapshot);
      if (width == 20) _expectMinimums(snapshot, config);
    }
  });

  test('rechecks fitting siblings even when the new Other fits', () {
    final tree = _tree([26, 39, 5, 8, 11, 39]);
    final config = _config(
      algorithm: TreemapLayoutAlgorithm.squarified,
      width: 20,
      height: 20,
    );
    final engine = TreemapLayoutEngine<String>();
    final initial = engine.layout(
      tree: tree,
      viewport: _viewport,
      config: config.copyWith(minimumNodePolicy: TreemapMinimumNodePolicy.show),
    );
    final fitting = initial.index[const TreemapKey.source('n3')]!;
    expect(fitting.bounds.width, greaterThan(20));
    expect(fitting.bounds.height, greaterThan(20));
    // Grouping n2 + n4 gives Other 25.4 px height, but shrinks n3 to 12.7.
    final snapshot = engine.layout(
      tree: tree,
      viewport: _viewport,
      config: config,
    );
    _expectMinimums(snapshot, config);
    _expectProportional(snapshot, total: 128);
    expect(
      snapshot.nodes
          .singleWhere((n) => n.isAggregate)
          .aggregateMembers
          .map((n) => n.key),
      ['n2', 'n3', 'n4'],
    );
  });

  test(
    'equal-weight absorption is deterministic and retains source objects',
    () {
      final tree = _tree([60, 15, 15, 6, 4]);
      final engine = TreemapLayoutEngine<String>();
      final config = _config(width: 12);
      TreemapGeometrySnapshot<String> run() =>
          engine.layout(tree: tree, viewport: _viewport, config: config);
      final first = run();
      final other = first.nodes.singleWhere((n) => n.isAggregate);
      expect(other.aggregateMembers, [
        tree.nodes['n1'],
        tree.nodes['n3'],
        tree.nodes['n4'],
      ]);
      expect(other.key.aggregateParent, const TreemapKey.source('root'));
      expect(run().nodes.singleWhere((n) => n.isAggregate).key, other.key);
      _expectMinimums(first, config);
      _expectProportional(first);
    },
  );

  test('minimums apply to final rectangles after spacing', () {
    final config = _config(width: 20).copyWith(innerSpacing: 4);
    final snapshot = TreemapLayoutEngine<String>().layout(
      tree: _tree([60, 20, 20]),
      viewport: _viewport,
      config: config,
    );
    _expectMinimums(snapshot, config);
    expect(snapshot.nodes.map((n) => n.weight), [60, 40]);
    expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
  });

  for (final policy in TreemapInsufficientSpacePolicy.values) {
    test('all initially small tiles can still fit by grouping: $policy', () {
      final config = _config(width: 60, insufficient: policy);
      final snapshot = TreemapLayoutEngine<String>().layout(
        tree: _tree([50, 50]),
        viewport: _viewport,
        config: config,
      );
      _expectMinimums(snapshot, config);
      _expectProportional(snapshot);
      expect(snapshot.nodes.single.aggregateMembers, hasLength(2));
    });

    for (final minimum in ['width', 'height', 'area']) {
      for (final weights in <List<double>>[
        [70, 25, 3, 2],
        [100],
      ]) {
        test('impossible $minimum terminates with $policy for $weights', () {
          final config = _config(
            width: minimum == 'width' ? 101 : 0,
            height: minimum == 'height' ? 101 : 0,
            area: minimum == 'area' ? 10001 : 0,
            insufficient: policy,
          );
          TreemapGeometrySnapshot<String> run() =>
              TreemapLayoutEngine<String>().layout(
                tree: _tree(weights),
                viewport: _viewport,
                config: config,
              );
          if (policy == TreemapInsufficientSpacePolicy.error) {
            expect(run, throwsA(isA<TreemapLayoutException>()));
          } else {
            final snapshot = run();
            if (policy == TreemapInsufficientSpacePolicy.hide) {
              expect(snapshot.nodes, isEmpty);
            } else {
              expect(snapshot.nodes, hasLength(1));
              _expectProportional(snapshot);
              if (weights.length > 1) {
                expect(
                  snapshot.nodes.single.aggregateMembers,
                  hasLength(weights.length),
                );
              }
            }
          }
        });
      }
    }

    test('reveal never regenerates equivalent Other under $policy', () {
      final tree = _tree([70, 25, 3, 2]);
      final config = _config(width: 20, insufficient: policy);
      final engine = TreemapLayoutEngine<String>();
      final controller = TreemapController<String>()..synchronize(tree);
      addTearDown(controller.dispose);
      TreemapGeometrySnapshot<String> run() => engine.layout(
        tree: tree,
        viewport: _viewport,
        config: config,
        focus: controller.layoutFocus,
      );
      final original = run();
      final other = original.nodes.singleWhere((n) => n.isAggregate);
      controller.revealAggregate(
        other.key,
        memberKeys: other.aggregateMembers.map((n) => n.key),
      );
      expect(controller.layoutFocus!.aggregateMembers, other.aggregateMembers);
      if (policy == TreemapInsufficientSpacePolicy.error) {
        expect(run, throwsA(isA<TreemapLayoutException>()));
      } else {
        final revealed = run();
        expect(revealed.nodes.where((n) => n.isAggregate), isEmpty);
        expect(
          revealed.nodes.map((n) => n.key.sourceKey),
          policy == TreemapInsufficientSpacePolicy.show
              ? ['n1', 'n2', 'n3']
              : ['n1'],
        );
        if (policy == TreemapInsufficientSpacePolicy.hide) {
          _expectMinimums(revealed, config);
        }
      }
      controller.zoomOut();
      expect(controller.focusKey, const TreemapKey.source('root'));
      expect(run().nodes.singleWhere((n) => n.isAggregate).key, other.key);
      _expectMinimums(run(), config);
    });
  }

  test('successive reveals strictly reduce aggregate membership', () {
    final tree = _tree([70, 25, 3, 2]);
    final config = _config(width: 10);
    final controller = TreemapController<String>()..synchronize(tree);
    addTearDown(controller.dispose);
    final engine = TreemapLayoutEngine<String>();
    var previousCount = 5;
    for (var step = 0; step < 4; step++) {
      final snapshot = engine.layout(
        tree: tree,
        viewport: _viewport,
        config: config,
        focus: controller.layoutFocus,
      );
      _expectMinimums(snapshot, config);
      final aggregates = snapshot.nodes.where((n) => n.isAggregate);
      if (aggregates.isEmpty) {
        expect(snapshot.nodes.map((n) => n.key.sourceKey), ['n2', 'n3']);
        return;
      }
      final other = aggregates.single;
      expect(other.aggregateMembers.length, lessThan(previousCount));
      previousCount = other.aggregateMembers.length;
      controller.revealAggregate(
        other.key,
        memberKeys: other.aggregateMembers.map((n) => n.key),
      );
    }
    fail('Revealing must terminate in source tiles.');
  });
}
