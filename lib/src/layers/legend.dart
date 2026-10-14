import 'package:flutter/widgets.dart';

import '../appearance/color_scale.dart';
import '../appearance/legend.dart';
import '../appearance/overlay.dart';
import '../controller.dart';
import '../presentation/contracts.dart';
import '../presentation/state.dart';
import 'surrounding_grid.dart';

/// Places a color-scale legend around a chart viewport.
final class TreemapLegend<K>
    implements TreemapSurroundingContent<K>, TreemapSurroundingLayer<K> {
  const TreemapLegend({required this.scale, required this.config});

  final TreemapColorScale scale;
  final TreemapLegendConfig config;

  @override
  Widget build(BuildContext context, TreemapController<K> controller) =>
      TreemapLegendView(scale: scale, config: config, controller: controller);

  @override
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapController<K> controller,
  ) => TreemapSurroundingGrid<K>.fromMap({
    config.position: this,
  }).wrap(context, treemap, controller);
}

/// Standalone legend widget for compositions outside a chart.
class TreemapLegendView<K> extends StatelessWidget {
  const TreemapLegendView({
    super.key,
    required this.scale,
    required this.config,
    this.controller,
    this.presentation,
  });

  final TreemapColorScale scale;
  final TreemapLegendConfig config;
  final TreemapController<K>? controller;

  /// Chart output for a legend outside its presentation scope. Inside a chart,
  /// the nearest scope is used automatically when this argument is absent.
  /// Without either, automatic scales must first be resolved with resolveDomain.
  final TreemapPresentationState<K>? presentation;

  @override
  Widget build(BuildContext context) {
    final state = presentation ?? TreemapPresentationScope.maybeOf<K>(context);
    if (state != null) {
      return _build(
        context,
        state.resolveColorScale(scale),
        state.hoveredColor,
      );
    }
    return controller == null
        ? _build(context, scale, null)
        : ListenableBuilder(
            listenable: controller!,
            builder: (context, _) =>
                _build(context, scale, controller!.hoveredColor),
          );
  }

  Widget _build(
    BuildContext context,
    TreemapColorScale scale,
    Object? hoveredColor,
  ) {
    Widget legend = config.kind == TreemapLegendKind.discrete
        ? _buildDiscrete(context, scale)
        : _buildBar(context, scale, hoveredColor);
    if (config.title case final title?) {
      final titleWidget = config.titleBuilder(context, title);
      legend = config.direction == Axis.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                SizedBox(width: config.spacing),
                Flexible(child: legend),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                SizedBox(height: config.spacing),
                Flexible(child: legend),
              ],
            );
    }
    return Semantics(
      label: config.title == null
          ? config.semanticsLabel
          : '${config.semanticsLabel}: ${config.title}',
      child: config.wrapperBuilder(context, legend),
    );
  }

  Widget _buildDiscrete(BuildContext context, TreemapColorScale scale) {
    final items = [
      for (final entry in scale.legendEntries)
        Padding(
          padding: EdgeInsetsDirectional.only(end: config.spacing),
          child: config.itemBuilder(
            context,
            entry,
            config.labelBuilder(context, entry),
          ),
        ),
    ];
    if (config.overflow == TreemapOverflowMode.wrap) {
      return Wrap(
        direction: config.direction,
        spacing: config.spacing,
        runSpacing: config.runSpacing,
        children: items,
      );
    }
    return SingleChildScrollView(
      scrollDirection: config.direction,
      child: config.direction == Axis.horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: items)
          : Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }

  Widget _buildBar(
    BuildContext context,
    TreemapColorScale scale,
    Object? hoveredColor,
  ) {
    final colors = config.segmented
        ? scale.legendEntries.map((entry) => entry.color).toList()
        : treemapSampleScale(scale, count: config.sampleCount);
    final barSize = config.direction == Axis.horizontal
        ? config.horizontalBarSize
        : config.verticalBarSize;
    if (colors.isEmpty) {
      return scale.isContinuous
          ? SizedBox.fromSize(size: barSize)
          : const SizedBox.shrink();
    }
    if (colors.length == 1) colors.add(colors.single);
    final bar = config.barBuilder(context, colors, config.direction);
    Widget withPointer(Object? value) {
      final fraction = treemapColorFraction(scale, value);
      final pointer =
          value == null ||
              (scale.isContinuous && (value is! num || !value.isFinite))
          ? null
          : config.pointerBuilder(context, scale.colorFor(value), fraction);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: bar),
          if (pointer != null)
            config.direction == Axis.horizontal
                ? Positioned(
                    left: fraction * barSize.width - config.pointerExtent / 2,
                    top: -config.horizontalPointerOffset,
                    child: pointer,
                  )
                : Positioned(
                    left: -config.verticalPointerOffset,
                    bottom:
                        fraction * barSize.height - config.pointerExtent / 2,
                    child: RotatedBox(quarterTurns: 1, child: pointer),
                  ),
        ],
      );
    }

    final content = withPointer(hoveredColor);
    final labels = scale.legendEntries;
    return config.direction == Axis.horizontal
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: barSize.width,
                height: barSize.height,
                child: content,
              ),
              if (config.showLabels && labels.isNotEmpty)
                SizedBox(
                  width: barSize.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      config.labelBuilder(context, labels.first),
                      if (labels.length > 1)
                        config.labelBuilder(context, labels.last),
                    ],
                  ),
                ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: barSize.width,
                height: barSize.height,
                child: content,
              ),
              if (config.showLabels && labels.isNotEmpty)
                SizedBox(
                  height: barSize.height,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      config.labelBuilder(context, labels.last),
                      if (labels.length > 1)
                        config.labelBuilder(context, labels.first),
                    ],
                  ),
                ),
            ],
          );
  }
}
