import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../controller.dart';
import 'context.dart';
import 'label_placement.dart';
import 'state.dart';

typedef TreemapNodeWidgetBuilder<K> =
    Widget Function(BuildContext context, TreemapNodeDetails<K> details);
typedef TreemapStatefulNodeWidgetBuilder<K> =
    Widget Function(
      BuildContext context,
      TreemapNodeDetails<K> details,
      Set<TreemapVisualState> states,
    );

/// Builds single-line text from displayed node details and visual states.
typedef TreemapStatefulNodeTextBuilder<K> =
    String Function(
      BuildContext context,
      TreemapNodeDetails<K> details,
      Set<TreemapVisualState> states,
    );

/// Required visual layer that owns all tile rendering.
abstract interface class TreemapTileLayer<K> {
  /// Background source shared with labels and other rendering layers.
  ///
  /// The chart reads this before building layers. Wrappers may delegate to their
  /// tile layer; the source must not depend on [build] having run. Return null
  /// when no shared source is declared. Canvas labels require a non-null source;
  /// arbitrary widgets and composite paints cannot be inspected to infer one.
  TreemapAppearanceResolver<K>? get appearance;

  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

/// Optional layer that declares header sizing and renders labels in node bounds.
abstract interface class TreemapLabelLayer<K> {
  /// Resolves the complete parent-header allocation before geometry is computed.
  ///
  /// Use configuration and inherited text metrics, never presentation output,
  /// built widgets or rendering callbacks. Wrappers may delegate to their label
  /// layer. Return null when no parent headers should be reserved. A height
  /// includes label padding and spacing and must be finite and non-negative;
  /// the chart passes only this number to geometry internally.
  double? resolveParentHeaderHeight(BuildContext context);

  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

/// Optional preparation capability for label layers that reserve content space.
///
/// The chart calls this once per build, after displayed geometry is resolved and
/// before building tiles. Return the prepared labels and their remaining content
/// bounds together so measurement and rendering agree. Wrappers delegate this
/// capability explicitly. Existing label layers can continue to render overlays
/// by implementing only [TreemapLabelLayer].
abstract interface class TreemapLabelPlacementProvider<K> {
  TreemapLabelPlacement<K> preparePlacement(
    BuildContext context,
    TreemapVisualContext<K> visual,
  );
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

/// Builds arbitrary presentation-aware surrounding content.
typedef TreemapSurroundingContentBuilder<K> =
    Widget Function(BuildContext context, TreemapVisualContext<K> visual);

/// Builds presentation-aware content for a surrounding treemap composition.
///
/// Unlike [TreemapSurroundingLayer], this contract creates only the chrome
/// itself. A surrounding layout, such as `TreemapSurroundingGrid`, owns its
/// placement relative to the treemap viewport.
abstract interface class TreemapSurroundingContent<K> {
  /// Adapts a standalone widget to surrounding content.
  const factory TreemapSurroundingContent.widget({required Widget child}) =
      _TreemapSurroundingWidget<K>;

  /// Adapts a presentation-aware builder to surrounding content.
  const factory TreemapSurroundingContent.builder({
    required TreemapSurroundingContentBuilder<K> builder,
  }) = _TreemapSurroundingBuilder<K>;

  Widget build(BuildContext context, TreemapVisualContext<K> visual);
}

final class _TreemapSurroundingWidget<K>
    implements TreemapSurroundingContent<K> {
  const _TreemapSurroundingWidget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) => child;
}

final class _TreemapSurroundingBuilder<K>
    implements TreemapSurroundingContent<K> {
  const _TreemapSurroundingBuilder({required this.builder});

  final TreemapSurroundingContentBuilder<K> builder;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      builder(context, visual);
}

/// Optional layer that can place arbitrary chrome around the treemap viewport.
abstract interface class TreemapSurroundingLayer<K> {
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapVisualContext<K> visual,
  );
}
