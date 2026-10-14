import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CustomScale extends TreemapColorScale {
  @override
  Color colorFor(Object? value) => Colors.purple;
  @override
  List<TreemapLegendEntry> get legendEntries => const [];
}

TreemapColorScale _scale({
  double minimum = double.negativeInfinity,
  double maximum = double.infinity,
  TreemapColorDomainScope scope = TreemapColorDomainScope.global,
  bool saturation = false,
}) => saturation
    ? TreemapSaturationColorScale(
        minimum: minimum,
        maximum: maximum,
        domainScope: scope,
        color: Colors.blue,
        fallback: Colors.pink,
      )
    : TreemapInterpolatedColorScale(
        minimum: minimum,
        maximum: maximum,
        domainScope: scope,
        colors: const [Colors.black, Colors.white],
        fallback: Colors.pink,
      );

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(
      key: 'a',
      children: [
        TreemapNode(key: 'ten', weight: 10),
        TreemapNode(key: 'thirty', weight: 30),
      ],
    ),
    TreemapNode(
      key: 'b',
      children: [TreemapNode(key: 'sixty', weight: 60)],
    ),
  ],
);

void _bounds(TreemapColorScale scale, double? minimum, double? maximum) {
  expect(scale.minimum, minimum);
  expect(scale.maximum, maximum);
}

