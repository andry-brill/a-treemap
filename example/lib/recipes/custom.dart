import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A complete recipe using only design-neutral Flutter APIs.
Widget customTreemapBreadcrumb(
  BuildContext context,
  TreemapPathEntry<Object?> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => CustomTreemapBreadcrumbItem(
  label: entry.label ?? entry.key.sourceKey?.toString() ?? 'Other',
  isCurrent: isCurrent,
  onPressed: onPressed,
);

Widget customTreemapLegendTitle(BuildContext context, String title) =>
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold));

Widget customTreemapLegendLabel(
  BuildContext context,
  TreemapLegendEntry entry,
) => Text(entry.label);

Widget customTreemapLegendPointer(
  BuildContext context,
  Color color,
  double fraction,
) => TreemapLegendPointer(
  color: DefaultTextStyle.of(context).style.color ?? const Color(0xFF202020),
);

Widget customTreemapTooltip(BuildContext context, Widget child) =>
    TreemapTooltipContainer(
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
        child: child,
      ),
    );

/// Explicit pointer, keyboard, focus, and accessibility behavior without buttons
/// from a design-system package. Copy and adapt the decoration to your app.
class CustomTreemapBreadcrumbItem extends StatefulWidget {
  const CustomTreemapBreadcrumbItem({
    super.key,
    required this.label,
    required this.isCurrent,
    this.onPressed,
  });
  final String label;
  final bool isCurrent;
  final VoidCallback? onPressed;

  @override
  State<CustomTreemapBreadcrumbItem> createState() => _CustomBreadcrumbState();
}

class _CustomBreadcrumbState extends State<CustomTreemapBreadcrumbItem> {
  bool _focused = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isCurrent && widget.onPressed != null;
    final color =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF202020);
    return FocusableActionDetector(
      focusNode: _focusNode,
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (enabled) widget.onPressed!();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.isCurrent,
        label: widget.label,
        onTap: enabled ? widget.onPressed : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled
              ? () {
                  _focusNode.requestFocus();
                  widget.onPressed!();
                }
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: _focused && enabled ? color : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: ExcludeSemantics(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: widget.isCurrent
                        ? FontWeight.bold
                        : FontWeight.normal,
                    decoration: widget.isCurrent
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
