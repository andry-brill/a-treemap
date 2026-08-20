import 'dart:math' as math;

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../scenario.dart';

const _builderNodeCount = 120;
const _maximumBuilderNodes = 80;
const _builderNormalNodeCount = 79;

const _screenshotWeights = <double>[28, 24, 20, 18, 16, 14, 12, 10];

const _screenshotTinyWeight = .9;

const _screenshotBluePalette = <Color>[
  Color(0xFF0B63F6),
  Color(0xE00B63F6),
  Color(0xC20B63F6),
  Color(0xA30B63F6),
  Color(0x850B63F6),
  Color(0x660B63F6),
  Color(0x4D0B63F6),
  Color(0x330B63F6),
];
const _screenshotPinkPalette = <Color>[
  Color(0xFFEC168C),
  Color(0xE0EC168C),
  Color(0xC2EC168C),
  Color(0xA3EC168C),
  Color(0x85EC168C),
  Color(0x66EC168C),
  Color(0x4DEC168C),
  Color(0x33EC168C),
];

String _screenshotOpacityLabel(double value) =>
    '${(100 - value * 80).round()}%';

final _screenshotBlueScale = TreemapColorScale.interpolated(
  minimum: 0,
  maximum: 1,
  colors: _screenshotBluePalette,
  fallback: _screenshotBluePalette.last,
  labelFormatter: _screenshotOpacityLabel,
);

final _screenshotPinkScale = TreemapColorScale.interpolated(
  minimum: 0,
  maximum: 1,
  colors: _screenshotPinkPalette,
  fallback: _screenshotPinkPalette.last,
  labelFormatter: _screenshotOpacityLabel,
);

TreemapNode<String> _builderTree() => TreemapNode(
  key: 'root',
  label: 'Virtualized items',
  children: [
    for (var index = 0; index < _builderNodeCount; index++)
      TreemapNode(
        key: 'item-$index',
        label: 'Item $index',
        weight: index < _builderNormalNodeCount
            ? (8 + index % 4).toDouble()
            : .08,
        color: index.toDouble(),
      ),
  ],
);

TreemapNode<String> _screenshotGroup(
  String key,
  String label,
  List<Color> palette,
) => TreemapNode(
  key: key,
  label: label,
  color: Colors.transparent,
  children: [
    for (var index = 0; index < 16; index++)
      TreemapNode(
        key: '$key-item-$index',
        label: '$label ${index + 1}',
        weight: index < _screenshotWeights.length
            ? _screenshotWeights[index]
            : _screenshotTinyWeight,
        color: palette[index % palette.length],
      ),
  ],
);

TreemapNode<String> _screenshotTree() => TreemapNode(
  key: 'screenshot-root',
  label: 'Level 2',
  children: [
    _screenshotGroup('screenshot-blue', 'Blue', _screenshotBluePalette),
    _screenshotGroup('screenshot-pink', 'Pink', _screenshotPinkPalette),
  ],
);

TreemapNode<String> _screenshotNavigationTree() => TreemapNode(
  key: 'screenshot-navigation-root',
  label: 'Level 1',
  children: [_screenshotTree()],
);

TreemapNode<String> _screenshotOverviewTree() => TreemapNode(
  key: 'screenshot-overview-root',
  label: 'Level 1',
  children: [
    TreemapNode(
      key: 'screenshot-overview-entry',
      label: 'Level 2',
      weight: 1,
      color: _screenshotBluePalette.first,
    ),
  ],
);

Widget _categoryLegendTitle(BuildContext context, String title) => Text(
  title,
  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
);

Widget _compactLegendLabel(BuildContext context, TreemapLegendEntry entry) =>
    Text(entry.label, style: const TextStyle(fontSize: 11));

Widget _roundedLegendItem(
  BuildContext context,
  TreemapLegendEntry entry,
  Widget label,
) => TreemapLegendItem(
  color: entry.color,
  label: label,
  swatchSize: 16,
  spacing: 6,
  swatchBorderRadius: const BorderRadius.all(Radius.circular(4)),
);

Widget _categoryLegendWrapper(BuildContext context, Widget child) =>
    TreemapOverlayContainer(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      padding: const EdgeInsets.all(10),
      child: child,
    );

