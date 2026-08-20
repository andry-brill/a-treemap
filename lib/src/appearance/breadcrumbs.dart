import 'package:flutter/material.dart';

import '../geometry.dart';
import '../widgets/breadcrumb_item.dart';
import '../widgets/breadcrumb_separator.dart';
import '../widgets/overlay_container.dart';
import 'overlay.dart';

/// Builds one complete breadcrumb, including its interaction and current state.
///
/// The default builder returns a configurable [TreemapBreadcrumbItem].
typedef TreemapBreadcrumbItemBuilder<K> =
    Widget Function(
      BuildContext context,
      TreemapPathEntry<K> entry,
      bool isCurrent,
      VoidCallback? onPressed,
    );

/// Builds the separator placed between adjacent breadcrumbs.
///
/// The default builder returns a configurable [TreemapBreadcrumbSeparator].
typedef TreemapBreadcrumbSeparatorBuilder =
    Widget Function(BuildContext context);

/// Builds the marker shown when earlier breadcrumbs are omitted.
typedef TreemapBreadcrumbOverflowIndicatorBuilder =
    Widget Function(BuildContext context);

Widget _buildTreemapBreadcrumbItem(
  BuildContext context,
  TreemapPathEntry<Object?> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) {
  final label = entry.label ?? entry.key.sourceKey?.toString() ?? 'Other';
  return TreemapBreadcrumbItem(
    label: label,
    isCurrent: isCurrent,
    onPressed: onPressed,
  );
}

Widget _buildTreemapBreadcrumbSeparator(BuildContext context) =>
    const TreemapBreadcrumbSeparator();

Widget _buildTreemapBreadcrumbOverflowIndicator(BuildContext context) =>
    const Text('…');

Widget _wrapTreemapBreadcrumbs(BuildContext context, Widget child) =>
    TreemapOverlayContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    );

/// Configures breadcrumb placement, item construction, and overflow behavior.
final class TreemapBreadcrumbsConfig<K> {
  const TreemapBreadcrumbsConfig({
    this.position = TreemapOverlayPosition.topCenter,
    this.separatorBuilder = _buildTreemapBreadcrumbSeparator,
    this.overflow = TreemapOverflowMode.scroll,
    this.itemBuilder = _buildTreemapBreadcrumbItem,
    this.wrapperBuilder = _wrapTreemapBreadcrumbs,
    this.ellipsisMaximumChildren = 5,
    this.overflowIndicatorBuilder = _buildTreemapBreadcrumbOverflowIndicator,
  }) : assert(ellipsisMaximumChildren > 0);

  final TreemapOverlayPosition position;
  final TreemapOverflowMode overflow;

  /// Builds a fresh separator between each pair of breadcrumb items.
  final TreemapBreadcrumbSeparatorBuilder separatorBuilder;

  /// Builds each complete breadcrumb from its path entry and action.
  final TreemapBreadcrumbItemBuilder<K> itemBuilder;

  /// Wraps the complete breadcrumb content with padding, decoration, or other
  /// caller-defined presentation.
  final TreemapOverlayWrapperBuilder wrapperBuilder;

  /// Maximum number of trailing children retained in ellipsis overflow mode.
  final int ellipsisMaximumChildren;

  /// Builds the marker placed before retained children when earlier children
  /// are omitted.
  final TreemapBreadcrumbOverflowIndicatorBuilder overflowIndicatorBuilder;

  TreemapBreadcrumbsConfig<K> copyWith({
    TreemapOverlayPosition? position,
    TreemapOverflowMode? overflow,
    TreemapBreadcrumbSeparatorBuilder? separatorBuilder,
    TreemapBreadcrumbItemBuilder<K>? itemBuilder,
    TreemapOverlayWrapperBuilder? wrapperBuilder,
    int? ellipsisMaximumChildren,
    TreemapBreadcrumbOverflowIndicatorBuilder? overflowIndicatorBuilder,
  }) => TreemapBreadcrumbsConfig<K>(
    position: position ?? this.position,
    overflow: overflow ?? this.overflow,
    separatorBuilder: separatorBuilder ?? this.separatorBuilder,
    itemBuilder: itemBuilder ?? this.itemBuilder,
    wrapperBuilder: wrapperBuilder ?? this.wrapperBuilder,
    ellipsisMaximumChildren:
        ellipsisMaximumChildren ?? this.ellipsisMaximumChildren,
    overflowIndicatorBuilder:
        overflowIndicatorBuilder ?? this.overflowIndicatorBuilder,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapBreadcrumbsConfig<K> &&
      position == other.position &&
      overflow == other.overflow &&
      separatorBuilder == other.separatorBuilder &&
      itemBuilder == other.itemBuilder &&
      wrapperBuilder == other.wrapperBuilder &&
      ellipsisMaximumChildren == other.ellipsisMaximumChildren &&
      overflowIndicatorBuilder == other.overflowIndicatorBuilder;

  @override
  int get hashCode => Object.hash(
    position,
    overflow,
    separatorBuilder,
    itemBuilder,
    wrapperBuilder,
    ellipsisMaximumChildren,
    overflowIndicatorBuilder,
  );
}
