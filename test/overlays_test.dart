import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapNode<String> _manyNodes(int count) => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    for (var index = 0; index < count; index++)
      TreemapNode(
        key: 'node-$index',
        label: 'A long localized label $index',
        weight: index + 1,
      ),
  ],
);

TreemapNodeDetails<String> _tooltipDetails(TreemapBounds bounds) {
  final node = TreemapNode(key: 'leaf', label: 'Leaf', weight: 1);
  return TreemapNodeDetails(
    geometry: TreemapGeometryNode(
      key: const TreemapKey.source('leaf'),
      node: node,
      bounds: bounds,
      weight: 1,
      depth: 1,
      kind: TreemapGeometryKind.source,
      label: 'Leaf',
      parentKey: const TreemapKey.source('root'),
      opacity: 1,
    ),
    path: const [],
  );
}

Widget _testBreadcrumbItem(
  BuildContext context,
  TreemapPathEntry<String> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => TextButton(
  onPressed: onPressed,
  child: Text(
    '${entry.label}:${isCurrent ? 'current' : 'ancestor'}',
    key: const ValueKey('custom-breadcrumb-item'),
  ),
);

Widget _testBreadcrumbSeparator(BuildContext context) =>
    const Text('>', key: ValueKey('custom-breadcrumb-separator'));

Widget _testBreadcrumbOverflowIndicator(BuildContext context) =>
    const Text('more', key: ValueKey('custom-breadcrumb-overflow-indicator'));

Widget _testBreadcrumbWrapper(BuildContext context, Widget child) => ColoredBox(
  key: const ValueKey('custom-breadcrumb-wrapper'),
  color: Colors.transparent,
  child: child,
);

Widget _testLegendTitle(BuildContext context, String title) =>
    Text('T:$title', key: const ValueKey('custom-legend-title'));

Widget _testLegendLabel(BuildContext context, TreemapLegendEntry entry) => Text(
  'L:${entry.label}',
  key: ValueKey('custom-legend-label-${entry.label}'),
);

Widget _testLegendItem(
  BuildContext context,
  TreemapLegendEntry entry,
  Widget label,
) => ColoredBox(
  key: ValueKey('custom-legend-item-${entry.label}'),
  color: entry.color,
  child: label,
);

Widget _testLegendBar(
  BuildContext context,
  List<Color> colors,
  Axis direction,
) => ColoredBox(key: const ValueKey('custom-legend-bar'), color: colors.first);

Widget _testLegendPointer(BuildContext context, Color color, double fraction) =>
    Text(
      '${(fraction * 100).round()}%',
      key: const ValueKey('custom-legend-pointer'),
    );

Widget _testLegendWrapper(BuildContext context, Widget child) => ColoredBox(
  key: const ValueKey('custom-legend-wrapper'),
  color: Colors.transparent,
  child: child,
);

Widget _bareTooltipContainer(BuildContext context, Widget child) => child;

Widget _testTooltipContainer(BuildContext context, Widget child) => ColoredBox(
  key: const ValueKey('custom-tooltip-container'),
  color: Colors.black,
  child: child,
);

void main() {
  const target = TreemapBounds.fromLTWH(140, 100, 80, 60);
  const expectedPositions = {
    TreemapTooltipPlacement.auto: Offset(150, 60),
    TreemapTooltipPlacement.above: Offset(150, 60),
    TreemapTooltipPlacement.below: Offset(150, 170),
    TreemapTooltipPlacement.left: Offset(70, 115),
    TreemapTooltipPlacement.right: Offset(230, 115),
  };

  test('canvas label ellipsis is configurable and copied', () {
    const config = TreemapLabelConfig<String>();

    expect(config.ellipsis, '...');
    final changed = config.copyWith(
      ellipsis: '~~~',
      fallbackTitle: 'Unnamed',
      weightFractionDigits: 4,
      titleStyle: const TextStyle(fontSize: 15),
      valueStyle: const TextStyle(fontSize: 9),
      valueColorOpacity: .5,
      colorResolver: (_) => Colors.pink,
    );
    expect(changed.ellipsis, '~~~');
    expect(changed.fallbackTitle, 'Unnamed');
    expect(changed.weightFractionDigits, 4);
    expect(changed.titleStyle.fontSize, 15);
    expect(changed.valueStyle.fontSize, 9);
    expect(changed.valueColorOpacity, .5);
    expect(changed.colorResolver(const TreemapAppearance()), Colors.pink);

    final customLines = changed.copyWith(
      linesBuilder: (details, appearance, locale) => const [
        TreemapCanvasLabelLine(
          text: 'Custom line',
          style: TextStyle(fontSize: 8),
        ),
      ],
    );
    expect(
      customLines
          .resolveLines(
            _tooltipDetails(target),
            const TreemapAppearance(color: Colors.blue),
            null,
          )
          .single
          .text,
      'Custom line',
    );
  });

  test('breadcrumb and legend builders are configurable and copied', () {
    const breadcrumbs = TreemapBreadcrumbsConfig<String>(
      itemBuilder: _testBreadcrumbItem,
      separatorBuilder: _testBreadcrumbSeparator,
      wrapperBuilder: _testBreadcrumbWrapper,
      ellipsisMaximumChildren: 3,
      overflowIndicatorBuilder: _testBreadcrumbOverflowIndicator,
    );
    final changedBreadcrumbs = breadcrumbs.copyWith(ellipsisMaximumChildren: 2);
    expect(breadcrumbs.position, TreemapOverlayPosition.topCenter);
    expect(changedBreadcrumbs.itemBuilder, same(_testBreadcrumbItem));
    expect(changedBreadcrumbs.separatorBuilder, same(_testBreadcrumbSeparator));
    expect(changedBreadcrumbs.wrapperBuilder, same(_testBreadcrumbWrapper));
    expect(changedBreadcrumbs.ellipsisMaximumChildren, 2);
    expect(
      changedBreadcrumbs.overflowIndicatorBuilder,
      same(_testBreadcrumbOverflowIndicator),
    );

    const discrete = TreemapLegendConfig.discrete(
      runSpacing: 9,
      wrapperBuilder: _testLegendWrapper,
      titleBuilder: _testLegendTitle,
      labelBuilder: _testLegendLabel,
      itemBuilder: _testLegendItem,
      semanticsLabel: 'Categories',
    );
    expect(discrete.position, TreemapOverlayPosition.bottomCenter);
    expect(discrete.copyWith(runSpacing: 10).runSpacing, 10);
    expect(discrete.runSpacing, 9);
    expect(discrete.wrapperBuilder, same(_testLegendWrapper));
    expect(discrete.titleBuilder, same(_testLegendTitle));
    expect(discrete.labelBuilder, same(_testLegendLabel));
    expect(discrete.itemBuilder, same(_testLegendItem));
    expect(discrete.semanticsLabel, 'Categories');

    const bar = TreemapLegendConfig.bar(
      horizontalBarSize: Size(210, 14),
      verticalBarSize: Size(14, 130),
      wrapperBuilder: _testLegendWrapper,
      barBuilder: _testLegendBar,
      pointerBuilder: _testLegendPointer,
      pointerExtent: 14,
      horizontalPointerOffset: 12,
      verticalPointerOffset: 13,
      showLabels: false,
      sampleCount: 12,
    );
    expect(bar.position, TreemapOverlayPosition.bottomCenter);
    expect(bar.copyWith(sampleCount: 16).sampleCount, 16);
    expect(bar.horizontalBarSize, const Size(210, 14));
    expect(bar.verticalBarSize, const Size(14, 130));
    expect(bar.wrapperBuilder, same(_testLegendWrapper));
    expect(bar.barBuilder, same(_testLegendBar));
    expect(bar.pointerBuilder, same(_testLegendPointer));
    expect(bar.pointerExtent, 14);
    expect(bar.horizontalPointerOffset, 12);
    expect(bar.verticalPointerOffset, 13);
    expect(bar.showLabels, isFalse);
  });

  testWidgets('default builders compose configurable standard widgets', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    controller
      ..synchronize(
        TreemapNode(
          key: 'root',
          label: 'Root',
          children: [
            TreemapNode(
              key: 'group',
              label: 'Group',
              children: [TreemapNode(key: 'leaf', weight: 1)],
            ),
          ],
        ),
      )
      ..zoomTo('group')
      ..setHovered(const TreemapKey.source('leaf'), color: 1);
    addTearDown(controller.dispose);
    final scale = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 2,
      colors: const [Colors.blue, Colors.red],
      fallback: Colors.grey,
    );

    await tester.pumpTreemapApp(
      Column(
        children: [
          TreemapBreadcrumbsView<String>(controller: controller),
          TreemapLegendView<String>(
            scale: TreemapColorScale.exact(const {
              1: Colors.blue,
            }, fallback: Colors.grey),
            config: const TreemapLegendConfig.discrete(),
          ),
          TreemapLegendView<String>(
            scale: scale,
            controller: controller,
            config: const TreemapLegendConfig.bar(showLabels: false),
          ),
          SizedBox(
            width: 300,
            height: 200,
            child: Stack(
              children: [
                TreemapTooltipView<String>(
                  details: _tooltipDetails(
                    const TreemapBounds.fromLTWH(20, 20, 80, 60),
                  ),
                  config: const TreemapTooltipConfig(),
                  builder: (context, details) => const Text('tooltip'),
                ),
              ],
            ),
          ),
        ],
      ),
      surfaceSize: const Size(600, 500),
    );

    expect(find.byType(TreemapBreadcrumbItem), findsNWidgets(2));
    expect(find.byType(TreemapBreadcrumbSeparator), findsOneWidget);
    expect(find.byType(TreemapLegendItem), findsOneWidget);
    expect(find.byType(TreemapLegendBar), findsOneWidget);
    expect(find.byType(TreemapLegendPointer), findsOneWidget);
    expect(find.byType(TreemapTooltipContainer), findsOneWidget);
    expect(find.byType(TreemapOverlayContainer), findsNWidgets(3));
  });

  testWidgets('overlay builders replace complete visual widgets', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    controller
      ..synchronize(
        TreemapNode(
          key: 'root',
          label: 'Root',
          children: [
            TreemapNode(
              key: 'group',
              label: 'Group',
              children: [TreemapNode(key: 'leaf', weight: 1)],
            ),
          ],
        ),
      )
      ..zoomTo('group')
      ..setHovered(const TreemapKey.source('node-0'), color: 1);
    addTearDown(controller.dispose);
    final scale = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 2,
      colors: const [Colors.blue, Colors.red],
      fallback: Colors.grey,
    );

    await tester.pumpTreemapApp(
      Column(
        children: [
          TreemapBreadcrumbsView<String>(
            controller: controller,
            config: const TreemapBreadcrumbsConfig(
              itemBuilder: _testBreadcrumbItem,
              separatorBuilder: _testBreadcrumbSeparator,
              wrapperBuilder: _testBreadcrumbWrapper,
              overflow: TreemapOverflowMode.ellipsis,
              ellipsisMaximumChildren: 2,
              overflowIndicatorBuilder: _testBreadcrumbOverflowIndicator,
            ),
          ),
          TreemapLegendView<String>(
            scale: TreemapColorScale.exact(
              const {1: Colors.blue},
              fallback: Colors.grey,
              labels: const {1: 'one'},
            ),
            config: const TreemapLegendConfig.discrete(
              wrapperBuilder: _testLegendWrapper,
              labelBuilder: _testLegendLabel,
              itemBuilder: _testLegendItem,
            ),
          ),
          TreemapLegendView<String>(
            scale: scale,
            controller: controller,
            config: const TreemapLegendConfig.bar(
              title: 'Scale',
              titleBuilder: _testLegendTitle,
              labelBuilder: _testLegendLabel,
              barBuilder: _testLegendBar,
              pointerBuilder: _testLegendPointer,
              showLabels: false,
            ),
          ),
          SizedBox(
            width: 300,
            height: 200,
            child: Stack(
              children: [
                TreemapTooltipView<String>(
                  details: _tooltipDetails(
                    const TreemapBounds.fromLTWH(20, 20, 80, 60),
                  ),
                  config: const TreemapTooltipConfig(
                    containerBuilder: _testTooltipContainer,
                  ),
                  builder: (context, details) => const Text('tooltip'),
                ),
              ],
            ),
          ),
        ],
      ),
      surfaceSize: const Size(600, 500),
    );

    expect(
      find.byKey(const ValueKey('custom-breadcrumb-item')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-breadcrumb-separator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-breadcrumb-overflow-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-breadcrumb-wrapper')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('custom-legend-wrapper')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-legend-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-legend-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-legend-pointer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('custom-legend-label-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-legend-item-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-tooltip-container')),
      findsOneWidget,
    );
  });

  testWidgets('ordinary canvas labels do not require Localizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 200,
            child: TreemapChart<String>(
              root: _manyNodes(3),
              tiles: testTreemapTiles(),
              labels: testTreemapLabels(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('localized canvas labels require Localizations', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 200,
            child: TreemapChart<String>(
              root: _manyNodes(3),
              tiles: testTreemapTiles(),
              labels: testTreemapLabels(
                config: TreemapLabelConfig(
                  localizedValueFormatter: (details, locale) =>
                      '${locale.languageCode}:${details.weight}',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('requires a Localizations ancestor'),
      ),
    );
  });

  for (final textDirection in TextDirection.values) {
    for (final entry in expectedPositions.entries) {
      testWidgets(
        'tooltip ${entry.key.name} is sized and positioned from its target '
        'in ${textDirection.name}',
        (tester) async {
          await tester.pumpTreemapApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: const ValueKey('tooltip-area'),
                width: 500,
                height: 400,
                child: Stack(
                  children: [
                    TreemapTooltipView<String>(
                      details: _tooltipDetails(target),
                      config: TreemapTooltipConfig(
                        placement: entry.key,
                        margin: 10,
                        maxWidth: 100,
                        containerBuilder: _bareTooltipContainer,
                      ),
                      builder: (context, details) => const SizedBox(
                        key: ValueKey('tooltip-content'),
                        width: 60,
                        height: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            surfaceSize: const Size(600, 500),
            textDirection: textDirection,
          );

          final areaOrigin = tester.getTopLeft(
            find.byKey(const ValueKey('tooltip-area')),
          );
          final tooltip = find.byKey(const ValueKey('tooltip-content'));
          final tooltipOffset = tester.getTopLeft(tooltip) - areaOrigin;

          expect(tester.getSize(tooltip), const Size(60, 30));
          expect(tooltipOffset.dx, closeTo(entry.value.dx, .001));
          expect(tooltipOffset.dy, closeTo(entry.value.dy, .001));
        },
      );
    }
  }

  testWidgets('widget labels use a bounded largest-node working set', (
    tester,
  ) async {
    await tester.pumpTreemapApp(
      SizedBox(
        width: 500,
        height: 300,
        child: TreemapChart<String>(
          root: _manyNodes(20),
          tiles: testTreemapTiles(),
          labels: TreemapWidgetLabels(
            maximumNodes: 3,
            ignorePointer: true,
            builder: (context, details, states) => SizedBox(
              key: ValueKey('overlay-${details.key}'),
              child: Text(details.label ?? ''),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('overlay-TreemapKey.source(node-19)')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('overlay-TreemapKey.source(node-0)')),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('overlay-'),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('label content does not alter layout geometry', (tester) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      SizedBox(
        width: 180,
        height: 80,
        child: TreemapChart<String>(
          root: _manyNodes(12),
          tiles: testTreemapTiles(),
          layout: TreemapLayoutConfig(
            minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
          ),
          labels: testTreemapLabels(
            config: TreemapLabelConfig(
              ellipsis: '...',
              localizedValueFormatter: (details, locale) =>
                  '${locale.languageCode}:${details.weight}',
            ),
          ),
          onSnapshot: (value) => snapshot = value,
        ),
      ),
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(1.4),
    );
    expect(snapshot!.nodes.any((node) => node.isAggregate), isFalse);
    expect(snapshot!.visibleNodes, hasLength(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('breadcrumbs and legends support all eight positions', (
    tester,
  ) async {
    for (final position in TreemapOverlayPosition.values) {
      final scale = TreemapColorScale.interpolated(
        minimum: 1,
        maximum: 5,
        colors: const [Colors.blue, Colors.red],
        fallback: Colors.grey,
      );
      await tester.pumpTreemapApp(
        SizedBox(
          width: 720,
          height: 320,
          child: TreemapChart<String>(
            root: _manyNodes(5),
            tiles: testTreemapTiles(colorScale: scale),
            labels: testTreemapLabels(colorScale: scale),
            surrounding: TreemapBreadcrumbs(
              config: TreemapBreadcrumbsConfig(position: position),
            ),
          ),
        ),
      );
      expect(find.byType(TreemapBreadcrumbsView<String>), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'breadcrumbs: $position');

      await tester.pumpTreemapApp(
        SizedBox(
          width: 720,
          height: 320,
          child: TreemapChart<String>(
            root: _manyNodes(5),
            tiles: testTreemapTiles(colorScale: scale),
            labels: testTreemapLabels(colorScale: scale),
            surrounding: TreemapLegend(
              scale: scale,
              config: TreemapLegendConfig.bar(position: position),
            ),
          ),
        ),
      );
      expect(find.byType(TreemapLegendView<String>), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'legend: $position');
    }
  });
}