Widget _numericLegendTitle(BuildContext context, String title) => Text(
  title,
  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
);

Widget _numericLegendLabel(BuildContext context, TreemapLegendEntry entry) =>
    Text(entry.label, style: const TextStyle(fontSize: 10));

Widget _roundedLegendBar(
  BuildContext context,
  List<Color> colors,
  Axis direction,
) => TreemapLegendBar(
  colors: colors,
  direction: direction,
  borderRadius: const BorderRadius.all(Radius.circular(7)),
);

Widget _textLegendPointer(BuildContext context, Color color, double fraction) =>
    TreemapLegendPointer(color: color);

TreemapChart<String> _scaled(
  TreemapColorScale scale, {
  TreemapLegendConfig? legendConfig,
}) => TreemapChart<String>(
  root: sampleTree(numericColors: true),
  tiles: sampleTiles(colorScale: scale),
  labels: sampleLabels(colorScale: scale),
  surrounding: TreemapLegend(
    scale: scale,
    config:
        legendConfig ??
        (scale.isContinuous
            ? const TreemapLegendConfig.bar(title: 'Value')
            : const TreemapLegendConfig.discrete(title: 'Value')),
  ),
  layout: TreemapLayoutConfig(innerSpacing: 3),
);

final appearanceScenarios = <ExampleScenario>[
  ExampleScenario(
    id: 'appearance-direct-node-colors',
    title: 'Direct node colors',
    category: 'Color scales',
    description:
        'Assigns Colors.indigo, Colors.teal, and Colors.deepPurple directly to three leaves with weights 50, 30, and 20. The configured exact scale deliberately maps those Color objects to red, orange, and yellow, but the tiles retain their assigned colors because Color inputs bypass scale resolution.',
    builder: (_) {
      final scale = TreemapColorScale.exact({
        Colors.indigo: Colors.red,
        Colors.teal: Colors.orange,
        Colors.deepPurple: Colors.yellow,
      }, fallback: Colors.grey);
      final root = TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(
            key: 'direct-indigo',
            label: 'Direct indigo',
            weight: 50,
            color: Colors.indigo,
          ),
          TreemapNode(
            key: 'direct-teal',
            label: 'Direct teal',
            weight: 30,
            color: Colors.teal,
          ),
          TreemapNode(
            key: 'direct-purple',
            label: 'Direct purple',
            weight: 20,
            color: Colors.deepPurple,
          ),
        ],
      );
      return TreemapChart<String>(
        root: root,
        tiles: sampleTiles(colorScale: scale),
        labels: sampleLabels(colorScale: scale),
        layout: TreemapLayoutConfig(innerSpacing: 3),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-exact-scale',
    title: 'Exact color scale',
    category: 'Color scales',
    description:
        'Maps exact values to colors: Consumer/Business branches use indigo/teal, while leaf weights 55, 30, 15, 38, 24, and 18 map to purple, blue, orange, green, cyan, and red. The discrete legend uses that same domain.',
    builder: (_) => _scaled(
      TreemapColorScale.exact({
        'consumer': Colors.indigo,
        'business': Colors.teal,
        55: Colors.purple,
        30: Colors.blue,
        15: Colors.orange,
        38: Colors.green,
        24: Colors.cyan,
        18: Colors.red,
      }, fallback: Colors.grey),
    ),
  ),
  ExampleScenario(
    id: 'appearance-categorical-scale',
    title: 'Categorical color scale',
    category: 'Color scales',
    description:
        'Hashes the Consumer, Business, and six leaf color values into a repeatable four-color palette: indigo, teal, orange, and pink. Thin builders configure TreemapLegendItem and TreemapOverlayContainer to show 16 px rounded swatches, 6 px label gaps, 10 px wrap spacing and padding, a rounded theme-aware background, compact type, and the “Category color legend” semantics label. $sampleHierarchyDescription',
    builder: (_) {
      final scale = TreemapColorScale.categorical(
        const [Colors.indigo, Colors.teal, Colors.orange, Colors.pink],
        labels: const ['A', 'B', 'C', 'D'],
        fallback: Colors.grey,
      );
      return _scaled(
        scale,
        legendConfig: const TreemapLegendConfig.discrete(
          title: 'Value',
          runSpacing: 10,
          wrapperBuilder: _categoryLegendWrapper,
          titleBuilder: _categoryLegendTitle,
          labelBuilder: _compactLegendLabel,
          itemBuilder: _roundedLegendItem,
          semanticsLabel: 'Category color legend',
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-range-scale',
    title: 'Numeric range scale',
    category: 'Color scales',
    description:
        'Classifies the six leaf values into blue Small (0–20), orange Medium (20–40), and red Large (40–60) ranges. Thus Desktop 15 and Enterprise 18 are Small, while Mobile 55 is Large; the legend shows all three intervals.',
    builder: (_) => _scaled(
      TreemapColorScale.numericRange(const [
        TreemapNumericColorRange(
          minimum: 0,
          maximum: 20,
          color: Colors.blue,
          label: 'Small',
        ),
        TreemapNumericColorRange(
          minimum: 20,
          maximum: 40,
          color: Colors.orange,
          label: 'Medium',
        ),
        TreemapNumericColorRange(
          minimum: 40,
          maximum: 60,
          color: Colors.red,
          label: 'Large',
        ),
      ], fallback: Colors.grey),
    ),
  ),
  ExampleScenario(
    id: 'appearance-interpolated-scale',
    title: 'Interpolated scale and bar',
    category: 'Color scales',
    description:
        'Interpolates every numeric leaf value over a 0–60 domain from blue through amber to red. Mobile 55 appears near red while Desktop 15 stays blue-side. The legend formats stops as “0 units”, samples 24 colors, and uses thin builders to configure TreemapLegendBar and TreemapLegendPointer for its rounded 200×14 px bar and value marker.',
    builder: (_) {
      final scale = TreemapColorScale.interpolated(
        minimum: 0,
        maximum: 60,
        colors: const [Colors.blue, Colors.amber, Colors.red],
        fallback: Colors.grey,
        labelFormatter: (value) => '${value.round()} units',
      );
      return _scaled(
        scale,
        legendConfig: const TreemapLegendConfig.bar(
          title: 'Value',
          horizontalBarSize: Size(200, 14),
          verticalBarSize: Size(14, 140),
          titleBuilder: _numericLegendTitle,
          labelBuilder: _numericLegendLabel,
          barBuilder: _roundedLegendBar,
          pointerBuilder: _textLegendPointer,
          pointerExtent: 14,
          horizontalPointerOffset: 14,
          verticalPointerOffset: 14,
          sampleCount: 24,
          semanticsLabel: 'Numeric color legend',
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-saturation-scale',
    title: 'Saturation scale',
    category: 'Color scales',
    description:
        'Maps values from 0 through 60 by changing the saturation of one indigo hue. The six sample weights range from Desktop 15 to Mobile 55, so area remains weight-driven while color intensity independently communicates magnitude.',
    builder: (_) => _scaled(
      TreemapColorScale.saturation(
        minimum: 0,
        maximum: 60,
        color: Colors.indigo,
        fallback: Colors.grey,
      ),
    ),
  ),
  ExampleScenario(
    id: 'appearance-gradients-states',
    title: 'Gradients, borders, hover, selection',
    category: 'Appearance',
    description:
        'Uses TreemapTiles and optimized TreemapCanvasLabels with an explicit hierarchy color scale. Long titles such as “Mobile channel performance” use a configured 13 px bold title, 10 px value at 70% opacity, white color resolver, “Unnamed channel” fallback, two fractional weight digits, and ASCII "..." ellipsis. Every tile has a 10 px corner radius and translucent border; click a leaf to compare the normal and selected gradients.',
    builder: (_) {
      final style = TreemapStyle(
        tileAppearance: const TreemapAppearance(
          border: BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      );
      TreemapAppearance resolver(context, details, states) => TreemapAppearance(
        gradient: LinearGradient(
          colors: states.contains(TreemapVisualState.selected)
              ? const [Colors.amber, Colors.deepOrange]
              : const [Colors.indigo, Colors.teal],
        ),
      );
      final labelDefaults = TreemapLabelConfig<String>(
        titleFormatter: (details) =>
            '${details.label ?? details.key.sourceKey} channel performance',
        fallbackTitle: 'Unnamed channel',
        weightFractionDigits: 2,
        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        valueStyle: const TextStyle(fontSize: 10),
        valueColorOpacity: .7,
        colorResolver: (_) => Colors.white,
        ellipsis: '...',
      );
      return TreemapChart<String>(
        root: sampleTree(),
        tiles: sampleTiles(style: style, nodeStyleResolver: resolver),
        labels: sampleLabels(
          style: style,
          nodeStyleResolver: resolver,
          config: labelDefaults.copyWith(
            linesBuilder: (details, appearance, locale) => [
              ...labelDefaults.resolveLines(details, appearance, locale),
              TreemapCanvasLabelLine(
                text: 'Depth ${details.depth}',
                style: const TextStyle(fontSize: 9, color: Colors.white70),
              ),
            ],
          ),
        ),
        interaction: const TreemapInteractionConfig(
          selectOnNodeTap: true,
          zoomOnNodeTap: false,
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-screenshot',
    title: 'Screenshot',
    category: 'Appearance',
    description:
        'Fits the complete breadcrumb, paired legends, and treemap into the largest available square with TreemapSurroundingGrid.fromMap. An external-controller breadcrumb occupies topStart and two legends occupy topEnd; their own 56 px SizedBoxes set the natural top-row height, while the absent middle side cells let the treemap span the full width. Level 1 opens a single-tile overview and Level 2 returns to two transparent blue and pink groups. Each group has eight weighted tiles plus eight siblings weighted 0.9 that aggregate into a readable Other block. The chart uses no outer layout padding, 8 px level padding, 16 px inner spacing and rounded corners, a 72 px minimum width, and black labels over opacity ramps from 100% to 20%.',
    builder: (_) => const _ScreenshotExample(),
  ),
  ExampleScenario(
    id: 'appearance-builders-virtualized',
    title: 'Tile and label builders',
    category: 'Builders',
    description:
        'Composes the canvas tile layer with TreemapBuilderTileLayer, then uses clipped TreemapWidgetLabels containing an icon and text. Of 120 leaves, 79 cycle through weights 8–11 and 41 deliberately tiny leaves weigh 0.08; colors interpolate by index 0–119. Both widget layers are capped at 80 blocks. Layout minimumWidth 54 and minimumHeight 24 combine the tiny siblings into one weight-faithful Other block close to the configured minimum size.',
    builder: (_) {
      final scale = manyNodeColorScale(_builderNodeCount);
      return TreemapChart<String>(
        root: _builderTree(),
        layout: TreemapLayoutConfig(
          minimumWidth: 54,
          minimumHeight: 24,
          minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
        ),
        tiles: TreemapCompositeTileLayer([
          sampleTiles(colorScale: scale),
          TreemapBuilderTileLayer(
            maximumNodes: _maximumBuilderNodes,
            ignorePointer: true,
            builder: (context, details, states) => DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
        ]),
        labels: TreemapWidgetLabels(
          maximumNodes: _maximumBuilderNodes,
          ignorePointer: true,
          builder: (context, details, states) =>
              _VirtualizedNodeLabel(details: details),
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-discrete-legend',
    title: 'Discrete legend and custom item',
    category: 'Legends',
    description:
        'Places a vertical discrete legend at middle-start for the Consumer and Business categories. Each entry is a custom Material Chip with a colored CircleAvatar; the chart still uses the six sample weights 55, 30, 15, 38, 24, and 18.',
    builder: (_) {
      final scale = TreemapColorScale.categorical(
        const [Colors.indigo, Colors.teal],
        labels: const ['Consumer', 'Business'],
        fallback: Colors.grey,
      );
      return TreemapChart<String>(
        root: sampleTree(),
        tiles: sampleTiles(colorScale: scale),
        labels: sampleLabels(colorScale: scale),
        surrounding: TreemapLegend(
          scale: scale,
          config: TreemapLegendConfig.discrete(
            position: TreemapOverlayPosition.middleStart,
            direction: Axis.vertical,
            itemBuilder: (context, entry, label) => Chip(
              avatar: CircleAvatar(backgroundColor: entry.color),
              label: label,
            ),
          ),
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'appearance-bar-legend',
    title: 'Segmented bar legend and pointer',
    category: 'Legends',
    description:
        'Places a vertical segmented bar at middle-end for a 0–60 blue-yellow-red scale. Hover a leaf such as Mobile 55 or Enterprise 18 to move the custom arrow pointer to that value’s normalized position.',
    builder: (_) {
      final scale = TreemapColorScale.interpolated(
        minimum: 0,
        maximum: 60,
        colors: const [Colors.blue, Colors.yellow, Colors.red],
        fallback: Colors.grey,
      );
      return TreemapChart<String>(
        root: sampleTree(numericColors: true),
        tiles: sampleTiles(colorScale: scale),
        labels: sampleLabels(colorScale: scale),
        surrounding: TreemapLegend(
          scale: scale,
          config: TreemapLegendConfig.bar(
            position: TreemapOverlayPosition.middleEnd,
            direction: Axis.vertical,
            segmented: true,
            pointerBuilder: (context, color, fraction) =>
                Icon(Icons.arrow_right, color: color),
          ),
        ),
      );
    },
  ),
];

final class _VirtualizedNodeLabel extends StatelessWidget {
  const _VirtualizedNodeLabel({required this.details});

  final TreemapNodeDetails<String> details;

  @override
  Widget build(BuildContext context) {
    final label =
        details.label ??
        details.key.sourceKey?.toString() ??
        'Other (${details.aggregateMembers.length})';
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_outlined, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _screenshotChromeWrapper(BuildContext context, Widget child) =>
    TreemapOverlayContainer(child: child);

Widget _screenshotBreadcrumbItem(
  BuildContext context,
  TreemapPathEntry<String> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => _ScreenshotBreadcrumbItem(
  entry: entry,
  isCurrent: isCurrent,
  onPressed: onPressed,
);

Widget _screenshotLegendLabel(BuildContext context, TreemapLegendEntry entry) =>
    Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        entry.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1),
      ),
    );

Widget _screenshotLegendBar(
  BuildContext context,
  List<Color> colors,
  Axis direction,
) => TreemapLegendBar(
  colors: colors,
  direction: direction,
  borderRadius: const BorderRadius.all(Radius.circular(5)),
);

final class _ScreenshotBreadcrumbItem extends StatelessWidget {
  const _ScreenshotBreadcrumbItem({
    required this.entry,
    required this.isCurrent,
    required this.onPressed,
  });

  final TreemapPathEntry<String> entry;
  final bool isCurrent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TreemapBreadcrumbItem(
    label: entry.label ?? entry.key.sourceKey?.toString() ?? 'Other',
    isCurrent: isCurrent,
    onPressed: onPressed,
    indicatorWidth: 0,
    indicatorColor: Colors.transparent,
    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isCurrent ? _screenshotBluePalette.first : null,
      fontWeight: isCurrent ? FontWeight.bold : null,
    ),
  );
}

final class _ScreenshotLegends extends StatelessWidget {
  const _ScreenshotLegends();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _ScreenshotScaleLegend(title: 'Blue', scale: _screenshotBlueScale),
      const SizedBox(width: 16),
      _ScreenshotScaleLegend(title: 'Pink', scale: _screenshotPinkScale),
    ],
  );
}

final class _ScreenshotScaleLegend extends StatelessWidget {
  const _ScreenshotScaleLegend({required this.title, required this.scale});

  final String title;
  final TreemapColorScale scale;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      TreemapLegendView<String>(
        scale: scale,
        config: TreemapLegendConfig.bar(
          horizontalBarSize: const Size(96, 8),
          sampleCount: 24,
          labelBuilder: _screenshotLegendLabel,
          barBuilder: _screenshotLegendBar,
          wrapperBuilder: _screenshotChromeWrapper,
          semanticsLabel: '$title opacity scale',
        ),
      ),
    ],
  );
}

final class _ScreenshotExample extends StatefulWidget {
  const _ScreenshotExample();

  @override
  State<_ScreenshotExample> createState() => _ScreenshotExampleState();
}

final class _ScreenshotExampleState extends State<_ScreenshotExample> {
  late final TreemapController<String> _navigationController;

  bool get _showsScreenshot =>
      _navigationController.focusKey?.sourceKey == 'screenshot-root';

  @override
  void initState() {
    super.initState();
    _navigationController = TreemapController<String>()
      ..synchronize(_screenshotNavigationTree())
      ..zoomTo('screenshot-root')
      ..addListener(_handleNavigationChanged);
  }

  void _handleNavigationChanged() {
    if (mounted) setState(() {});
  }

  void _openScreenshot(TreemapNodeDetails<String> details) {
    if (details.key.sourceKey == 'screenshot-overview-entry') {
      _navigationController.zoomTo('screenshot-root');
    }
  }

  @override
  void dispose() {
    _navigationController
      ..removeListener(_handleNavigationChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TreemapAppearance? nodeAppearance(
      BuildContext context,
      TreemapNodeDetails<String> details,
      Set<TreemapVisualState> states,
    ) {
      if (details.isAggregate) {
        final isBlue =
            details.geometry.parentKey?.sourceKey == 'screenshot-blue';
        return TreemapAppearance(
          color: isBlue ? const Color(0xFF0B63F6) : const Color(0xFFEC168C),
          opacity: .2,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        );
      }
      if (details.hasChildren) {
        return const TreemapAppearance(color: Colors.transparent, opacity: 0);
      }
      final color = details.color;
      return TreemapAppearance(
        color: color is Color ? color.withValues(alpha: 1) : null,
        opacity: color is Color ? color.a : 1,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      );
    }

    final appearance = TreemapAppearanceResolver<String>(
      colorScale: TreemapColorScale.exact(const {}, fallback: Colors.grey),
      style: TreemapStyle(
        backgroundColor: Theme.of(context).colorScheme.surface,
        labelPadding: const EdgeInsets.only(left: 16, top: 12),
      ),
      nodeStyleResolver: nodeAppearance,
    );
    final showsScreenshot = _showsScreenshot;
    final chart = TreemapChart<String>(
      root: showsScreenshot ? _screenshotTree() : _screenshotOverviewTree(),
      tiles: TreemapTiles(appearance: appearance),
      labels: TreemapCanvasLabels(
        appearance: appearance,
        config: TreemapLabelConfig(
          showValue: false,
          titleFormatter: (details) =>
              details.isAggregate ? 'Other...' : details.label ?? '',
          titleStyle: const TextStyle(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
          colorResolver: (_) => const Color(0xCC000000),
        ),
      ),
      layout: TreemapLayoutConfig(
        levelPadding: const TreemapInsets.all(8),
        innerSpacing: 16,
        minimumWidth: 72,
        minimumHeight: 24,
        minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
        policy: TreemapLayoutPolicy(
          rootRule: const TreemapLayoutRule(
            algorithm: TreemapLayoutAlgorithm.dice,
          ),
          byChildDepth: const {
            2: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.squarified),
          },
        ),
      ),
      interaction: showsScreenshot
          ? const TreemapInteractionConfig<String>(zoomOnNodeTap: false)
          : TreemapInteractionConfig<String>(
              zoomOnNodeTap: false,
              onNodeTap: _openScreenshot,
            ),
      surrounding: TreemapSurroundingGrid<String>.fromMap({
        TreemapOverlayPosition.topStart:
            TreemapSurroundingContent<String>.builder(
              builder: (context, controller) => SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: TreemapBreadcrumbsView<String>(
                    controller: _navigationController,
                    config: const TreemapBreadcrumbsConfig<String>(
                      wrapperBuilder: _screenshotChromeWrapper,
                      itemBuilder: _screenshotBreadcrumbItem,
                    ),
                  ),
                ),
              ),
            ),
        TreemapOverlayPosition.topEnd:
            const TreemapSurroundingContent<String>.widget(
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: EdgeInsets.only(right: 24, bottom: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.bottomEnd,
                    child: _ScreenshotLegends(),
                  ),
                ),
              ),
            ),
      }, columnGap: 16),
      clipBehavior: Clip.hardEdge,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(dimension: side, child: chart),
        );
      },
    );
  }
}
