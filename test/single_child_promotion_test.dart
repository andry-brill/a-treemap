import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNormalizedTree<K> _promote<K>(TreemapNode<K> root) =>
    TreemapNormalizer.normalize(
      root,
      singleChildPolicy: TreemapSingleChildPolicy.promote,
    );

TreemapNode<String> _domainTree() => TreemapNode(
  key: 'root',
  label: 'All',
  children: [
    TreemapNode(
      key: 'a',
      label: 'A',
      children: [
        TreemapNode(key: 'ten', label: 'Ten', weight: 10),
        TreemapNode(key: 'thirty', label: 'Thirty', weight: 30),
      ],
    ),
    TreemapNode(
      key: 'b',
      label: 'B',
      color: 1000,
      children: [TreemapNode(key: 'sixty', label: 'Sixty', weight: 60)],
    ),
  ],
);

final class _Capture implements TreemapTileLayer<String> {
  late TreemapVisualContext<String> visual;
  @override
  TreemapAppearanceResolver<String>? get appearance => null;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return const SizedBox.expand();
  }
}

void main() {
  test('default and explicit preserve retain the original hierarchy', () {
    final root = _domainTree();
    final implicit = TreemapNormalizer.normalize(root);
    final explicit = TreemapNormalizer.normalize(
      root,
      singleChildPolicy: TreemapSingleChildPolicy.preserve,
    );
    expect(implicit.root, same(root));
    expect(explicit.root, same(root));
    expect(explicit.nodes, implicit.nodes);
    expect(explicit.parents, implicit.parents);
    expect(explicit.depths, implicit.depths);
    expect(explicit.totals, implicit.totals);
    expect(explicit.totals.keys, ['ten', 'thirty', 'a', 'sixty', 'b', 'root']);
    expect(explicit.globalColorDomain, (10, 1000));
    expect(explicit.pathTo('sixty').map((n) => n.key), ['root', 'b', 'sixty']);
  });

  test('promotion discards ancestry and derives indexes and domains anew', () {
    final root = _domainTree();
    final tree = _promote(root);
    expect(tree.root.children.map((n) => n.key), ['a', 'sixty']);
    expect(tree.nodes.keys, ['root', 'a', 'ten', 'thirty', 'sixty']);
    expect(tree.parents['sixty'], 'root');
    expect(tree.depths['sixty'], 1);
    expect(tree.pathTo('sixty').map((n) => n.key), ['root', 'sixty']);
    expect(tree.pathTo('b'), isEmpty);
    for (final index in [tree.nodes, tree.parents, tree.depths, tree.totals]) {
      expect(index.containsKey('b'), isFalse);
    }
    expect(tree.totals, {
      'root': 100,
      'a': 40,
      'ten': 10,
      'thirty': 30,
      'sixty': 60,
    });
    expect(tree.globalColorDomain, (10, 60));
    expect(root.children.last.key, 'b');
    expect(tree.nodes['a'], same(root.children.first));
    expect(tree.nodes['sixty'], same(root.children.last.children.single));
    expect(_promote(tree.root).root, same(tree.root));
    expect(() => tree.nodes.clear(), throwsUnsupportedError);
    expect(() => tree.parents.clear(), throwsUnsupportedError);
    expect(() => tree.depths.clear(), throwsUnsupportedError);
    expect(() => tree.totals.clear(), throwsUnsupportedError);
    expect(() => tree.root.children.clear(), throwsUnsupportedError);
  });

  test('chains preserve child metadata, branching nodes and sibling order', () {
    final payload = Object();
    final leaf = TreemapNode(
      key: 'leaf',
      weight: 10,
      label: 'Child',
      valueLabel: 'ten',
      semanticLabel: 'Child semantics',
      color: 5,
      data: payload,
    );
    final branch = TreemapNode(
      key: 'branch',
      children: [
        TreemapNode(key: 'x', weight: 2),
        TreemapNode(key: 'y', weight: 3),
      ],
    );
    final root = TreemapNode(
      key: 'root',
      weight: 999,
      label: 'Container',
      valueLabel: 'total',
      semanticLabel: 'Root semantics',
      color: -1000,
      data: payload,
      children: [
        TreemapNode(key: 'before', weight: 1),
        TreemapNode(
          key: 'outer',
          children: [
            TreemapNode(key: 'inner', children: [leaf]),
          ],
        ),
        TreemapNode(key: 'wrapper', children: [branch]),
        TreemapNode(key: 'after', weight: 4),
      ],
    );
    final tree = _promote(root);
    expect(tree.root.children.map((n) => n.key), [
      'before',
      'leaf',
      'branch',
      'after',
    ]);
    expect(tree.nodes['leaf'], same(leaf));
    expect(tree.nodes['leaf']!.data, same(payload));
    expect(tree.nodes['branch'], same(branch));
    expect(tree.depths['x'], 2);
    expect(tree.root.key, root.key);
    expect(tree.root.label, root.label);
    expect(tree.root.valueLabel, root.valueLabel);
    expect(tree.root.semanticLabel, root.semanticLabel);
    expect(tree.root.weight, root.weight);
    expect(tree.root.color, root.color);
    expect(tree.root.data, same(payload));
    expect(tree.totals['root'], 20);
  });

  test('parent metadata is not inherited even when child fields are null', () {
    final leaf = TreemapNode(key: 'leaf', weight: 0);
    final root = TreemapNode(
      key: 'root',
      children: [
        TreemapNode(
          key: 'parent',
          label: 'Parent',
          valueLabel: 'parent value',
          semanticLabel: 'Parent semantics',
          color: 999,
          data: Object(),
          children: [leaf],
        ),
      ],
    );
    final tree = _promote(root);
    expect(tree.root.key, 'root');
    expect(tree.root.children.single, same(leaf));
    expect(tree.nodes['parent'], isNull);
    expect(tree.globalColorDomain, (0, 0));
    expect(tree.totals['root'], 0);
  });

  test('leaf and empty container roots are retained', () {
    for (final weight in [0.0, 10.0]) {
      final root = TreemapNode(key: 'root', weight: weight, color: -1);
      final tree = _promote(root);
      expect(tree.root, same(root));
      expect(tree.nodes.keys, ['root']);
      expect(tree.parents['root'], isNull);
      expect(tree.depths['root'], 0);
      expect(tree.globalColorDomain, isNull);
    }
  });

  test(
    'zero-weight siblings count as source children and keep their parent',
    () {
      final branch = TreemapNode(
        key: 'branch',
        children: [
          TreemapNode(key: 'zero', weight: 0),
          TreemapNode(key: 'positive', weight: 10),
        ],
      );
      final tree = _promote(TreemapNode(key: 'root', children: [branch]));
      expect(tree.root.children.single, same(branch));
      expect(tree.parents['positive'], 'branch');
      expect(tree.depths['zero'], 2);
    },
  );

  test('promotion handles deep chains iteratively', () {
    var root = TreemapNode(key: 5000, weight: 7);
    final leaf = root;
    for (var i = 4999; i >= 0; i--) {
      root = TreemapNode(key: i, children: [root]);
    }
    final tree = _promote(root);
    expect(tree.root.key, 0);
    expect(tree.root.children.single, same(leaf));
    expect(tree.nodes.keys, [0, 5000]);
    expect(tree.depths[5000], 1);
    expect(tree.totals[0], 7);
  });

  for (final invalid in [double.nan, double.infinity, -1.0]) {
    test('validates a removed parent with weight $invalid', () {
      expect(
        () => _promote(
          TreemapNode(
            key: 'root',
            children: [
              TreemapNode(
                key: 'parent',
                weight: invalid,
                children: [TreemapNode(key: 'leaf', weight: 1)],
              ),
            ],
          ),
        ),
        throwsA(
          isA<TreemapValidationException<String>>().having(
            (e) => e.issues.map((issue) => issue.code),
            'codes',
            contains(TreemapValidationCode.invalidWeight),
          ),
        ),
      );
    });
  }
  test('removed parents still participate in key and identity validation', () {
    final shared = TreemapNode(key: 'leaf', weight: 1);
    final fixtures = <(TreemapNode<String>, TreemapValidationCode)>[
      (
        TreemapNode(
          key: 'root',
          children: [
            TreemapNode(key: '', children: [shared]),
          ],
        ),
        TreemapValidationCode.emptyKey,
      ),
      (
        TreemapNode(
          key: 'root',
          children: [
            TreemapNode(key: 'leaf', children: [shared]),
          ],
        ),
        TreemapValidationCode.duplicateKey,
      ),
      (
        TreemapNode(
          key: 'root',
          children: [
            TreemapNode(key: 'a', children: [shared]),
            TreemapNode(key: 'b', children: [shared]),
          ],
        ),
        TreemapValidationCode.cycle,
      ),
    ];
    for (final (root, code) in fixtures) {
      expect(
        () => _promote(root),
        throwsA(
          isA<TreemapValidationException<String>>().having(
            (e) => e.issues.map((issue) => issue.code),
            'codes',
            contains(code),
          ),
        ),
      );
    }
  });

  test(
    'record construction and equivalent explicit input promote identically',
    () {
      final root = _domainTree();
      final records = [
        (id: 'ten', group: 'a', weight: 10.0),
        (id: 'thirty', group: 'a', weight: 30.0),
        (id: 'sixty', group: 'b', weight: 60.0),
      ];
      final fromRecords =
          TreemapNode.fromRecords<
            ({String id, String group, double weight}),
            String
          >(
            rootKey: 'root',
            records: records,
            leafKey: (r) => r.id,
            weight: (r) => r.weight,
            levels: [TreemapRecordLevel(key: (r) => r.group)],
          );
      final a = _promote(root);
      final b = _promote(fromRecords);
      expect(b.nodes.keys, a.nodes.keys);
      expect(b.parents, a.parents);
      expect(b.depths, a.depths);
      expect(b.totals, a.totals);
      expect(b.globalColorDomain, a.globalColorDomain);
    },
  );

  test(
    'prepared layout, standalone presentation and isolate layout agree',
    () async {
      final tree = _promote(_domainTree());
      final engine = TreemapLayoutEngine<String>();
      const viewport = TreemapBounds.fromLTWH(0, 0, 600, 400);
      const config = TreemapLayoutConfig<String>(maxVisibleDepth: 1);
      final sync = engine.layout(
        tree: tree,
        viewport: viewport,
        config: config,
      );
      final asynchronous = await engine.layoutAsync(
        tree: tree,
        viewport: viewport,
        config: config,
        fallbackToSynchronous: false,
      );
      expect(
        asynchronous.nodes.map((n) => n.key),
        sync.nodes.map((n) => n.key),
      );
      expect(
        asynchronous.nodes.map((n) => n.bounds),
        sync.nodes.map((n) => n.bounds),
      );
      expect(sync.nodes.map((n) => n.key).toSet(), {
        const TreemapKey.source('a'),
        const TreemapKey.source('sixty'),
      });
      final state = TreemapPresentationState.fromData(
        tree: tree,
        targetSnapshot: sync,
      );
      final scale = state.resolveColorScale(
        TreemapColorScale.interpolated(
          colors: const [Colors.blue, Colors.red],
          fallback: Colors.grey,
        ),
      );
      expect(scale.minimum, 10);
      expect(scale.maximum, 60);
      expect(state.details.containsKey(const TreemapKey.source('b')), isFalse);
    },
  );

  testWidgets('charts and breadcrumbs share only prepared identities', (
    tester,
  ) async {
    final tree = _promote<String>(
      TreemapNode<String>(
        key: 'root',
        label: 'All',
        children: [
          TreemapNode(
            key: 'removed',
            label: 'Removed',
            children: [_domainTree().children.first],
          ),
          _domainTree().children.last,
        ],
      ),
    );
    final left = TreemapController<String>();
    final right = TreemapController<String>();
    addTearDown(left.dispose);
    addTearDown(right.dispose);
    final capture = _Capture();
    final otherCapture = _Capture();
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final controller in [left, right])
              Expanded(
                child: TreemapChart<String>(
                  tree: tree,
                  controller: controller,
                  tiles: identical(controller, right) ? capture : otherCapture,
                  surrounding: const TreemapBreadcrumbs<String>(),
                  layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(left.zoomTo('removed').status, TreemapCommandStatus.missingKey);
    expect(
      left.zoomTo('sixty').status,
      TreemapCommandStatus.leafCannotBeFocused,
    );
    left.setSelection({
      const TreemapKey.source('removed'),
      const TreemapKey.source('ten'),
    });
    expect(left.selectedEntries, {const TreemapKey.source('ten')});
    left.zoomTo('a');
    await tester.pumpAndSettle();
    expect(left.currentPath.map((e) => e.key.sourceKey), ['root', 'a']);
    expect(find.text('Removed'), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(right.focusKey, const TreemapKey.source('root'));
    capture.visual.actions.hover(const TreemapKey.source('sixty'));
    await tester.pumpAndSettle();
    expect(
      capture.visual.presentation.hoveredKey,
      const TreemapKey.source('sixty'),
    );
    expect(
      capture.visual.presentation.details.containsKey(
        const TreemapKey.source('b'),
      ),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
