import 'package:flutter/material.dart';

/// Standard marker used to indicate the current value on a legend bar.
class TreemapLegendPointer extends StatelessWidget {
  const TreemapLegendPointer({
    super.key,
    this.symbol = '▼',
    this.dimension = 18,
    this.color,
    this.textStyle,
  }) : assert(dimension >= 0);

  /// Text glyph used as the marker.
  final String symbol;

  /// Square extent reserved for the marker.
  final double dimension;

  /// Marker color, defaulting to the theme on-surface color.
  final Color? color;

  /// Additional marker text styling.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontSize: 14, height: 1)
        .merge(textStyle)
        .copyWith(
          color:
              textStyle?.color ??
              color ??
              Theme.of(context).colorScheme.onSurface,
        );
    return SizedBox.square(
      dimension: dimension,
      child: Center(child: Text(symbol, style: style)),
    );
  }
}
