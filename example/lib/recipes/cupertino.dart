import 'package:any_treemap/any_treemap.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

/// Copy this file into your app and supply these functions to core configs.
Widget cupertinoTreemapBreadcrumb(
  BuildContext context,
  TreemapPathEntry<Object?> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => CupertinoTreemapBreadcrumbItem(
  label: entry.label ?? entry.key.sourceKey?.toString() ?? 'Other',
  isCurrent: isCurrent,
  onPressed: onPressed,
);

Widget cupertinoTreemapLegendTitle(BuildContext context, String title) => Text(
  title,
  style: CupertinoTheme.of(context).textTheme.textStyle
      .copyWith(fontWeight: FontWeight.w600),
);

Widget cupertinoTreemapLegendLabel(
  BuildContext context,
  TreemapLegendEntry entry,
) => Text(entry.label, style: CupertinoTheme.of(context).textTheme.textStyle);

Widget cupertinoTreemapLegendPointer(
  BuildContext context,
  Color color,
  double fraction,
) => TreemapLegendPointer(
  color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
);

Widget cupertinoTreemapTooltip(BuildContext context, Widget child) =>
    TreemapTooltipContainer(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemBackground,
          context,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.separator,
            context,
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        ),
        child: child,
      ),
    );

/// Application-owned Cupertino button; no Material theme or ancestor needed.
class CupertinoTreemapBreadcrumbItem extends StatelessWidget {
  const CupertinoTreemapBreadcrumbItem({
    super.key,
    required this.label,
    required this.isCurrent,
    this.onPressed,
    this.semanticLabel,
    this.animationDuration = const Duration(milliseconds: 180),
    this.animationCurve = Curves.linear,
    this.indicatorColor,
    this.inactiveIndicatorColor = const Color(0x00000000),
    this.indicatorWidth = 2,
    this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : assert(indicatorWidth >= 0),
       assert(maxLines > 0);

  final String label;
  final bool isCurrent;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Duration animationDuration;
  final Curve animationCurve;
  final Color? indicatorColor;
  final Color inactiveIndicatorColor;
  final double indicatorWidth;
  final TextStyle? textStyle;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final enabled = !isCurrent && onPressed != null;
    return Semantics(
      selected: isCurrent,
      enabled: enabled,
      child: CupertinoButton(
        onPressed: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : animationDuration,
          curve: animationCurve,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoDynamicColor.resolve(
                  isCurrent
                      ? indicatorColor ?? theme.primaryColor
                      : inactiveIndicatorColor,
                  context,
                ),
                width: indicatorWidth,
              ),
            ),
          ),
          child: Text(
            label,
            semanticsLabel: semanticLabel ?? label,
            maxLines: maxLines,
            overflow: overflow,
            style:
                textStyle ??
                theme.textTheme.textStyle.copyWith(
                  color: enabled
                      ? theme.primaryColor
                      : CupertinoDynamicColor.resolve(
                          isCurrent
                              ? CupertinoColors.label
                              : CupertinoColors.inactiveGray,
                          context,
                        ),
                ),
          ),
        ),
      ),
    );
  }
}
