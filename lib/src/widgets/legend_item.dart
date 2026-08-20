import 'package:flutter/widgets.dart';

/// Standard color swatch and label used by discrete legends.
class TreemapLegendItem extends StatelessWidget {
  const TreemapLegendItem({
    super.key,
    required this.color,
    required this.label,
    this.swatchSize = 12,
    this.spacing = 4,
    this.swatchBorderRadius = const BorderRadius.all(Radius.circular(2)),
    this.swatchBorder,
  }) : assert(swatchSize >= 0),
       assert(spacing >= 0);

  /// Color displayed by the swatch.
  final Color color;

  /// Label displayed after the swatch.
  final Widget label;

  /// Square extent of the swatch.
  final double swatchSize;

  /// Horizontal gap between the swatch and [label].
  final double spacing;

  /// Corner shape of the swatch.
  final BorderRadiusGeometry swatchBorderRadius;

  /// Optional border drawn around the swatch.
  final BoxBorder? swatchBorder;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: swatchBorder,
          borderRadius: swatchBorderRadius,
        ),
        child: SizedBox.square(dimension: swatchSize),
      ),
      SizedBox(width: spacing),
      label,
    ],
  );
}
