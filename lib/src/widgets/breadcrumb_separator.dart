import 'package:flutter/widgets.dart';

/// Standard centered separator used between breadcrumb items.
class TreemapBreadcrumbSeparator extends StatelessWidget {
  const TreemapBreadcrumbSeparator({
    super.key,
    this.label = '›',
    this.dimension = 16,
    this.textStyle = const TextStyle(fontSize: 16, height: 1),
  }) : assert(dimension >= 0);

  /// Text displayed between adjacent breadcrumbs.
  final String label;

  /// Square extent reserved for the separator.
  final double dimension;

  /// Style applied to [label].
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: Center(child: Text(label, style: textStyle)),
  );
}
