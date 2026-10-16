import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'datasets.dart';

T named<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((value) => value.name == name);
Alignment alignment(String name) => const {
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'center': Alignment.center,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
}[name]!;
FontWeight fontWeight(String name) =>
    FontWeight.values[int.parse(name.substring(1)) ~/ 100 - 1];
Curve curve(String name) => switch (name) {
  'easeInOutCubic' => Curves.easeInOutCubic,
  'easeOut' => Curves.easeOut,
  'fastOutSlowIn' => Curves.fastOutSlowIn,
  _ => Curves.linear,
};

/// Materializes every configured property through one chart construction path.
final class PlaygroundComposition {
  PlaygroundComposition(this.config, this.tree) {
    scale = _scale();
    if (config.text('preview.mode') == 'standalone') {
      scale = scale.resolveDomain(
        sourceLeaves(tree.root).map((node) => node.color ?? node.weight),
      );
    }
    appearance = TreemapAppearanceResolver<String>(
      colorScale: scale,
      style: TreemapStyle(
        backgroundColor: config.color('tiles.background'),
        tileAppearance: _stateAppearance('normal'),
        hoverAppearance: _stateAppearance('hover'),
        selectedAppearance: _stateAppearance('selected'),
        focusedAppearance: _stateAppearance('focused'),
      ),
      nodeStyleResolver: config.text('tiles.nodeStyle') == 'none'
          ? null
          : _nodeStyle,
    );
    layout = _layout();
    labelConfig = _labelConfig();
  }

  final PlaygroundConfig config;
  final TreemapNormalizedTree<String> tree;
  late final TreemapLayoutConfig<String> layout;
  late TreemapColorScale scale;
  late final TreemapAppearanceResolver<String> appearance;
  late final TreemapLabelConfig<String> labelConfig;

  EdgeInsets padding(String prefix) => EdgeInsets.fromLTRB(
    config.number('$prefix.left'),
    config.number('$prefix.top'),
    config.number('$prefix.right'),
    config.number('$prefix.bottom'),
  );
  TreemapInsets insets(String prefix) => TreemapInsets.fromLTRB(
    config.number('$prefix.left'),
    config.number('$prefix.top'),
    config.number('$prefix.right'),
    config.number('$prefix.bottom'),
  );

  TreemapColorScale _scale() {
    final fallback = config.color('color.fallback');
    final palette = config.palette('color.palette');
    String formatter(double value) => switch (config.text('color.formatter')) {
      'oneDecimal' => value.toStringAsFixed(1),
      'units' => '${value.round()} units',
      'opacity' => '${(100 - value * 80).round()}%',
      _ =>
        value == value.roundToDouble()
            ? value.round().toString()
            : value.toStringAsFixed(2),
    };
    final minimum =
        config.optionalNumber('color.minimum') ?? double.negativeInfinity;
    final maximum = config.optionalNumber('color.maximum') ?? double.infinity;
    final scope = named(
      TreemapColorDomainScope.values,
      config.text('color.domainScope'),
    );
    return switch (config.text('color.scale')) {
      'exact' => TreemapColorScale.exact(
        {
          for (final row in config.rows('color.mappings'))
            row['value']: parseColor(row['color'] as String),
        },
        labels: {
          for (final row in config.rows('color.mappings'))
            if (row['label'] != null && row['label'] != '')
              row['value']: row['label'] as String,
        },
        fallback: fallback,
      ),
      'categorical' => TreemapColorScale.categorical(
        palette,
        labels: config.text('color.labels').isEmpty
            ? const []
            : config.text('color.labels').split(','),
        fallback: fallback,
      ),
      'numericRange' => TreemapColorScale.numericRange([
        for (final row in config.rows('color.ranges'))
          TreemapNumericColorRange(
            minimum: (row['minimum'] as num).toDouble(),
            maximum: (row['maximum'] as num).toDouble(),
            color: parseColor(row['color'] as String),
            label: row['label'] as String?,
          ),
      ], fallback: fallback),
      'interpolated' => TreemapColorScale.interpolated(
        minimum: minimum,
        maximum: maximum,
        domainScope: scope,
        colors: palette,
        fallback: fallback,
        labelFormatter: formatter,
      ),
      'saturation' => TreemapColorScale.saturation(
        minimum: minimum,
        maximum: maximum,
        domainScope: scope,
        color: config.color('color.saturationHue'),
        minimumSaturation: config.number('color.minimumSaturation'),
        maximumSaturation: config.number('color.maximumSaturation'),
        fallback: fallback,
        labelFormatter: formatter,
      ),
      _ => suggestedScale(tree, fallback),
    };
  }

