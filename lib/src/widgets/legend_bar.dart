import 'package:flutter/widgets.dart';

/// Standard directional color bar used by bar legends.
class TreemapLegendBar extends StatelessWidget {
  const TreemapLegendBar({
    super.key,
    required this.colors,
    required this.direction,
    this.borderRadius = const BorderRadius.all(Radius.circular(3)),
    this.stops,
    this.tileMode = TileMode.clamp,
  }) : assert(colors.length >= 2),
       assert(stops == null || stops.length == colors.length);

  /// Ordered colors painted across the bar.
  final List<Color> colors;

  /// Axis along which colors progress from first to last.
  final Axis direction;

  /// Corner shape of the bar.
  final BorderRadiusGeometry borderRadius;

  /// Optional normalized position for each color.
  final List<double>? stops;

  /// How the gradient paints beyond its start and end positions.
  final TileMode tileMode;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: direction == Axis.horizontal
            ? Alignment.centerLeft
            : Alignment.bottomCenter,
        end: direction == Axis.horizontal
            ? Alignment.centerRight
            : Alignment.topCenter,
        colors: colors,
        stops: stops,
        tileMode: tileMode,
      ),
      borderRadius: borderRadius,
    ),
  );
}
