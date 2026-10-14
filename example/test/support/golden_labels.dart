import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

/// Font bundled by the Flutter test environment on every host platform.
const goldenFontFamily = 'Ahem';

Paint _goldenTextPaint(Color color) => Paint()
  ..color = color
  ..isAntiAlias = false;

/// Creates canvas-label configuration with deterministic test rasterization.
///
/// Explicitly selecting Ahem avoids host font fallback, while foreground
/// paints with antialiasing disabled avoid Skia text-edge differences between
/// Windows, Linux, and macOS golden runs.
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