  TreemapAppearance _stateAppearance(String state) {
    final prefix = 'tiles.$state';
    final palette = config.palette('color.palette');
    final gradient = switch (config.text('$prefix.gradient')) {
      'linear' => LinearGradient(colors: [palette.first, palette.last]),
      'radial' => RadialGradient(colors: [palette.first, palette.last]),
      _ => null,
    };
    return TreemapAppearance(
      color: config.optionalColor('$prefix.color'),
      gradient: gradient,
      border: config.number('$prefix.borderWidth') == 0
          ? BorderSide.none
          : BorderSide(
              color: config.color('$prefix.borderColor'),
              width: config.number('$prefix.borderWidth'),
            ),
      borderRadius: BorderRadius.circular(config.number('$prefix.radius')),
      opacity: config.number('$prefix.opacity'),
    );
  }

  TreemapAppearance? _nodeStyle(
    BuildContext context,
    TreemapNodeDetails<String> details,
    Set<TreemapVisualState> states,
  ) {
    switch (config.text('tiles.nodeStyle')) {
      case 'depth':
        return TreemapAppearance(
          opacity: (1 - details.depth * .08).clamp(.4, 1),
        );
      case 'gradientStates':
        return TreemapAppearance(
          gradient: LinearGradient(
            colors: states.contains(TreemapVisualState.selected)
                ? const [Colors.deepPurple, Colors.pink]
                : states.contains(TreemapVisualState.hovered)
                ? const [Colors.teal, Colors.cyan]
                : const [Colors.indigo, Colors.blue],
          ),
          border: const BorderSide(color: Color(0x88FFFFFF)),
        );
      case 'opacityGroups':
        if (details.isAggregate) {
          return TreemapAppearance(
            color: details.geometry.parentKey?.sourceKey == 'screenshot-blue'
                ? blueOpacityPalette.first
                : pinkOpacityPalette.first,
            opacity: .2,
          );
        }
        if (details.hasChildren) {
          return const TreemapAppearance(color: Colors.transparent, opacity: 0);
        }
        final color = details.color;
        return color is Color
            ? TreemapAppearance(
                color: color.withValues(alpha: 1),
                opacity: color.a,
              )
            : null;
      default:
        return null;
    }
  }

  TreemapLayoutRule<String> _rule(Map<String, Object?> values) {
    String? option(String key) =>
        values[key] == null || values[key] == 'inherit'
        ? null
        : values[key] as String;
    final comparator = option('comparator') ?? config.text('layout.comparator');
    return TreemapLayoutRule(
      algorithm: option('algorithm') == null
          ? null
          : named(TreemapLayoutAlgorithm.values, option('algorithm')!),
      sort: option('sort') == null
          ? null
          : named(TreemapSortPolicy.values, option('sort')!),
      direction: option('origin') == null
          ? null
          : named(TreemapLayoutDirection.values, option('origin')!),
      axisOrder: option('axisOrder') == null
          ? null
          : named(TreemapAxisOrder.values, option('axisOrder')!),
      strategy: option('strategy') == 'equalColumns'
          ? const EqualColumnsStrategy()
          : null,
      comparator:
          option('sort') == 'custom' ||
              option('sort') == null && option('comparator') != null
          ? _comparators[comparator]
          : null,
    );
  }

  TreemapLayoutConfig<String> _layout() {
    final rootRule = _rule({
      for (final key in [
        'algorithm',
        'sort',
        'origin',
        'axisOrder',
        'strategy',
        'comparator',
      ])
        key: config.text('layout.$key'),
    });
    final rows = config.rows('layout.rules');
    final resolver = config.text('layout.resolver');
    return TreemapLayoutConfig(
      policy: TreemapLayoutPolicy(
        rootRule: rootRule,
        inheritResolvedRule: config.flag('layout.inherit'),
        byChildDepth: {
          for (final row in rows)
            if (row['target'] == 'depth')
              int.parse(row['key'].toString()): _rule(row),
        },
        byParentKey: {
          for (final row in rows)
            if (row['target'] == 'parent') row['key'] as String: _rule(row),
        },
        resolver: _layoutResolvers[resolver],
      ),
      outerPadding: insets('layout.outerPadding'),
      levelPadding: insets('layout.levelPadding'),
      innerSpacing: config.number('layout.innerSpacing'),
      maxVisibleDepth: config.optionalNumber('layout.maxVisibleDepth')?.toInt(),
      minimumWidth: config.number('layout.minimumWidth'),
      minimumHeight: config.number('layout.minimumHeight'),
      minimumArea: config.number('layout.minimumArea'),
      minimumNodePolicy: named(
        TreemapMinimumNodePolicy.values,
        config.text('layout.minimumNodePolicy'),
      ),
      insufficientSpacePolicy: named(
        TreemapInsufficientSpacePolicy.values,
        config.text('layout.insufficientSpacePolicy'),
      ),
    );
  }