void main() {
  for (final saturation in [false, true]) {
    group(saturation ? 'automatic saturation' : 'automatic interpolation', () {
      test(
        'defaults, filtering, clamping and independent immutable resolution',
        () {
          final scale = _scale(saturation: saturation);
          _bounds(scale, double.negativeInfinity, double.infinity);
          final resolved = scale.resolveDomain([
            10,
            30.0,
            60,
            null,
            'category',
            Colors.red,
            double.nan,
            double.infinity,
          ]);
          _bounds(resolved, 10, 60);
          _bounds(scale.resolveDomain([-4, -2]), -4, -2);
          _bounds(scale, double.negativeInfinity, double.infinity);
          expect(resolved.colorFor(0), resolved.colorFor(10));
          expect(resolved.colorFor(70), resolved.colorFor(60));
          expect(resolved.colorFor('category'), Colors.pink);
          expect(resolved.colorFor(double.nan), Colors.pink);
          expect(treemapColorFraction(resolved, 35), .5);
          expect(resolved.legendEntries.map((entry) => entry.value), [10, 60]);
          expect(treemapSampleScale(resolved, count: 1), hasLength(2));
        },
      );

      test(
        'either bound can be fixed and crossed inferred bounds collapse',
        () {
          final fixedMinimum = _scale(
            minimum: 0,
            saturation: saturation,
          ).resolveDomain([10, 60]);
          _bounds(fixedMinimum, 0, 60);
          _bounds(
            _scale(
              maximum: 100,
              saturation: saturation,
            ).resolveDomain([10, 60]),
            10,
            100,
          );
          final lower = _scale(
            minimum: 0,
            saturation: saturation,
          ).resolveDomain([-10, -5]);
          _bounds(lower, 0, 0);
          expect(treemapColorFraction(lower, -5), 0);
          final upper = _scale(
            maximum: 0,
            saturation: saturation,
          ).resolveDomain([5, 10]);
          _bounds(upper, 0, 0);
          expect(treemapColorFraction(upper, 5), 1);
        },
      );

      test(
        'constant and empty domains have safe colors, legends and fractions',
        () {
          final scale = _scale(saturation: saturation);
          final constant = scale.resolveDomain([5, 5]);
          final reference = _scale(
            minimum: 0,
            maximum: 10,
            saturation: saturation,
          );
          _bounds(constant, 5, 5);
          expect(constant.colorFor(5), reference.colorFor(5));
          expect(constant.colorFor(4), reference.colorFor(0));
          expect(constant.colorFor(6), reference.colorFor(10));
          expect(constant.legendEntries, hasLength(1));
          expect(constant.legendEntries.single.color, reference.colorFor(5));
          expect(treemapColorFraction(constant, 5), .5);
          expect(treemapColorFraction(constant, double.nan), 0);
          expect(
            treemapSampleScale(constant, count: 3),
            List.filled(3, reference.colorFor(5)),
          );
          final empty = scale.resolveDomain([
            null,
            'x',
            Colors.red,
            double.infinity,
          ]);
          _bounds(empty, null, null);
          expect(empty.colorFor(7), Colors.pink);
          expect(empty.legendEntries, isEmpty);
          expect(treemapSampleScale(empty), isEmpty);
          expect(treemapColorFraction(empty, 7), 0);
          _bounds(
            _scale(minimum: 0, saturation: saturation).resolveDomain([]),
            null,
            null,
          );
        },
      );

      test(
        'unresolved use fails and wrong sentinels and finite domains are rejected',
        () {
          final scale = _scale(saturation: saturation);
          expect(() => scale.colorFor(1), throwsStateError);
          expect(() => scale.legendEntries, throwsStateError);
          expect(() => treemapSampleScale(scale), throwsStateError);
          expect(() => treemapColorFraction(scale, 1), throwsStateError);
          for (final bounds in [
            (double.nan, 1.0),
            (0.0, double.nan),
            (double.infinity, double.infinity),
            (double.negativeInfinity, double.negativeInfinity),
            (1.0, 1.0),
            (2.0, 1.0),
          ]) {
            expect(
              () => _scale(
                minimum: bounds.$1,
                maximum: bounds.$2,
                saturation: saturation,
              ),
              throwsArgumentError,
            );
          }
        },
      );

      test('finite extreme numbers do not overflow interpolation', () {
        final resolved = _scale(
          saturation: saturation,
        ).resolveDomain([-double.maxFinite, double.maxFinite]);
        expect(treemapColorFraction(resolved, 0), .5);
        expect(treemapSampleScale(resolved, count: 3)[1], resolved.colorFor(0));
        expect(
          resolved.legendEntries.every(
            (entry) => (entry.value as num).isFinite,
          ),
          isTrue,
        );
      });
    });
  }

  test('multiple stops and formatter survive automatic resolution', () {
    final scale = TreemapColorScale.interpolated(
      colors: const [Colors.blue, Colors.yellow, Colors.red],
      fallback: Colors.grey,
      labelFormatter: (value) => '${value.round()} kg',
    ).resolveDomain([10, 60]);
    expect(scale.colorFor(35).toARGB32(), Colors.yellow.toARGB32());
    expect(scale.legendEntries.map((entry) => entry.label), [
      '10 kg',
      '35 kg',
      '60 kg',
    ]);
  });

  test(
    'explicit and custom scales pass through without reading candidates',
    () {
      Iterable<Object?> unreadable() sync* {
        throw StateError('must not iterate');
      }

      for (final scale in [
        _scale(minimum: 0, maximum: 1),
        _CustomScale(),
        TreemapColorScale.exact({}, fallback: Colors.red),
      ]) {
        expect(scale.resolveDomain(unreadable()), same(scale));
      }
    },
  );

  test('global and visible scopes use branch totals, depth and focus', () {
    final root = _tree();
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(root));
    addTearDown(controller.dispose);
    var presentation = TreemapPresentationState.fromData(
      tree: TreemapNormalizer.normalize(root),
    );
    final global = _scale();
    final visible = _scale(scope: TreemapColorDomainScope.visible);
    _bounds(presentation.resolveColorScale(global), 10, 60);
    _bounds(presentation.resolveColorScale(visible), null, null);
    final engine = TreemapLayoutEngine<String>();
    void layout(int? depth) {
      presentation = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(root),
        targetSnapshot: engine.layout(
          tree: TreemapNormalizer.normalize(root),
          viewport: const TreemapBounds.fromLTWH(0, 0, 600, 400),
          config: TreemapLayoutConfig(maxVisibleDepth: depth),
          focus: controller.layoutFocus,
        ),
      );
    }

    layout(1);
    _bounds(presentation.resolveColorScale(visible), 40, 60);
    layout(null);
    _bounds(presentation.resolveColorScale(visible), 10, 60);
    controller.zoomTo('a');
    layout(1);
    _bounds(presentation.resolveColorScale(visible), 10, 30);
    _bounds(presentation.resolveColorScale(global), 10, 60);
  });

  test(
    'effective inputs ignore direct colors, categories and invalid numbers',
    () {
      final root = TreemapNode<String>(
        key: 'root',
        color: -9999,
        children: [
          TreemapNode(key: 'number', weight: 100, color: -10),
          TreemapNode(key: 'weight', weight: 20),
          TreemapNode(key: 'direct', weight: 1000, color: Colors.red),
          TreemapNode(key: 'category', weight: 2000, color: 'category'),
          TreemapNode(key: 'nan', weight: 3000, color: double.nan),
        ],
      );
      final presentation = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(root),
      );
      _bounds(presentation.resolveColorScale(_scale()), -10, 20);
    },
  );

  test(
    'culling and aggregates affect only visible scope, including reveal',
    () {
      final root = TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(key: 'large', weight: 1000),
          TreemapNode(key: 'small1', weight: 1),
          TreemapNode(key: 'small2', weight: 2),
        ],
      );
      final controller = TreemapController<String>()
        ..synchronize(TreemapNormalizer.normalize(root));
      addTearDown(controller.dispose);
      final engine = TreemapLayoutEngine<String>();
      final visible = _scale(scope: TreemapColorDomainScope.visible);
      TreemapGeometrySnapshot<String> layout(TreemapMinimumNodePolicy policy) =>
          engine.layout(
            tree: TreemapNormalizer.normalize(root),
            viewport: const TreemapBounds.fromLTWH(0, 0, 600, 400),
            config: TreemapLayoutConfig(
              minimumWidth: 20,
              minimumHeight: 20,
              minimumNodePolicy: policy,
            ),
            focus: controller.layoutFocus,
          );
      var presentation = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(root),
        targetSnapshot: layout(TreemapMinimumNodePolicy.hide),
      );
      _bounds(presentation.resolveColorScale(visible), 1000, 1000);
      final aggregated = layout(TreemapMinimumNodePolicy.aggregate);
      presentation = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(root),
        targetSnapshot: aggregated,
      );
      _bounds(presentation.resolveColorScale(visible), 3, 1000);
      _bounds(presentation.resolveColorScale(_scale()), 1, 1000);
      final aggregate = aggregated.visibleNodes.singleWhere(
        (node) => node.isAggregate,
      );
      controller.revealAggregate(
        aggregate.key,
        memberKeys: aggregate.aggregateMembers.map((node) => node.key),
      );
      presentation = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(root),
        targetSnapshot: layout(TreemapMinimumNodePolicy.aggregate),
      );
      _bounds(presentation.resolveColorScale(visible), 1, 2);
    },
  );

  test(
    'one immutable scale resolves independently in multiple presentations',
    () {
      final scale = _scale();
      final a = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(_tree()),
      );
      final b = TreemapPresentationState.fromData(
        tree: TreemapNormalizer.normalize(
          TreemapNode(
            key: 'root',
            children: [
              TreemapNode(key: 'x', weight: 100),
              TreemapNode(key: 'y', weight: 200),
            ],
          ),
        ),
      );
      _bounds(a.resolveColorScale(scale), 10, 60);
      _bounds(b.resolveColorScale(scale), 100, 200);
      _bounds(a.resolveColorScale(scale), 10, 60);
    },
  );
}
