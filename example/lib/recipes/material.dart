import 'package:any_treemap/any_treemap.dart';
import 'package:material_ui/material_ui.dart';

/// Copy this file into your app and supply these functions to core configs.
Widget materialTreemapBreadcrumb(
  BuildContext context,
  TreemapPathEntry<Object?> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => MaterialTreemapBreadcrumbItem(
  label: entry.label ?? entry.key.sourceKey?.toString() ?? 'Other',
  isCurrent: isCurrent,
  onPressed: onPressed,
);

Widget materialTreemapLegendTitle(BuildContext context, String title) =>
    Text(title, style: Theme.of(context).textTheme.labelLarge);

Widget materialTreemapLegendLabel(
  BuildContext context,
  TreemapLegendEntry entry,
) => Text(entry.label, style: Theme.of(context).textTheme.bodyMedium);

Widget materialTreemapLegendPointer(
  BuildContext context,
  Color color,
  double fraction,
) => TreemapLegendPointer(color: Theme.of(context).colorScheme.onSurface);

Widget materialTreemapTooltip(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return TreemapTooltipContainer(
    decoration:
        theme.tooltipTheme.decoration ??
        BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
    child: DefaultTextStyle(
      style:
          theme.tooltipTheme.textStyle ??
          (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
      child: child,
    ),
  );
}

/// Application-owned Material recipe, including native focus/keyboard behavior.
class MaterialTreemapBreadcrumbItem extends StatelessWidget {
  const MaterialTreemapBreadcrumbItem({
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
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: isCurrent,

      child: TextButton(
        onPressed: isCurrent ? null : onPressed,
        style: buttonStyle,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : animationDuration,
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
            semanticsLabel: semanticLabel ?? label,
            maxLines: maxLines,
            overflow: overflow,
            style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    ),
  );
}
