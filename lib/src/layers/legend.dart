import 'package:flutter/widgets.dart';

import '../appearance/color_scale.dart';
import '../appearance/legend.dart';
import '../appearance/overlay.dart';
import '../controller.dart';
import '../presentation/contracts.dart';
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
  });

  final TreemapColorScale scale;
  final TreemapLegendConfig config;
  final TreemapController<K>? controller;

  @override
  Widget build(BuildContext context) {
    Widget legend = config.kind == TreemapLegendKind.discrete
        ? _buildDiscrete(context)
        : _buildBar(context);
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

  Widget _buildDiscrete(BuildContext context) {
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

  Widget _buildBar(BuildContext context) {
    final colors = config.segmented
        ? scale.legendEntries.map((entry) => entry.color).toList()
        : treemapSampleScale(scale, count: config.sampleCount);
    if (colors.isEmpty) return const SizedBox.shrink();
    final barSize = config.direction == Axis.horizontal
        ? config.horizontalBarSize
        : config.verticalBarSize;
    final bar = config.barBuilder(context, colors, config.direction);
    Widget withPointer(Object? value) {
      final fraction = treemapColorFraction(scale, value);
      final pointer = value == null
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

    final content = controller == null
        ? withPointer(null)
        : ListenableBuilder(
            listenable: controller!,
            builder: (context, _) => withPointer(controller!.hoveredColor),
          );
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
                      config.labelBuilder(context, labels.first),
                    ],
                  ),
                ),
            ],
          );
  }
}
