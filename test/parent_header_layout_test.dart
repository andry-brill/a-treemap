import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/layout.dart' show TreemapLayoutRequest;
import 'package:flutter_test/flutter_test.dart';

final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [
      TreemapNode(
        key: 'parent',
        children: [
          TreemapNode(
            key: 'group',
            children: [
              TreemapNode(key: 'a', weight: 3),
              TreemapNode(key: 'b', weight: 1),
            ],
          ),
          TreemapNode(key: 'c', weight: 2),
        ],
      ),
      TreemapNode(key: 'd', weight: 2),
    ],
  ),
);
const _viewport = TreemapBounds.fromLTWH(0, 0, 640, 400);
const _parent = TreemapKey.source('parent');

void main() {
  test(
    'parent config supports disabled, fixed, and restored automatic height',
    () {
      const config = TreemapParentLabelConfig(height: 56);
      expect(config.copyWith(), config);
      expect(config.copyWith(height: null), const TreemapParentLabelConfig());
      expect(config.copyWith(showTitle: false).showValue, isTrue);
      expect(
        const TreemapParentLabelConfig(
          showTitle: false,
          showValue: false,
        ).enabled,
        isFalse,
      );
      for (final height in [-1.0, double.nan, double.infinity]) {
        expect(
          () => TreemapParentLabelConfig(height: height),
          throwsAssertionError,
        );
      }
    },
  );

  test('internal geometry input validates resolved header heights', () {
    final engine = TreemapLayoutEngine<String>();
    for (final height in [-1.0, double.nan, double.infinity]) {
      final request = TreemapLayoutRequest<String>(
        tree: _tree,
        viewport: _viewport,
        parentHeaderHeight: height,
      );
      expect(
        () => request.execute(engine),
        throwsA(isA<TreemapLayoutException>()),
      );
    }
  });

  for (final algorithm in TreemapLayoutAlgorithm.values) {
    test(
      '$algorithm reserves nested headers without changing sibling allocation',
      () {
        final engine = TreemapLayoutEngine<String>();
        final config = TreemapLayoutConfig<String>(
          policy: TreemapLayoutPolicy(
            rootRule: TreemapLayoutRule(algorithm: algorithm),
          ),
          levelPadding: const TreemapInsets.all(4),
        );
        final ordinary = engine.layout(
          tree: _tree,
          viewport: _viewport,
          config: config,
        );
        final headers = TreemapLayoutRequest<String>(
          tree: _tree,
          viewport: _viewport,
          config: config,
          parentHeaderHeight: 40,
        ).execute(engine);
        expect(TreemapGeometryDiagnostics.validate(headers), isEmpty);
        expect(headers.index[_parent]!.bounds, ordinary.index[_parent]!.bounds);
        expect(headers.index[_parent]!.weight, 6);
        expect(headers.index, isNot(contains(const TreemapKey.source('root'))));
        for (final parent in headers.nodes.where(
          (node) => node.headerBounds != null,
        )) {
          final inset = parent.bounds.inset(config.levelPadding);
          final header = parent.headerBounds!;
          expect(header.left, inset.left);
          expect(header.top, inset.top);
          expect(header.width, inset.width);
          expect(header.height, lessThanOrEqualTo(40));
          final children = headers.nodes.where(
            (node) => node.parentKey == parent.key,
          );
          for (final child in children) {
            expect(
              child.bounds.top,
              greaterThanOrEqualTo(header.bottom - 1e-7),
            );
          }
          expect(
            children.fold<double>(0, (sum, node) => sum + node.bounds.area),
            closeTo(inset.width * (inset.height - header.height), 1e-6),
          );
        }
      },
    );
  }

  test(
    'zero height remains a header; depth boundaries remain ordinary labels',
    () {
      final engine = TreemapLayoutEngine<String>();
      final zero = TreemapLayoutRequest<String>(
        tree: _tree,
        viewport: _viewport,
        parentHeaderHeight: 0,
      ).execute(engine);
      expect(zero.index[_parent]!.headerBounds!.height, 0);
      final depth = TreemapLayoutRequest<String>(
        tree: _tree,
        viewport: _viewport,
        config: const TreemapLayoutConfig(maxVisibleDepth: 1),
        parentHeaderHeight: 40,
      ).execute(engine);
      expect(depth.index[_parent]!.headerBounds, isNull);
      expect(depth.nodes, hasLength(2));
    },
  );

  test(
    'oversized headers stop descendants but preserve drill-down source data',
    () {
      final snapshot = TreemapLayoutRequest<String>(
        tree: _tree,
        viewport: _viewport,
        config: const TreemapLayoutConfig(levelPadding: TreemapInsets.all(8)),
        parentHeaderHeight: 1000,
      ).execute(TreemapLayoutEngine<String>());
      final parent = snapshot.index[_parent]!;
      expect(snapshot.nodes, hasLength(2));
      expect(
        parent.headerBounds,
        parent.bounds.inset(const TreemapInsets.all(8)),
      );
      expect(parent.node!.children, hasLength(2));
      expect(parent.weight, 6);
      expect(TreemapGeometryDiagnostics.validate(snapshot), isEmpty);
    },
  );

  test(
    'child culling preserves a single header and aggregates stay ordinary tiles',
    () {
      final tree = TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [
            TreemapNode(
              key: 'parent',
              children: [
                TreemapNode(key: 'a', weight: 1),
                TreemapNode(key: 'b', weight: 1),
              ],
            ),
          ],
        ),
      );
      for (final policy in [
        TreemapMinimumNodePolicy.hide,
        TreemapMinimumNodePolicy.aggregate,
      ]) {
        final snapshot = TreemapLayoutRequest<String>(
          tree: tree,
          viewport: _viewport,
          config: TreemapLayoutConfig(
            minimumHeight: 1000,
            minimumNodePolicy: policy,
          ),
          parentHeaderHeight: 40,
        ).execute(TreemapLayoutEngine<String>());
        expect(snapshot.index[_parent]!.headerBounds, isNotNull);
        expect(
          snapshot.nodes,
          hasLength(policy == TreemapMinimumNodePolicy.hide ? 1 : 2),
        );
        for (final aggregate in snapshot.nodes.where(
          (node) => node.isAggregate,
        )) {
          expect(aggregate.headerBounds, isNull);
          expect(aggregate.weight, 2);
        }
      }
    },
  );

  test('header transitions keep entering children below the moving header', () {
    final engine = TreemapLayoutEngine<String>();
    final from = TreemapLayoutRequest<String>(
      tree: _tree,
      viewport: _viewport,
      parentHeaderHeight: 1000,
    ).execute(engine);
    final to = TreemapLayoutRequest<String>(
      tree: _tree,
      viewport: _viewport,
      parentHeaderHeight: 20,
    ).execute(engine);
    for (final t in [.1, .5, .9]) {
      final frame = TreemapGeometryTransition.lerp(from, to, t);
      expect(TreemapGeometryDiagnostics.validate(frame), isEmpty);
      final header = frame.index[_parent]!.headerBounds!;
      expect(
        header.height,
        closeTo(
          from.index[_parent]!.headerBounds!.height * (1 - t) + 20 * t,
          1e-7,
        ),
      );
      for (final child in frame.nodes.where(
        (node) => node.parentKey == _parent,
      )) {
        expect(child.bounds.top, greaterThanOrEqualTo(header.bottom - 1e-7));
      }
      final reverse = TreemapGeometryTransition.lerp(to, from, t);
      expect(TreemapGeometryDiagnostics.validate(reverse), isEmpty);
      for (final child in reverse.nodes.where(
        (node) => node.parentKey == _parent,
      )) {
        expect(
          child.bounds.top,
          greaterThanOrEqualTo(
            reverse.index[_parent]!.headerBounds!.bottom - 1e-7,
          ),
        );
      }
    }
    expect(
      to.index[_parent]!.copyWith(headerBounds: null).headerBounds,
      isNull,
    );
  });

  test('internal header request produces identical isolate geometry', () async {
    final engine = TreemapLayoutEngine<String>();
    const config = TreemapLayoutConfig<String>(
      levelPadding: TreemapInsets.all(4),
    );
    final request = TreemapLayoutRequest<String>(
      tree: _tree,
      viewport: _viewport,
      config: config,
      parentHeaderHeight: 32,
    );
    final direct = request.execute(engine);
    final isolated = await request.executeAsync(
      engine,
      fallbackToSynchronous: false,
    );
    expect(isolated.index.keys, orderedEquals(direct.index.keys));
    for (final node in isolated.nodes) {
      expect(node.bounds, direct.index[node.key]!.bounds);
      expect(node.headerBounds, direct.index[node.key]!.headerBounds);
    }
  });

  test(
    'public headless layout has no reserved headers after an internal request',
    () async {
      final engine = TreemapLayoutEngine<String>();
      final headers = TreemapLayoutRequest<String>(
        tree: _tree,
        viewport: _viewport,
        parentHeaderHeight: 32,
      ).execute(engine);
      expect(headers.index[_parent]!.headerBounds, isNotNull);
      final direct = engine.layout(tree: _tree, viewport: _viewport);
      final isolated = await engine.layoutAsync(
        tree: _tree,
        viewport: _viewport,
        fallbackToSynchronous: false,
      );
      expect(isolated.index.keys, orderedEquals(direct.index.keys));
      for (final node in isolated.nodes) {
        expect(node.bounds, direct.index[node.key]!.bounds);
        expect(node.headerBounds, isNull);
        expect(direct.index[node.key]!.headerBounds, isNull);
      }
    },
  );
}
