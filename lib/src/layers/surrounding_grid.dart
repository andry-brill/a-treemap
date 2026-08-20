import 'package:flutter/widgets.dart';

import '../appearance/overlay.dart';
import '../controller.dart';
import '../presentation/contracts.dart';

/// Places controller-aware content in directional slots around the treemap.
///
/// Top and bottom rows use three equal-width logical cells and take their
/// natural content height. The middle row receives the remaining height; its
/// treemap expands into the width not occupied by the optional side cells.
/// Callers own the sizing and overflow behavior of the supplied content.
final class TreemapSurroundingGrid<K> implements TreemapSurroundingLayer<K> {
  const TreemapSurroundingGrid({
    this.topStart,
    this.topCenter,
    this.topEnd,
    this.middleStart,
    this.middleEnd,
    this.bottomStart,
    this.bottomCenter,
    this.bottomEnd,
    this.padding = EdgeInsets.zero,
    this.rowGap = 0,
    this.columnGap = 0,
    this.clipBehavior = Clip.none,
  }) : assert(rowGap >= 0 && rowGap < double.infinity),
       assert(columnGap >= 0 && columnGap < double.infinity);

  /// Creates a grid from dynamically selected directional cells.
  ///
  /// The supplied map is read immediately and is not retained.
  factory TreemapSurroundingGrid.fromMap(
    Map<TreemapOverlayPosition, TreemapSurroundingContent<K>> content, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double rowGap = 0,
    double columnGap = 0,
    Clip clipBehavior = Clip.none,
  }) => TreemapSurroundingGrid<K>(
    topStart: content[TreemapOverlayPosition.topStart],
    topCenter: content[TreemapOverlayPosition.topCenter],
    topEnd: content[TreemapOverlayPosition.topEnd],
    middleStart: content[TreemapOverlayPosition.middleStart],
    middleEnd: content[TreemapOverlayPosition.middleEnd],
    bottomStart: content[TreemapOverlayPosition.bottomStart],
    bottomCenter: content[TreemapOverlayPosition.bottomCenter],
    bottomEnd: content[TreemapOverlayPosition.bottomEnd],
    padding: padding,
    rowGap: rowGap,
    columnGap: columnGap,
    clipBehavior: clipBehavior,
  );

  final TreemapSurroundingContent<K>? topStart;
  final TreemapSurroundingContent<K>? topCenter;
  final TreemapSurroundingContent<K>? topEnd;
  final TreemapSurroundingContent<K>? middleStart;
  final TreemapSurroundingContent<K>? middleEnd;
  final TreemapSurroundingContent<K>? bottomStart;
  final TreemapSurroundingContent<K>? bottomCenter;
  final TreemapSurroundingContent<K>? bottomEnd;

  final EdgeInsetsGeometry padding;
  final double rowGap;
  final double columnGap;
  final Clip clipBehavior;

  @override
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapController<K> controller,
  ) {
    Widget? build(TreemapSurroundingContent<K>? content) =>
        content?.build(context, controller);

    final top = _SurroundingOuterRow(
      start: build(topStart),
      center: build(topCenter),
      end: build(topEnd),
      crossAxisAlignment: CrossAxisAlignment.start,
      columnGap: columnGap,
    );
    final bottom = _SurroundingOuterRow(
      start: build(bottomStart),
      center: build(bottomCenter),
      end: build(bottomEnd),
      crossAxisAlignment: CrossAxisAlignment.end,
      columnGap: columnGap,
    );
    final middleStartWidget = build(middleStart);
    final middleEndWidget = build(middleEnd);

    Widget result = Padding(
      padding: padding,
      child: Column(
        spacing: rowGap,
        children: [
          if (top.hasContent) top,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: columnGap,
              children: [
                if (middleStartWidget != null)
                  _SurroundingMiddleCell(
                    alignment: AlignmentDirectional.centerStart,
                    child: middleStartWidget,
                  ),
                Expanded(child: treemap),
                if (middleEndWidget != null)
                  _SurroundingMiddleCell(
                    alignment: AlignmentDirectional.centerEnd,
                    child: middleEndWidget,
                  ),
              ],
            ),
          ),
          if (bottom.hasContent) bottom,
        ],
      ),
    );
    if (clipBehavior != Clip.none) {
      result = ClipRect(clipBehavior: clipBehavior, child: result);
    }
    return result;
  }
}

final class _SurroundingOuterRow extends StatelessWidget {
  const _SurroundingOuterRow({
    required this.start,
    required this.center,
    required this.end,
    required this.crossAxisAlignment,
    required this.columnGap,
  });

  final Widget? start;
  final Widget? center;
  final Widget? end;
  final CrossAxisAlignment crossAxisAlignment;
  final double columnGap;

  bool get hasContent => start != null || center != null || end != null;

  @override
  Widget build(BuildContext context) {
    if (start == null && end == null) {
      return SizedBox(
        width: double.infinity,
        child: Align(alignment: Alignment.center, child: center),
      );
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      spacing: columnGap,
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: start,
          ),
        ),
        Expanded(
          child: Align(alignment: Alignment.center, child: center),
        ),
        Expanded(
          child: Align(alignment: AlignmentDirectional.centerEnd, child: end),
        ),
      ],
    );
  }
}

final class _SurroundingMiddleCell extends StatelessWidget {
  const _SurroundingMiddleCell({required this.alignment, required this.child});

  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Align(widthFactor: 1, alignment: alignment, child: child);
}
