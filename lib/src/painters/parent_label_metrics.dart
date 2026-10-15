import 'package:flutter/widgets.dart';

import '../appearance/parent_label.dart';
import '../layout.dart';

/// Input-side text metrics: no geometry, formatters, builders or state styles.
double? resolveParentLabelHeight(
  BuildContext context,
  TreemapParentLabelConfig? config, {
  required TextStyle titleStyle,
  required TextStyle valueStyle,
  required EdgeInsets padding,
  double spacing = 0,
  TextDirection? textDirection,
}) {
  if (config == null || !config.enabled) return null;
  final height = config.height;
  if (height != null) {
    if (!height.isFinite || height < 0) {
      throw const TreemapLayoutException(
        'Parent label height must be finite and non-negative.',
      );
    }
    return height;
  }
  final direction = textDirection ?? Directionality.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final locale = Localizations.maybeLocaleOf(context);
  double lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final result = painter.height;
    painter.dispose();
    return result;
  }

  return padding.vertical +
      (config.showTitle ? lineHeight(titleStyle) : 0) +
      (config.showValue ? lineHeight(valueStyle) : 0) +
      (config.showTitle && config.showValue ? spacing : 0);
}
