import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/sample_data.dart';
import 'support/golden_labels.dart';
import 'support/pump_app.dart';

void main() {
  test('example hierarchy assigns a distinct color to every leaf', () {
    const values = [
      'consumer/mobile',
      'consumer/web',
      'consumer/desktop',
      'business/small',
      'business/medium',
      'business/enterprise',
    ];
    final colors = values.map(sampleHierarchyColorScale.colorFor).toSet();

    expect(colors, hasLength(values.length));
  });

  testWidgets('example hierarchy palette visual contract', (tester) async {
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('example-palette'),
        child: TreemapChart<String>(
          root: sampleTree(),
          tiles: TreemapTiles(
            appearance: TreemapAppearanceResolver(
              colorScale: sampleHierarchyColorScale,
            ),
          ),
          layout: TreemapLayoutConfig(
            innerSpacing: 2,
            outerPadding: const TreemapInsets.all(8),
          ),
        ),
      ),
      surfaceSize: const Size(720, 420),
    );

    await expectLater(
      find.byKey(const ValueKey('example-palette')),
      matchesGoldenFile('goldens/example_hierarchy_palette.png'),
    );
  });

  testWidgets('example palette labels use deterministic text rendering', (
    tester,
  ) async {
    final appearance = TreemapAppearanceResolver<String>(
      colorScale: sampleHierarchyColorScale,
    );
    await tester.pumpTreemapApp(
      RepaintBoundary(
        key: const ValueKey('example-palette'),
        child: TreemapChart<String>(
          root: sampleTree(),
          tiles: TreemapTiles(appearance: appearance),
          labels: TreemapCanvasLabels(
            appearance: appearance,
            config: goldenLabelConfig<String>(),
          ),
          layout: TreemapLayoutConfig(
            innerSpacing: 2,
            outerPadding: const TreemapInsets.all(8),
          ),
        ),
      ),
      surfaceSize: const Size(720, 420),
    );

    await expectLater(
      find.byKey(const ValueKey('example-palette')),
      matchesGoldenFile('goldens/example_hierarchy_palette_labels.png'),
    );
  });
}
