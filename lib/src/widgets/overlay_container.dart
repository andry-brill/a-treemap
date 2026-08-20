import 'package:flutter/widgets.dart';

/// Configurable shell for breadcrumb, legend, or other overlay contents.
class TreemapOverlayContainer extends StatelessWidget {
  const TreemapOverlayContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.decoration,
  });

  /// Overlay content placed inside the shell.
  final Widget child;

  /// Space inserted around [child].
  final EdgeInsetsGeometry padding;

  /// Optional decoration painted behind the padded child.
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    Widget result = Padding(padding: padding, child: child);
    if (decoration case final decoration?) {
      result = DecoratedBox(decoration: decoration, child: result);
    }
    return result;
  }
}
