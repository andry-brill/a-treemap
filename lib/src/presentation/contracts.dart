import 'package:flutter/widgets.dart';

import '../controller.dart';
import 'context.dart';

typedef TreemapNodeWidgetBuilder<K> =
    Widget Function(BuildContext context, TreemapNodeDetails<K> details);
typedef TreemapStatefulNodeWidgetBuilder<K> =
    Widget Function(
      BuildContext context,
      TreemapNodeDetails<K> details,
      Set<TreemapVisualState> states,
    );

/// Required visual layer that owns all tile rendering.
abstract interface class TreemapTileLayer<K> {
  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

/// Optional visual layer that renders labels inside the resolved node bounds.
abstract interface class TreemapLabelLayer<K> {
  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

/// Optional accessibility layer that exposes treemap nodes to assistive
/// technologies.
///
/// Canvas-painted tiles do not create Flutter semantics nodes automatically.
/// Implement this contract to provide a complete, possibly customized,
/// accessibility representation for the visible treemap nodes.
abstract interface class TreemapSemanticsLayer<K> {
  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

/// Selects which pointer gestures can reveal a tooltip.
enum TreemapTooltipActivation {
  /// Reveals tooltips only while a mouse or stylus hovers a node.
  hover,

  /// Reveals tooltips only after a node tap.
  tap,

  /// Reveals tooltips for either hovering or tapping.
  hoverAndTap,
}

/// Optional layer that owns tooltip lifecycle preferences and complete output.
abstract interface class TreemapTooltipLayer<K> {
  TreemapTooltipActivation get activation;
  Duration? get hideDelay;
  bool get suppressDuringAnimation;

  Widget build(BuildContext context, TreemapTooltipContext<K> tooltip);
}

/// Builds arbitrary controller-aware surrounding content.
typedef TreemapSurroundingContentBuilder<K> =
    Widget Function(BuildContext context, TreemapController<K> controller);

/// Builds controller-aware content for a surrounding treemap composition.
///
/// Unlike [TreemapSurroundingLayer], this contract creates only the chrome
/// itself. A surrounding layout, such as `TreemapSurroundingGrid`, owns its
/// placement relative to the treemap viewport.
abstract interface class TreemapSurroundingContent<K> {
  /// Adapts a standalone widget to surrounding content.
  const factory TreemapSurroundingContent.widget({required Widget child}) =
      _TreemapSurroundingWidget<K>;

  /// Adapts a controller-aware builder to surrounding content.
  const factory TreemapSurroundingContent.builder({
    required TreemapSurroundingContentBuilder<K> builder,
  }) = _TreemapSurroundingBuilder<K>;

  Widget build(BuildContext context, TreemapController<K> controller);
}

final class _TreemapSurroundingWidget<K>
    implements TreemapSurroundingContent<K> {
  const _TreemapSurroundingWidget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, TreemapController<K> controller) => child;
}

final class _TreemapSurroundingBuilder<K>
    implements TreemapSurroundingContent<K> {
  const _TreemapSurroundingBuilder({required this.builder});

  final TreemapSurroundingContentBuilder<K> builder;

  @override
  Widget build(BuildContext context, TreemapController<K> controller) =>
      builder(context, controller);
}

/// Optional layer that can place arbitrary chrome around the treemap viewport.
abstract interface class TreemapSurroundingLayer<K> {
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapController<K> controller,
  );
}
