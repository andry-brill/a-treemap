import 'package:any_treemap/any_treemap.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(
      key: 'expenses',
      children: [
        TreemapNode(
          key: 'food',
          children: [
            TreemapNode(key: 'groceries', weight: 4),
            TreemapNode(key: 'cafes', weight: 2),
          ],
        ),
        TreemapNode(key: 'transport', weight: 5),
        TreemapNode(
          key: 'other',
          children: [
            for (final key in ['rent', 'utilities', 'pharmacy', 'games'])
              TreemapNode(key: key, weight: 2),
          ],
        ),
      ],
    ),
    TreemapNode(key: 'unassigned', weight: 1),
  ],
);

const _viewport = TreemapBounds.fromLTWH(0, 0, 600, 400);

List<String?> _keys(TreemapGeometrySnapshot<String> snapshot) =>
    snapshot.nodes.map((node) => node.key.sourceKey).toList();

void main() {
  test('visible depth defaults, validation, and nullable copyWith', () {
    const unlimited = TreemapLayoutConfig<String>();
    expect(unlimited.maxVisibleDepth, isNull);
    final limited = unlimited.copyWith(maxVisibleDepth: 2);
    expect(limited.maxVisibleDepth, 2);
    expect(limited.copyWith(innerSpacing: 4).maxVisibleDepth, 2);
    expect(limited.copyWith(maxVisibleDepth: null).maxVisibleDepth, isNull);
    expect(limited.copyWith(maxVisibleDepth: 1).maxVisibleDepth, 1);
    for (final depth in [0, -1]) {
      expect(
        () => TreemapLayoutEngine<String>().layout(
          root: _tree(),
          viewport: _viewport,
          config: TreemapLayoutConfig(maxVisibleDepth: depth),
        ),
        throwsA(isA<TreemapLayoutException>()),
      );
    }
  });

  for (final algorithm in TreemapLayoutAlgorithm.values) {
    test('$algorithm limits traversal without changing retained geometry', () {
      final root = _tree();
      final config = TreemapLayoutConfig<String>(
        policy: TreemapLayoutPolicy(
          rootRule: TreemapLayoutRule(algorithm: algorithm),
        ),
        levelPadding: const TreemapInsets.all(4),
        innerSpacing: 2,
      );
      final engine = TreemapLayoutEngine<String>();
      TreemapGeometrySnapshot<String> run(int? depth) => engine.layout(
        root: root,
        viewport: _viewport,
        config: config.copyWith(maxVisibleDepth: depth),
      );
      final unlimited = run(null);
      final one = run(1);
      final two = run(2);
      expect(_keys(one), unorderedEquals(['expenses', 'unassigned']));
      expect(
        _keys(two),
        unorderedEquals([
          'expenses',
          'unassigned',
          'food',
          'transport',
          'other',
        ]),
      );
      expect(_keys(run(100)), _keys(unlimited));
      for (final snapshot in [one, two]) {
        expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
        for (final node in snapshot.nodes) {
          final full = unlimited.index[node.key]!;
          expect(node.bounds, full.bounds);
          expect(node.weight, full.weight);
          expect(node.depth, full.depth);
          expect(node.node, same(full.node));
        }
      }
      final expenses = one.index[const TreemapKey.source('expenses')]!;
      expect(expenses.weight, 19);
      expect(expenses.hasChildren, isTrue);
      expect(expenses.isAggregate, isFalse);
      expect(one.nodes.fold<double>(0, (sum, node) => sum + node.weight), 20);
      expect(
        one.hitTest(expenses.bounds.centerX, expenses.bounds.centerY),
        same(expenses),
      );
    });
  }

  test('focus restarts depth while rules and paths retain absolute depths', () {
    final visited = <(String, int)>[];
    final snapshot = TreemapLayoutEngine<String>().layout(
      root: _tree(),
      viewport: _viewport,
      focus: TreemapFocus.source('expenses'),
      config: TreemapLayoutConfig(
        maxVisibleDepth: 1,
        policy: TreemapLayoutPolicy(
          byChildDepth: const {
            2: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.dice),
          },
          resolver: (context) {
            visited.add((context.parent.key, context.childDepth));
            return null;
          },
        ),
      ),
    );
    expect(_keys(snapshot), unorderedEquals(['food', 'transport', 'other']));
    expect(visited, [('expenses', 2)]);
    expect(snapshot.path.map((entry) => entry.depth), [0, 1]);
    for (final node in snapshot.nodes) {
      expect(node.depth, 2);
      expect(node.bounds.height, 400);
    }
    final deeper = TreemapLayoutEngine<String>().layout(
      root: _tree(),
      viewport: _viewport,
      focus: TreemapFocus.source('food'),
      config: const TreemapLayoutConfig(maxVisibleDepth: 1),
    );
    expect(_keys(deeper), unorderedEquals(['groceries', 'cafes']));
    expect(deeper.nodes.every((node) => node.depth == 3), isTrue);
  });

  test('aggregate reveal restarts the limit and preserves source branches', () {
    final root = TreemapNode<String>(
      key: 'root',
      children: [
        TreemapNode(key: 'large', weight: 1000),
        TreemapNode(
          key: 'small-branch',
          children: [TreemapNode(key: 'hidden', weight: 2)],
        ),
        TreemapNode(key: 'small-leaf', weight: 1),
      ],
    );
    const config = TreemapLayoutConfig<String>(
      maxVisibleDepth: 1,
      minimumWidth: 20,
      minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
      policy: TreemapLayoutPolicy(
        rootRule: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.dice),
      ),
    );
    final engine = TreemapLayoutEngine<String>();
    final snapshot = engine.layout(
      root: root,
      viewport: _viewport,
      config: config,
    );
    final aggregate = snapshot.nodes.singleWhere((node) => node.isAggregate);
    expect(aggregate.weight, 3);
    final controller = TreemapController<String>()..synchronize(root);
    addTearDown(controller.dispose);
    controller.revealAggregate(
      TreemapNodeDetails(geometry: aggregate, path: snapshot.path),
    );
    final revealed = engine.layout(
      root: root,
      viewport: _viewport,
      config: config,
      focus: controller.layoutFocus,
    );
    expect(_keys(revealed), unorderedEquals(['small-branch', 'small-leaf']));
    expect(revealed.nodes.every((node) => node.depth == 2), isTrue);
    final deeper = engine.layout(
      root: root,
      viewport: _viewport,
      config: config.copyWith(maxVisibleDepth: 2),
      focus: controller.layoutFocus,
    );
    expect(_keys(deeper), contains('hidden'));
    controller.zoomOut();
    expect(controller.focusKey, const TreemapKey.source('root'));
  });

  test('isolate layout applies the same focus-relative cutoff', () async {
    final root = _tree();
    final engine = TreemapLayoutEngine<String>();
    const config = TreemapLayoutConfig<String>(maxVisibleDepth: 1);
    final sync = engine.layout(
      root: root,
      viewport: _viewport,
      config: config,
      focus: TreemapFocus.source('expenses'),
    );
    final async = await engine.layoutAsync(
      root: root,
      viewport: _viewport,
      config: config,
      focus: TreemapFocus.source('expenses'),
      fallbackToSynchronous: false,
    );
    expect(async.toStringDeep(), sync.toStringDeep());
  });
}
