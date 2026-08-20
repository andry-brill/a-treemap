import 'package:flutter/material.dart';

import '../controller.dart';
import '../presentation/context.dart';

/// Describes the paint and text styling for one tile state.
final class TreemapAppearance {
  const TreemapAppearance({
    this.color,
    this.gradient,
    this.border = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
    this.opacity = 1,
    this.titleStyle,
    this.valueStyle,
  }) : assert(opacity >= 0 && opacity <= 1);

  final Color? color;
  final Gradient? gradient;
  final BorderSide border;
  final BorderRadius borderRadius;
  final double opacity;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;

  TreemapAppearance copyWith({
    Color? color,
    Gradient? gradient,
    BorderSide? border,
    BorderRadius? borderRadius,
    double? opacity,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
  }) => TreemapAppearance(
    color: color ?? this.color,
    gradient: gradient ?? this.gradient,
    border: border ?? this.border,
    borderRadius: borderRadius ?? this.borderRadius,
    opacity: opacity ?? this.opacity,
    titleStyle: titleStyle ?? this.titleStyle,
    valueStyle: valueStyle ?? this.valueStyle,
  );

  TreemapAppearance merge(TreemapAppearance? other) {
    if (other == null) return this;
    return TreemapAppearance(
      color: other.color ?? color,
      gradient: other.gradient ?? gradient,
      border: other.border == BorderSide.none ? border : other.border,
      borderRadius: other.borderRadius == BorderRadius.zero
          ? borderRadius
          : other.borderRadius,
      opacity: opacity * other.opacity,
      titleStyle: other.titleStyle ?? titleStyle,
      valueStyle: other.valueStyle ?? valueStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TreemapAppearance &&
      color == other.color &&
      gradient == other.gradient &&
      border == other.border &&
      borderRadius == other.borderRadius &&
      opacity == other.opacity &&
      titleStyle == other.titleStyle &&
      valueStyle == other.valueStyle;

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    border,
    borderRadius,
    opacity,
    titleStyle,
    valueStyle,
  );
}

/// Groups base, interaction-state, background, and label-padding appearance.
final class TreemapStyle {
  const TreemapStyle({
    this.backgroundColor = const Color(0x00000000),
    this.tileAppearance = const TreemapAppearance(),
    this.hoverAppearance = const TreemapAppearance(
      border: BorderSide(color: Color(0xFFFFFFFF), width: 2),
    ),
    this.selectedAppearance = const TreemapAppearance(
      border: BorderSide(color: Color(0xFFFFC107), width: 3),
    ),
    this.focusedAppearance = const TreemapAppearance(),
    this.labelPadding = const EdgeInsets.all(6),
  });

  final Color backgroundColor;
  final TreemapAppearance tileAppearance;
  final TreemapAppearance hoverAppearance;
  final TreemapAppearance selectedAppearance;
  final TreemapAppearance focusedAppearance;
  final EdgeInsets labelPadding;

  TreemapStyle copyWith({
    Color? backgroundColor,
    TreemapAppearance? tileAppearance,
    TreemapAppearance? hoverAppearance,
    TreemapAppearance? selectedAppearance,
    TreemapAppearance? focusedAppearance,
    EdgeInsets? labelPadding,
  }) => TreemapStyle(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    tileAppearance: tileAppearance ?? this.tileAppearance,
    hoverAppearance: hoverAppearance ?? this.hoverAppearance,
    selectedAppearance: selectedAppearance ?? this.selectedAppearance,
    focusedAppearance: focusedAppearance ?? this.focusedAppearance,
    labelPadding: labelPadding ?? this.labelPadding,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapStyle &&
      backgroundColor == other.backgroundColor &&
      tileAppearance == other.tileAppearance &&
      hoverAppearance == other.hoverAppearance &&
      selectedAppearance == other.selectedAppearance &&
      focusedAppearance == other.focusedAppearance &&
      labelPadding == other.labelPadding;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    tileAppearance,
    hoverAppearance,
    selectedAppearance,
    focusedAppearance,
    labelPadding,
  );
}

typedef TreemapNodeStyleResolver<K> =
    TreemapAppearance? Function(
      BuildContext context,
      TreemapNodeDetails<K> details,
      Set<TreemapVisualState> states,
    );
