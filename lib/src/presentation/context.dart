import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../geometry.dart';
import '../model.dart';

/// Identifies transient or persistent state available to visual resolvers.
enum TreemapVisualState {
  /// The pointer currently targets the node.
  hovered,

  /// The node belongs to the active selection.
  selected,

  /// The node is the current keyboard-navigation target.
  focused,

  /// Interaction is disabled for the chart.
  disabled,
}

/// Immutable state supplied to replaceable visual layers.
final class TreemapVisualContext<K> {
  TreemapVisualContext({
    required this.snapshot,
    required Map<TreemapKey<K>, TreemapNodeDetails<K>> details,
    required Map<TreemapKey<K>, Set<TreemapVisualState>> states,
    required this.controller,
    required Set<TreemapKey<K>> selection,
    required this.textDirection,
    required this.textScaler,
    required this.isAnimating,
    required this.onActivate,
    required this.onFocus,
  }) : details = Map.unmodifiable(details),
       states = Map.unmodifiable({
         for (final entry in states.entries)
           entry.key: Set<TreemapVisualState>.unmodifiable(entry.value),
       }),
       selection = Set.unmodifiable(selection);

  final TreemapGeometrySnapshot<K> snapshot;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  final Map<TreemapKey<K>, Set<TreemapVisualState>> states;
  final TreemapController<K> controller;
  final Set<TreemapKey<K>> selection;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final bool isAnimating;
  final ValueChanged<TreemapNodeDetails<K>> onActivate;
  final ValueChanged<TreemapNodeDetails<K>> onFocus;

  Set<TreemapVisualState> statesFor(TreemapKey<K> key) =>
      states[key] ?? const {};

  /// The deepest painted nodes at the current focus and layout.
  ///
  /// A snapshot also contains ancestor geometry so tile layers can paint
  /// hierarchy backgrounds and spacing. Labels, semantics, and tooltips
  /// normally target these end blocks instead of those ancestors.
  Iterable<TreemapGeometryNode<K>> get visibleLeafNodes sync* {
    final visible = snapshot.visibleNodes.toList(growable: false);
    final parents = visible
        .map((node) => node.parentKey)
        .whereType<TreemapKey<K>>()
        .toSet();
    for (final node in visible) {
      if (!parents.contains(node.key)) yield node;
    }
  }
}

/// Combines the tooltip target with the complete visual-layer state.
final class TreemapTooltipContext<K> {
  const TreemapTooltipContext({required this.details, required this.visual});

  final TreemapNodeDetails<K> details;
  final TreemapVisualContext<K> visual;
}
