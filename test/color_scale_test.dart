import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact and categorical scales provide stable fallbacks and legends', () {
    final exact = TreemapColorScale.exact(
      {'a': Colors.red, 'b': Colors.blue},
      labels: {'a': 'Alpha'},
      fallback: Colors.black,
    );
    expect(exact.colorFor('a'), Colors.red);
    expect(exact.colorFor('missing'), Colors.black);
    expect(exact.legendEntries.first.label, 'Alpha');

    final categorical = TreemapColorScale.categorical([
      Colors.red,
      Colors.blue,
    ], fallback: Colors.black);
    expect(categorical.colorFor('stable'), categorical.colorFor('stable'));
    expect(categorical.legendEntries, hasLength(2));
  });

  test('numeric ranges validate overlap and include the final boundary', () {
    final scale = TreemapColorScale.numericRange([
      const TreemapNumericColorRange(
        minimum: 0,
        maximum: 10,
        color: Colors.green,
      ),
      const TreemapNumericColorRange(
        minimum: 10,
        maximum: 20,
        color: Colors.orange,
      ),
    ], fallback: Colors.black);
    expect(scale.colorFor(0), Colors.green);
    expect(scale.colorFor(10), Colors.orange);
    expect(scale.colorFor(20), Colors.orange);
    expect(
      () => TreemapColorScale.numericRange([
        const TreemapNumericColorRange(
          minimum: 0,
          maximum: 10,
          color: Colors.red,
        ),
        const TreemapNumericColorRange(
          minimum: 9,
          maximum: 12,
          color: Colors.blue,
        ),
      ], fallback: Colors.black),
      throwsArgumentError,
    );
  });

  test('interpolated and saturation scales clamp their domains', () {
    final interpolated = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 100,
      colors: [Colors.black, Colors.white],
      fallback: Colors.red,
    );
    expect(interpolated.colorFor(-10), Colors.black);
    expect(interpolated.colorFor(1000), Colors.white);
    expect(interpolated.isContinuous, isTrue);
    expect(treemapSampleScale(interpolated, count: 5), hasLength(5));

    final saturation = TreemapColorScale.saturation(
      minimum: 0,
      maximum: 1,
      color: Colors.blue,
      fallback: Colors.black,
    );
    expect(saturation.colorFor(0), isNot(saturation.colorFor(1)));
    expect(treemapColorFraction(saturation, .25), .25);
  });

  test('continuous scales expose legend label formatting', () {
    final interpolated = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 10,
      colors: [Colors.black, Colors.white],
      fallback: Colors.red,
      labelFormatter: (value) => '${value.round()} kg',
    );
    expect(interpolated.legendEntries.map((entry) => entry.label), [
      '0 kg',
      '10 kg',
    ]);

    final saturation = TreemapColorScale.saturation(
      minimum: 0,
      maximum: 1,
      color: Colors.blue,
      fallback: Colors.black,
      labelFormatter: (value) => '${(value * 100).round()}%',
    );
    expect(saturation.legendEntries.map((entry) => entry.label), [
      '0%',
      '100%',
    ]);
  });

  test('appearance states merge without losing base fields', () {
    const base = TreemapAppearance(
      color: Colors.blue,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    const selected = TreemapAppearance(
      border: BorderSide(color: Colors.amber, width: 2),
    );
    final resolved = base.merge(selected);
    expect(resolved.color, Colors.blue);
    expect(resolved.border, selected.border);
    expect(resolved.borderRadius, base.borderRadius);
  });

  testWidgets('a direct node Color bypasses color scale resolution', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final node = TreemapNode<String>(
      key: 'direct',
      weight: 1,
      color: Colors.indigo,
    );
    final details = TreemapNodeDetails<String>(
      geometry: TreemapGeometryNode(
        key: const TreemapKey.source('direct'),
        node: node,
        bounds: const TreemapBounds.fromLTWH(0, 0, 10, 10),
        weight: 1,
        depth: 1,
        kind: TreemapGeometryKind.source,
        label: null,
        parentKey: null,
        opacity: 1,
      ),
      path: const [],
    );
    final resolver = TreemapAppearanceResolver<String>(
      colorScale: TreemapColorScale.exact({
        Colors.indigo: Colors.red,
      }, fallback: Colors.black),
    );

    expect(resolver.resolve(context, details, const {}).color, Colors.indigo);
  });
}
