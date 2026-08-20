import 'package:flutter/widgets.dart';

/// Standard decorated shell used around tooltip contents.
class TreemapTooltipContainer extends StatelessWidget {
  const TreemapTooltipContainer({
    super.key,
    required this.child,
    this.decoration = const BoxDecoration(
      color: Color(0xE6232323),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  /// Tooltip content placed inside the shell.
  final Widget child;

  /// Decoration painted behind [child].
  final Decoration decoration;

  /// Space inserted between [decoration] and [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: decoration,
    child: Padding(padding: padding, child: child),
  );
}