  Color _labelColor(TreemapAppearance appearance) => (switch (config.text(
    'labels.colorResolver',
  )) {
    'white' => Colors.white,
    'black' => Colors.black,
    _ => treemapContrastingTextColor(appearance.color ?? Colors.transparent),
  }).withValues(alpha: config.number('labels.colorOpacity'));

  String title(TreemapNodeDetails<String> details) {
    final value = details.label ?? config.text('labels.fallbackTitle');
    return switch (config.text('labels.titleFormatter')) {
      'uppercase' => value.toUpperCase(),
      'aggregate' => details.isAggregate ? 'Other...' : value,
      _ => value,
    };
  }

  String value(TreemapNodeDetails<String> details) =>
      switch (config.text('labels.valueFormatter')) {
        'key' => details.key.toString(),
        'percent' => '${details.weight.toStringAsFixed(1)}%',
        _ =>
          details.node?.valueLabel ??
              (details.weight == details.weight.roundToDouble()
                  ? details.weight.round().toString()
                  : details.weight.toStringAsFixed(
                      config.integer('labels.weightFractionDigits'),
                    )),
      };

  TextStyle textStyle(String line) => TextStyle(
    fontSize: config.number('labels.${line}Size'),
    fontWeight: fontWeight(config.text('labels.${line}Weight')),
    color: config.optionalColor('labels.${line}Color'),
    height: config.number('labels.${line}Height'),
  );

  TreemapLabelStyle _labelStateStyle(String state) => TreemapLabelStyle(
    titleStyle: config.optionalNumber('labels.$state.titleSize') == null
        ? null
        : TextStyle(fontSize: config.number('labels.$state.titleSize')),
    valueStyle: config.optionalNumber('labels.$state.valueSize') == null
        ? null
        : TextStyle(fontSize: config.number('labels.$state.valueSize')),
  );

  TreemapLabelConfig<String> _labelConfig() => TreemapLabelConfig(
    showTitle: config.flag('labels.showTitle'),
    showValue: config.flag('labels.showValue'),
    titleFormatter: title,
    valueFormatter: value,
    localizedValueFormatter: config.text('labels.localizedFormatter') == 'none'
        ? null
        : (details, locale) {
            final number = details.weight.toStringAsFixed(1);
            final formatted = locale.languageCode == 'de'
                ? number.replaceAll('.', ',')
                : number;
            return config.text('labels.localizedFormatter') == 'money'
                ? (locale.languageCode == 'de' ? '€ ' : '\$ ') + formatted
                : '${locale.languageCode}: $formatted';
          },
    fallbackTitle: config.text('labels.fallbackTitle'),
    weightFractionDigits: config.integer('labels.weightFractionDigits'),
    titleStyle: textStyle('title'),
    valueStyle: textStyle('value'),
    hoverStyle: _labelStateStyle('hover'),
    selectedStyle: _labelStateStyle('selected'),
    focusedStyle: _labelStateStyle('focused'),
    nodeStyleResolver: config.text('labels.nodeStyle') == 'none'
        ? null
        : (context, details, states) => details.key.sourceKey == 'food'
              ? const TreemapLabelStyle(
                  titleStyle: TextStyle(fontSize: 16, color: Colors.deepPurple),
                )
              : null,
    padding: padding('labels.padding'),
    spacing: config.number('labels.spacing'),
    valueColorOpacity: config.number('labels.valueColorOpacity'),
    colorResolver: _labelColor,
    linesBuilder: config.text('labels.linesBuilder') == 'default'
        ? null
        : (details, appearance, locale, styles) => [
            if (config.flag('labels.showTitle'))
              TreemapCanvasLabelLine(
                text: title(details),
                style: _withLabelColor(
                  styles.titleStyle!,
                  _labelColor(appearance),
                ),
              ),
            if (config.flag('labels.showValue'))
              TreemapCanvasLabelLine(
                text: value(details),
                style: _withLabelColor(
                  styles.valueStyle!,
                  _labelColor(appearance),
                ),
              ),
            TreemapCanvasLabelLine(
              text: 'Depth ${details.depth}',
              style: _withLabelColor(
                styles.valueStyle!,
                _labelColor(appearance),
              ),
            ),
          ],
    maxLines: config.integer('labels.maxLines'),
    overflow: named(TextOverflow.values, config.text('labels.overflow')),
    ellipsis: config.text('labels.ellipsis'),
    alignment: alignment(config.text('labels.alignment')),
    textDirection: config.text('labels.textDirection') == 'inherit'
        ? null
        : named(TextDirection.values, config.text('labels.textDirection')),
  );

