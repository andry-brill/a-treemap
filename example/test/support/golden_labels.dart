import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

/// Font bundled by the Flutter test environment.
const goldenFontFamily = 'Ahem';

Paint _goldenTextPaint(Color color) => Paint()
  ..color = color
  ..isAntiAlias = false;

/// Creates canvas-label configuration with deterministic test rasterization.
///
/// Explicit Ahem and non-antialiased foreground paints keep these isolated
/// label fixtures deterministic for the pinned Windows golden environment.
TreemapLabelConfig<K> goldenLabelConfig<K>() => TreemapLabelConfig<K>(
  titleStyle: TextStyle(
    fontFamily: goldenFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    foreground: _goldenTextPaint(Colors.white),
  ),
  valueStyle: TextStyle(
    fontFamily: goldenFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    foreground: _goldenTextPaint(const Color(0xD1FFFFFF)),
  ),
);
