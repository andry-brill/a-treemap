import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'model.dart';

typedef TreemapNodeCallback<K> = void Function(TreemapNodeDetails<K> details);
typedef TreemapHoverCallback<K> = void Function(TreemapNodeDetails<K>? details);
typedef TreemapSelectionCallback<K> =
    void Function(Set<TreemapKey<K>> selection, TreemapNodeDetails<K>? changed);
typedef TreemapCursorResolver<K> =
    MouseCursor Function(TreemapNodeDetails<K>? details);

/// Core pointer, keyboard, navigation, and callback behavior.
final class TreemapInteractionConfig<K> {
  const TreemapInteractionConfig({
    this.enabled = true,
    this.enableBuiltInBehavior = true,
    this.zoomOnNodeTap = true,
    this.selectOnNodeTap = false,
    this.longPressDuration = kLongPressTimeout,
    this.tapSlop = kTouchSlop,
    this.hitTestPadding = 0,
    this.directionalCrossAxisWeight = .35,
    this.onNodeTap,
    this.onNodeLongPress,
    this.onHoverChanged,
    this.onSelectionChanged,
    this.cursorResolver,
  }) : assert(tapSlop >= 0),
       assert(hitTestPadding >= 0),
       assert(directionalCrossAxisWeight >= 0);

  final bool enabled;
  final bool enableBuiltInBehavior;

  /// Enables built-in branch drill-down on an ordinary node activation.
  ///
  /// A deepest-leaf activation with no [onNodeTap] callback moves back one
  /// focus level. Pointer or keyboard activation while Control, Meta, Alt, or
  /// Shift is held also moves back one level instead of drilling in.
  final bool zoomOnNodeTap;
  final bool selectOnNodeTap;
  final Duration longPressDuration;

  /// Maximum pointer movement still treated as a tap or long press.
  final double tapSlop;
  final double hitTestPadding;

  /// Weight applied to cross-axis distance during spatial keyboard traversal.
  final double directionalCrossAxisWeight;

  /// Receives the topmost visible node before any built-in tap behavior.
  ///
  /// Supplying this callback prevents the automatic deepest-leaf zoom-out so
  /// applications can define their own terminal-leaf action. Modifier-based
  /// zoom-out remains part of built-in navigation when it is enabled.
  final TreemapNodeCallback<K>? onNodeTap;
  final TreemapNodeCallback<K>? onNodeLongPress;
  final TreemapHoverCallback<K>? onHoverChanged;
  final TreemapSelectionCallback<K>? onSelectionChanged;
  final TreemapCursorResolver<K>? cursorResolver;

  TreemapInteractionConfig<K> copyWith({
    bool? enabled,
    bool? enableBuiltInBehavior,
    bool? zoomOnNodeTap,
    bool? selectOnNodeTap,
    Duration? longPressDuration,
    double? tapSlop,
    double? hitTestPadding,
    double? directionalCrossAxisWeight,
    TreemapNodeCallback<K>? onNodeTap,
    TreemapNodeCallback<K>? onNodeLongPress,
    TreemapHoverCallback<K>? onHoverChanged,
    TreemapSelectionCallback<K>? onSelectionChanged,
    TreemapCursorResolver<K>? cursorResolver,
  }) => TreemapInteractionConfig<K>(
    enabled: enabled ?? this.enabled,
    enableBuiltInBehavior: enableBuiltInBehavior ?? this.enableBuiltInBehavior,
    zoomOnNodeTap: zoomOnNodeTap ?? this.zoomOnNodeTap,
    selectOnNodeTap: selectOnNodeTap ?? this.selectOnNodeTap,
    longPressDuration: longPressDuration ?? this.longPressDuration,
    tapSlop: tapSlop ?? this.tapSlop,
    hitTestPadding: hitTestPadding ?? this.hitTestPadding,
    directionalCrossAxisWeight:
        directionalCrossAxisWeight ?? this.directionalCrossAxisWeight,
    onNodeTap: onNodeTap ?? this.onNodeTap,
    onNodeLongPress: onNodeLongPress ?? this.onNodeLongPress,
    onHoverChanged: onHoverChanged ?? this.onHoverChanged,
    onSelectionChanged: onSelectionChanged ?? this.onSelectionChanged,
    cursorResolver: cursorResolver ?? this.cursorResolver,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapInteractionConfig<K> &&
      enabled == other.enabled &&
      enableBuiltInBehavior == other.enableBuiltInBehavior &&
      zoomOnNodeTap == other.zoomOnNodeTap &&
      selectOnNodeTap == other.selectOnNodeTap &&
      longPressDuration == other.longPressDuration &&
      tapSlop == other.tapSlop &&
      hitTestPadding == other.hitTestPadding &&
      directionalCrossAxisWeight == other.directionalCrossAxisWeight &&
      onNodeTap == other.onNodeTap &&
      onNodeLongPress == other.onNodeLongPress &&
      onHoverChanged == other.onHoverChanged &&
      onSelectionChanged == other.onSelectionChanged &&
      cursorResolver == other.cursorResolver;

  @override
  int get hashCode => Object.hash(
    enabled,
    enableBuiltInBehavior,
    zoomOnNodeTap,
    selectOnNodeTap,
    longPressDuration,
    tapSlop,
    hitTestPadding,
    directionalCrossAxisWeight,
    onNodeTap,
    onNodeLongPress,
    onHoverChanged,
    onSelectionChanged,
    cursorResolver,
  );
}

/// Configures controlled or uncontrolled node-selection behavior.
final class TreemapSelectionConfig<K> {
  TreemapSelectionConfig({
    Set<TreemapKey<K>>? selected,
    this.toggleable = true,
    this.allowMultiple = false,
    this.fallbackToNearestAncestor = false,
  }) : selected = selected == null ? null : Set.unmodifiable(selected);

  /// Non-null means controlled selection ownership.
  final Set<TreemapKey<K>>? selected;
  final bool toggleable;
  final bool allowMultiple;
  final bool fallbackToNearestAncestor;

  TreemapSelectionConfig<K> copyWith({
    Set<TreemapKey<K>>? selected,
    bool? toggleable,
    bool? allowMultiple,
    bool? fallbackToNearestAncestor,
  }) => TreemapSelectionConfig<K>(
    selected: selected ?? this.selected,
    toggleable: toggleable ?? this.toggleable,
    allowMultiple: allowMultiple ?? this.allowMultiple,
    fallbackToNearestAncestor:
        fallbackToNearestAncestor ?? this.fallbackToNearestAncestor,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapSelectionConfig<K> &&
      setEquals(selected, other.selected) &&
      toggleable == other.toggleable &&
      allowMultiple == other.allowMultiple &&
      fallbackToNearestAncestor == other.fallbackToNearestAncestor;

  @override
  int get hashCode => Object.hash(
    selected == null ? null : Object.hashAllUnordered(selected!),
    toggleable,
    allowMultiple,
    fallbackToNearestAncestor,
  );
}