  TreemapTileLayer<String> get tiles {
    final canvas = TreemapTiles<String>(appearance: appearance);
    final base = switch (config.text('tiles.renderer')) {
      'noop' => TreemapNoopTileLayer(appearance: appearance),
      'widgets' => ConfiguredWidgetTiles(this),
      'composite' => TreemapCompositeTileLayer([
        canvas,
        ConfiguredWidgetTiles(this, borderOnly: true),
      ], appearance: appearance),
      _ => canvas,
    };
    if (!config.flag('tiles.centered.enabled') &&
        !config.flag('tiles.centeredText.enabled')) {
      return base;
    }
    final textTemplate = config.text('tiles.centeredText.template');
    // Count user-perceived characters once, including composed text and emoji.
    final textLength = textTemplate.characters.length;
    return TreemapCompositeTileLayer([
      base,
      if (config.flag('tiles.centered.enabled'))
        TreemapCenteredWidgetLayer<String>(
          widthFactor: config.number('tiles.centered.widthFactor'),
          heightFactor: config.number('tiles.centered.heightFactor'),
          aspect: config.optionalNumber('tiles.centered.aspect'),
          minimumSize: config.flag('tiles.centered.minimumEnabled')
              ? Size(
                  config.number('tiles.centered.minimumWidth'),
                  config.number('tiles.centered.minimumHeight'),
                )
              : null,
          builder: (context, details, states) => Container(
            key: ValueKey('centered-${details.key}'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: .8),
                width: states.contains(TreemapVisualState.selected) ? 3 : 1,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF176),
                  Color(0xFFFF9F43),
                  Color(0xFFFF4081),
                ],
                stops: [0, .45, 1],
              ),
            ),
          ),
        ),
      if (config.flag('tiles.centeredText.enabled'))
        TreemapCenteredTextLayer<String>.fixed(
          template: textTemplate,
          widthFactor: config.number('tiles.centeredText.widthFactor'),
          heightFactor: config.number('tiles.centeredText.heightFactor'),
          aspect: config.optionalNumber('tiles.centeredText.aspect'),
          minimumSize: config.flag('tiles.centeredText.minimumEnabled')
              ? Size(
                  config.number('tiles.centeredText.minimumWidth'),
                  config.number('tiles.centeredText.minimumHeight'),
                )
              : null,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          textBuilder: (context, details, states) {
            final letter = states.contains(TreemapVisualState.selected)
                ? 'W'
                : details.label?.characters.firstOrNull ?? 'I';
            return List.filled(textLength, letter.toUpperCase()).join();
          },
        ),
    ], appearance: appearance);
  }

  TreemapLabelLayer<String>? get labels => switch (config.text(
    'labels.renderer',
  )) {
    'none' => null,
    'widgets' => ConfiguredWidgetLabels(this),
    _ => TreemapCanvasLabels(config: labelConfig, parentLabels: parentLabels),
  };

  TreemapParentLabelConfig? get parentLabels =>
      config.flag('labels.parents.enabled')
      ? TreemapParentLabelConfig(
          showTitle: config.flag('labels.parents.showTitle'),
          showValue: config.flag('labels.parents.showValue'),
          height: config.optionalNumber('labels.parents.height'),
        )
      : null;

  Widget wrapper(BuildContext context, Widget child, String mode) =>
      mode == 'plain'
      ? child
      : TreemapOverlayContainer(
          padding: EdgeInsets.all(mode == 'rounded' ? 10 : 8),
          decoration: mode == 'rounded'
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: child,
        );

  TreemapLegendConfig get legendConfig {
    final kind = config.text('legend.kind');
    final discrete =
        kind == 'discrete' || kind == 'auto' && !scale.isContinuous;
    final position = named(
      TreemapOverlayPosition.values,
      config.text('legend.position'),
    );
    final direction = config.text('legend.direction') == 'horizontal'
        ? Axis.horizontal
        : Axis.vertical;
    Widget titleBuilder(BuildContext context, String title) => Text(
      title,
      style: config.text('legend.titleBuilder') == 'bold'
          ? const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
          : Theme.of(context).textTheme.labelLarge,
    );
    Widget labelBuilder(BuildContext context, TreemapLegendEntry entry) => Text(
      entry.label,
      style: config.text('legend.labelBuilder') == 'compact'
          ? const TextStyle(fontSize: 11)
          : Theme.of(context).textTheme.bodyMedium,
    );
    Widget itemBuilder(
      BuildContext context,
      TreemapLegendEntry entry,
      Widget label,
    ) => config.text('legend.itemBuilder') == 'chips'
        ? Chip(
            avatar: CircleAvatar(backgroundColor: entry.color, radius: 6),
            label: label,
          )
        : TreemapLegendItem(
            color: entry.color,
            label: label,
            swatchSize: 16,
            spacing: 6,
            swatchBorderRadius: BorderRadius.circular(
              config.text('legend.itemBuilder') == 'rounded' ? 4 : 0,
            ),
          );
    final title = config.text('legend.title').isEmpty
        ? null
        : config.text('legend.title');
    final overflow = named(
      TreemapOverflowMode.values,
      config.text('legend.overflow'),
    );
    if (discrete) {
      return TreemapLegendConfig.discrete(
        position: position,
        direction: direction,
        title: title,
        overflow: overflow,
        spacing: config.number('legend.spacing'),
        runSpacing: config.number('legend.runSpacing'),
        semanticsLabel: config.text('legend.semanticsLabel'),
        titleBuilder: titleBuilder,
        labelBuilder: labelBuilder,
        itemBuilder: itemBuilder,
        wrapperBuilder: (context, child) =>
            wrapper(context, child, config.text('legend.wrapper')),
      );
    }
    return TreemapLegendConfig.bar(
      position: position,
      direction: direction,
      title: title,
      overflow: overflow,
      spacing: config.number('legend.spacing'),
      semanticsLabel: config.text('legend.semanticsLabel'),
      titleBuilder: titleBuilder,
      labelBuilder: labelBuilder,
      wrapperBuilder: (context, child) =>
          wrapper(context, child, config.text('legend.wrapper')),
      segmented: config.flag('legend.segmented'),
      showLabels: config.flag('legend.showLabels'),
      sampleCount: config.integer('legend.sampleCount'),
      horizontalBarSize: Size(
        config.number('legend.horizontalWidth'),
        config.number('legend.horizontalHeight'),
      ),
      verticalBarSize: Size(
        config.number('legend.verticalWidth'),
        config.number('legend.verticalHeight'),
      ),
      pointerExtent: config.number('legend.pointerExtent'),
      horizontalPointerOffset: config.number('legend.horizontalPointerOffset'),
      verticalPointerOffset: config.number('legend.verticalPointerOffset'),
      barBuilder: (context, colors, axis) => TreemapLegendBar(
        colors: colors,
        direction: axis,
        borderRadius: BorderRadius.circular(
          config.text('legend.barBuilder') == 'rounded' ? 7 : 0,
        ),
      ),
      pointerBuilder: (context, color, fraction) =>
          switch (config.text('legend.pointerBuilder')) {
            'none' => const SizedBox.shrink(),
            'text' => Text(
              '${(fraction * 100).round()}%',
              style: const TextStyle(fontSize: 10),
            ),
            'color' => TreemapLegendPointer(
              color: color,
              dimension: config.number('legend.pointerExtent'),
            ),
            _ => TreemapLegendPointer(
              dimension: config.number('legend.pointerExtent'),
            ),
          },
    );
  }

  TreemapBreadcrumbsConfig<String> get breadcrumbConfig =>
      TreemapBreadcrumbsConfig(
        position: named(
          TreemapOverlayPosition.values,
          config.text('breadcrumbs.position'),
        ),
        overflow: named(
          TreemapOverflowMode.values,
          config.text('breadcrumbs.overflow'),
        ),
        ellipsisMaximumChildren: config.integer(
          'breadcrumbs.ellipsisMaximumChildren',
        ),
        wrapperBuilder: (context, child) =>
            wrapper(context, child, config.text('breadcrumbs.wrapper')),
        itemBuilder: (context, entry, current, onPressed) =>
            TreemapBreadcrumbItem(
              label: entry.label ?? 'Other',
              isCurrent: current,
              onPressed: onPressed,
              indicatorColor:
                  config.text('breadcrumbs.itemBuilder') == 'indicator'
                  ? Colors.orange
                  : null,
              indicatorWidth:
                  config.text('breadcrumbs.itemBuilder') == 'indicator' ? 3 : 2,
              animationDuration: Duration(
                milliseconds:
                    config.text('breadcrumbs.itemBuilder') == 'indicator'
                    ? 260
                    : 180,
              ),
            ),
        separatorBuilder: (context) =>
            config.text('breadcrumbs.separatorBuilder') == 'standard'
            ? const TreemapBreadcrumbSeparator()
            : TreemapBreadcrumbSeparator(
                label: config.text('breadcrumbs.separatorBuilder') == 'slash'
                    ? '/'
                    : config.text('breadcrumbs.separatorText'),
              ),
        overflowIndicatorBuilder: (context) => Text(
          config.text('breadcrumbs.overflowIndicator') == 'dots' ? '...' : '…',
        ),
      );

  TreemapSurroundingLayer<String>? surrounding({
    bool omitLegend = false,
    Widget? customTopEnd,
  }) {
    final slots =
        <TreemapOverlayPosition, List<TreemapSurroundingContent<String>>>{};
    void add(
      TreemapOverlayPosition position,
      TreemapSurroundingContent<String> content,
    ) => slots.putIfAbsent(position, () => []).add(content);
    if (config.flag('legend.enabled') && !omitLegend) {
      add(
        legendConfig.position,
        TreemapLegend(scale: scale, config: legendConfig),
      );
    }
    if (config.flag('breadcrumbs.enabled')) {
      add(
        breadcrumbConfig.position,
        TreemapBreadcrumbs(config: breadcrumbConfig),
      );
    }
    if (customTopEnd != null) {
      add(
        legendConfig.position,
        TreemapSurroundingContent.widget(child: customTopEnd),
      );
    }
    if (config.flag('preview.showPresentation')) {
      add(
        TreemapOverlayPosition.topCenter,
        TreemapSurroundingContent.builder(
          builder: (context, visual) {
            final state = visual.presentation;
            final resolved = state.resolveColorScale(scale);
            final targets =
                state.targetSnapshot?.visibleNodes.toList() ??
                <TreemapGeometryNode<String>>[];
            targets.sort(
              (a, b) => a.key.toString().compareTo(b.key.toString()),
            );
            TreemapGeometryNode<String>? focusTarget;
            for (final node in targets) {
              if (node.hasChildren) {
                focusTarget = node;
                break;
              }
            }
            focusTarget ??= targets.isEmpty ? null : targets.first;
            final focusKey = focusTarget?.key;
            final bounds = resolved.minimum == null
                ? 'No numeric domain'
                : 'Domain ${resolved.minimum!.toStringAsFixed(0)}–${resolved.maximum!.toStringAsFixed(0)}';
            return SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$bounds · ${state.targetSnapshot?.visibleNodes.length ?? 0} tiles',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Focus a tile',
                    onPressed: focusKey == null
                        ? null
                        : () => visual.actions.focus(focusKey),
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                  ),
                  IconButton(
                    tooltip: 'Activate focused tile',
                    onPressed: state.keyboardFocusedKey == null
                        ? null
                        : () => visual.actions.activate(
                            state.keyboardFocusedKey!,
                          ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    if (slots.isEmpty) return null;
    return TreemapSurroundingGrid.fromMap(
      {
        for (final entry in slots.entries)
          entry.key: entry.value.length == 1
              ? entry.value.single
              : TreemapSurroundingContent.builder(
                  builder: (context, visual) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final content in entry.value)
                        content.build(context, visual),
                    ],
                  ),
                ),
      },
      padding: padding('surrounding.padding'),
      rowGap: config.number('surrounding.rowGap'),
      columnGap: config.number('surrounding.columnGap'),
      clipBehavior: named(Clip.values, config.text('surrounding.clip')),
    );
  }

  TreemapChart<String> chart({
    required TreemapController<String> controller,
    required Set<TreemapKey<String>> selection,
    required void Function(Set<TreemapKey<String>>) onSelection,
    required void Function(String, String) onEvent,
    ValueChanged<TreemapPresentationState<String>>? onPresentation,
    bool omitLegend = false,
    Widget? customTopEnd,
    Key? key,
  }) {
    void event(String type, TreemapNodeDetails<String>? details) => onEvent(
      config.text('interaction.${type}Callback'),
      '$type: ${details?.label ?? details?.key.toString() ?? 'none'}',
    );
    final mode = config.text('interaction.tapCallback');
    return TreemapChart(
      key: key,
      tree: tree,
      controller: controller,
      layout: layout,
      tiles: tiles,
      labels: labels,
      selection: TreemapSelectionConfig(
        selected: config.flag('selection.controlled') ? selection : null,
        toggleable: config.flag('selection.toggleable'),
        allowMultiple: config.flag('selection.allowMultiple'),
        fallbackToNearestAncestor: config.flag(
          'selection.fallbackToNearestAncestor',
        ),
      ),
      interaction: TreemapInteractionConfig(
        enabled: config.flag('interaction.enabled'),
        enableBuiltInBehavior: config.flag('interaction.builtInBehavior'),
        zoomOnNodeTap: config.flag('interaction.zoomOnTap'),
        selectOnNodeTap: config.flag('interaction.selectOnTap'),
        longPressDuration: Duration(
          milliseconds: config.integer('interaction.longPressMs'),
        ),
        tapSlop: config.number('interaction.tapSlop'),
        hitTestPadding: config.number('interaction.hitTestPadding'),
        directionalCrossAxisWeight: config.number(
          'interaction.directionalCrossAxisWeight',
        ),
        onNodeTap: mode == 'none' ? null : (details) => event('tap', details),
        onNodeLongPress: config.text('interaction.longPressCallback') == 'none'
            ? null
            : (details) => event('longPress', details),
        onHoverChanged: config.text('interaction.hoverCallback') == 'none'
            ? null
            : (details) => event('hover', details),
        onSelectionChanged: (keys, details) {
          onSelection(keys);
          if (config.text('interaction.selectionCallback') != 'none') {
            event('selection', details);
          }
        },
        cursorResolver: config.text('interaction.cursor') == 'default'
            ? null
            : (details) => details == null
                  ? MouseCursor.defer
                  : config.text('interaction.cursor') == 'click'
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.precise,
      ),
      tooltip: config.flag('tooltip.enabled')
          ? TreemapTooltip(
              config: TreemapTooltipConfig(
                activation: named(
                  TreemapTooltipActivation.values,
                  config.text('tooltip.activation'),
                ),
                placement: named(
                  TreemapTooltipPlacement.values,
                  config.text('tooltip.placement'),
                ),
                fitInside: config.flag('tooltip.fitInside'),
                hideDelay: Duration(
                  milliseconds: config.integer('tooltip.hideDelayMs'),
                ),
                margin: config.number('tooltip.margin'),
                maxWidth: config.number('tooltip.maxWidth'),
                suppressDuringAnimation: config.flag(
                  'tooltip.suppressDuringAnimation',
                ),
                containerBuilder: (context, child) => TreemapTooltipContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(
                      config.text('tooltip.containerBuilder') == 'rounded'
                          ? 8
                          : 0,
                    ),
                  ),
                  child: child,
                ),
              ),
              builder: (context, details) => Text(
                '${title(details)}: ${value(details)}${config.text('tooltip.builder') == 'details' ? '\nDepth ${details.depth} · ${details.key}' : ''}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            )
          : null,
      semantics: config.flag('semantics.enabled')
          ? TreemapSemantics<String>(
              labelResolver: config.text('semantics.labelResolver') == 'key'
                  ? (details) => details.key.toString()
                  : null,
              valueResolver: config.text('semantics.valueResolver') == 'depth'
                  ? (details) => 'Depth ${details.depth}'
                  : null,
              hintResolver: config.text('semantics.hintResolver') == 'path'
                  ? (details) => details.path
                        .map((entry) => entry.label ?? '')
                        .join(' / ')
                  : null,
            )
          : null,
      surrounding: surrounding(
        omitLegend: omitLegend,
        customTopEnd: customTopEnd,
      ),
      transition: config.flag('animation.enabled')
          ? TreemapTransitionSpec(
              duration: Duration(
                milliseconds: config.integer('animation.durationMs'),
              ),
              curve: curve(config.text('animation.curve')),
            )
          : null,
      autofocus: config.flag('preview.autofocus'),
      clipBehavior: named(Clip.values, config.text('preview.clip')),
      onPresentationChanged: onPresentation,
    );
  }
}

final class EqualColumnsStrategy implements ITreemapLayoutStrategy<String> {
  const EqualColumnsStrategy();
  @override
  Map<TreemapKey<String>, TreemapBounds> layout(
    TreemapStrategyInput<String> input,
  ) {
    final width = input.bounds.width / input.items.length;
    return {
      for (final entry in input.items.indexed)
        entry.$2.key: TreemapBounds.fromLTWH(
          input.bounds.left + entry.$1 * width,
          input.bounds.top,
          width,
          input.bounds.height,
        ),
    };
  }
}

final class ConfiguredWidgetTiles implements TreemapTileLayer<String> {
  const ConfiguredWidgetTiles(this.composition, {this.borderOnly = false});
  final PlaygroundComposition composition;
  final bool borderOnly;
  @override
  TreemapAppearanceResolver<String> get appearance => composition.appearance;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    final appearances = visual.resolveAppearances(context, appearance);
    return TreemapBuilderTileLayer<String>(
      maximumNodes: composition.config
          .optionalNumber('tiles.maximumNodes')
          ?.toInt(),
      ignorePointer: composition.config.flag('tiles.ignorePointer'),
      builder: (context, details, states) {
        final appearance = appearances[details.key]!;
        return Opacity(
          opacity: appearance.opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: borderOnly ? null : appearance.color,
              gradient: borderOnly ? null : appearance.gradient,
              border: Border.fromBorderSide(
                borderOnly
                    ? const BorderSide(color: Color(0x66FFFFFF))
                    : appearance.border,
              ),
              borderRadius: appearance.borderRadius,
            ),
          ),
        );
      },
    ).build(context, visual);
  }
}

