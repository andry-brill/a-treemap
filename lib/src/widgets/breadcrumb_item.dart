import 'package:flutter/material.dart';

/// Standard accessible breadcrumb item used by the default item builder.
class TreemapBreadcrumbItem extends StatelessWidget {
  const TreemapBreadcrumbItem({
    super.key,
    required this.label,
    required this.isCurrent,
    this.onPressed,
    this.semanticLabel,
    this.animationDuration = const Duration(milliseconds: 180),
    this.animationCurve = Curves.linear,
    this.indicatorColor,
    this.inactiveIndicatorColor = Colors.transparent,
    this.indicatorWidth = 2,
    this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.buttonStyle,
  }) : assert(indicatorWidth >= 0),
       assert(maxLines > 0);

  /// Human-readable text shown by the item.
  final String label;

  /// Whether this item represents the current navigation level.
  final bool isCurrent;

  /// Navigation action for an ancestor; normally null for the current item.
  final VoidCallback? onPressed;

  /// Optional accessibility label used instead of [label].
  final String? semanticLabel;

  /// Duration used when the current-level indicator changes.
  final Duration animationDuration;

  /// Curve used when the current-level indicator changes.
  final Curve animationCurve;

  /// Current-level indicator color, defaulting to the theme primary color.
  final Color? indicatorColor;

  /// Indicator color used for ancestor items.
  final Color inactiveIndicatorColor;

  /// Thickness of the bottom current-level indicator.
  final double indicatorWidth;

  /// Label style, defaulting to the theme body-medium style.
  final TextStyle? textStyle;

  /// Maximum number of lines occupied by the label.
  final int maxLines;

  /// How overflowing label text is handled.
  final TextOverflow overflow;

  /// Optional style for the containing text button.
  final ButtonStyle? buttonStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    button: !isCurrent,
    selected: isCurrent,
    label: semanticLabel ?? label,
    child: TextButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isCurrent
                  ? indicatorColor ?? Theme.of(context).colorScheme.primary
                  : inactiveIndicatorColor,
              width: indicatorWidth,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: maxLines,
          overflow: overflow,
          style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ),
  );
}
