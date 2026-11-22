import 'dart:io';

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_builders.dart';

void main() {
  test('production imports and exports do not depend on a design system', () {
    final designSystem = RegExp(
      r'''(?:import|export)\s+['"]package:(?:material_ui/|cupertino_ui/|flutter/(?:material|cupertino)\.dart|flutter/src/(?:material|cupertino)/)''',
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        expect(
          designSystem.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    }
    final dependencies = File('pubspec.yaml')
        .readAsStringSync()
        .split('\ndependencies:')
        .last
        .split('\ndev_dependencies:')
        .first;
    expect(dependencies, isNot(contains('material_ui')));
    expect(dependencies, isNot(contains('cupertino_ui')));
  });

  testWidgets('chart, navigation, legends and tooltips work in WidgetsApp', (
    tester,
  ) async {
    final tree = TreemapNormalizer.normalize(
      TreemapNode<String>(
        key: 'root',
        label: 'Root',
        children: [
          TreemapNode(
            key: 'group',
            label: 'Group',
            children: [
              TreemapNode(key: 'a', label: 'A', weight: 70),
              TreemapNode(key: 'b', label: 'B', weight: 30),
            ],
          ),
          TreemapNode(key: 'c', weight: 25),
        ],
      ),
    );
    final controller = TreemapController<String>()
      ..synchronize(tree)
      ..zoomTo('group');
    addTearDown(controller.dispose);
    final scale = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 100,
      colors: const [Color(0xFF445588), Color(0xFF99BBEE)],
      fallback: const Color(0xFF808080),
    );
    TreemapPresentationState<String>? output;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        builder: (context, child) => DefaultTextStyle(
          style: const TextStyle(fontSize: 14, color: Color(0xFF202020)),
          child: Column(
            children: [
              Expanded(
                child: TreemapChart<String>(
                  tree: tree,
                  controller: controller,
                  tiles: TreemapTiles(
                    appearance: TreemapAppearanceResolver(colorScale: scale),
                  ),
                  labels: TreemapCanvasLabels(),
                  surrounding: TreemapSurroundingGrid(
                    topStart: const TreemapBreadcrumbs<String>(
                      config: TreemapBreadcrumbsConfig(
                        itemBuilder: testBreadcrumbItem,
                      ),
                    ),
                    bottomCenter: TreemapLegend<String>(
                      scale: scale,
                      config: const TreemapLegendConfig.bar(
                        titleBuilder: testLegendTitle,
                        labelBuilder: testLegendLabel,
                        pointerBuilder: testLegendPointer,
                      ),
                    ),
                  ),
                  onPresentationChanged: (value) => output = value,
                ),
              ),
              TreemapLegendView<String>(
                scale: TreemapColorScale.exact(const {
                  1: Color(0xFF445588),
                }, fallback: const Color(0xFF808080)),
                config: const TreemapLegendConfig.discrete(
                  title: 'Categories',
                  titleBuilder: testLegendTitle,
                  labelBuilder: testLegendLabel,
                ),
              ),
              const TreemapTooltipContainer(child: Text('Tooltip content')),
              const TreemapLegendPointer(color: Color(0xFF123456)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(output!.targetSnapshot!.focusKey, const TreemapKey.source('group'));
    expect(find.text('Tooltip content'), findsOneWidget);
    expect(find.byType(TreemapLegendBar), findsOneWidget);
    await tester.tap(find.text('Root'));
    await tester.pumpAndSettle();
    expect(controller.focusKey, const TreemapKey.source('root'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pointer requires a color and preserves explicit text overrides',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TreemapLegendPointer(
            color: Color(0xFF112233),
            textStyle: TextStyle(color: Color(0xFF445566)),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('▼')).style!.color,
        const Color(0xFF445566),
      );
    },
  );
}