final class ConfiguredWidgetLabels implements TreemapLabelLayer<String> {
  const ConfiguredWidgetLabels(this.composition);
  final PlaygroundComposition composition;

  TreemapWidgetLabels<String> _layer(
    TreemapStatefulNodeWidgetBuilder<String> builder,
  ) {
    final config = composition.config;
    return TreemapWidgetLabels<String>(
      config: composition.labelConfig,
      maximumNodes: config.optionalNumber('labels.maximumNodes')?.toInt(),
      ignorePointer: config.flag('labels.ignorePointer'),
      clipBehavior: named(Clip.values, config.text('labels.clip')),
      parentLabels: composition.parentLabels,
      builder: builder,
      parentBuilder: config.text('labels.parents.widgetBuilder') == 'badge'
          ? (context, details, states) => DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.folder_outlined, size: 18),
                  ),
                  Expanded(child: builder(context, details, states)),
                ],
              ),
            )
          : null,
    );
  }

  @override
  double? resolveParentHeaderHeight(BuildContext context) => _layer(
    (context, details, states) => const SizedBox.shrink(),
  ).resolveParentHeaderHeight(context);
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    final config = composition.config;
    final labelConfig = composition.labelConfig;
    final parentLabels = composition.parentLabels;
    final appearances = visual.resolveTileAppearances(context);
    return _layer((context, details, states) {
      final header = details.headerBounds != null;
      final bounds = details.headerBounds ?? details.bounds;
      if (bounds.width < config.number('labels.minimumWidth') ||
          bounds.height < config.number('labels.minimumHeight')) {
        return const SizedBox.shrink();
      }
      final appearance = appearances[details.key]!;
      final color = labelConfig.colorResolver(appearance);
      final styles = labelConfig.resolveStyles(context, details, states);
      final titleStyle = _withLabelColor(styles.titleStyle!, color);
      final valueStyle = _withLabelColor(
        styles.valueStyle!,
        color.withValues(alpha: labelConfig.valueColorOpacity),
      );
      final icon = config.text('labels.widgetBuilder') == 'icons';
      final localized = labelConfig.localizedValueFormatter;
      final labelValue = localized == null
          ? labelConfig.valueFormatter!(details)
          : localized(details, Localizations.localeOf(context));
      final title = details.isAggregate && icon
          ? 'Other (${details.aggregateMembers.length})'
          : labelConfig.titleFormatter!(details);
      final showTitle =
          (header ? parentLabels!.showTitle : labelConfig.showTitle) &&
          title.isNotEmpty;
      final showValue =
          (header ? parentLabels!.showValue : labelConfig.showValue) &&
          labelValue.isNotEmpty;
      final spacing = showTitle && showValue ? labelConfig.spacing : 0.0;
      final labelPadding = labelConfig.padding;
      if (spacing > bounds.height - labelPadding.vertical) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: labelPadding,
        child: Align(
          alignment: labelConfig.alignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon) ...[
                        Icon(Icons.widgets_outlined, size: 14, color: color),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          textDirection: labelConfig.textDirection,
                          maxLines: header && parentLabels?.height == null
                              ? 1
                              : labelConfig.maxLines,
                          overflow: labelConfig.overflow,
                          style: titleStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              if (spacing > 0) SizedBox(height: spacing),
              if (showValue)
                Flexible(
                  child: Text(
                    labelValue,
                    textDirection: labelConfig.textDirection,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
            ],
          ),
        ),
      );
    }).build(context, visual);
  }
}

final _comparators = <String, TreemapNodeComparator<String>>{
  'reverseKey': (a, b) => b.key.compareTo(a.key),
  'label': (a, b) => (a.label ?? a.key).compareTo(b.label ?? b.key),
};
final _layoutResolvers = <String, TreemapLayoutRuleResolver<String>>{
  'alternateDepth': (context) => TreemapLayoutRule(
    algorithm: context.childDepth.isEven
        ? TreemapLayoutAlgorithm.dice
        : TreemapLayoutAlgorithm.slice,
  ),
  'consumerDice': (context) => context.parent.key == 'consumer'
      ? const TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.dice)
      : null,
  'responsive': (context) => TreemapLayoutRule(
    algorithm: context.bounds.width >= context.bounds.height
        ? TreemapLayoutAlgorithm.dice
        : TreemapLayoutAlgorithm.slice,
  ),
};

TextStyle _withLabelColor(TextStyle style, Color color) =>
    style.color != null || style.foreground != null
    ? style
    : style.copyWith(color: color);
