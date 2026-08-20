import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Reuses bounded text layouts across canvas-label paint passes.
final class TreemapTextLayoutCache {
  final LinkedHashMap<_TextCacheKey, TextPainter> _entries = LinkedHashMap();
  static const _maximumEntries = 256;

  TextPainter layout({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required TextDirection direction,
    required TextScaler scaler,
    required Locale? locale,
    required String? ellipsis,
  }) {
    final key = _TextCacheKey(
      text,
      style,
      (maxWidth / 4).round(),
      maxLines,
      direction,
      scaler,
      locale,
      ellipsis,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
      maxLines: maxLines,
      ellipsis: ellipsis,
    )..layout(maxWidth: maxWidth);
    _entries[key] = painter;
    if (_entries.length > _maximumEntries) _entries.remove(_entries.keys.first);
    return painter;
  }
}

/// Identifies cached text by content, style, constraints, direction, and
/// locale.
final class _TextCacheKey {
  const _TextCacheKey(
    this.text,
    this.style,
    this.widthBucket,
    this.maxLines,
    this.direction,
    this.scaler,
    this.locale,
    this.ellipsis,
  );

  final String text;
  final TextStyle style;
  final int widthBucket;
  final int maxLines;
  final TextDirection direction;
  final TextScaler scaler;
  final Locale? locale;
  final String? ellipsis;

  @override
  bool operator ==(Object other) =>
      other is _TextCacheKey &&
      text == other.text &&
      style == other.style &&
      widthBucket == other.widthBucket &&
      maxLines == other.maxLines &&
      direction == other.direction &&
      scaler == other.scaler &&
      locale == other.locale &&
      ellipsis == other.ellipsis;

  @override
  int get hashCode => Object.hash(
    text,
    style,
    widthBucket,
    maxLines,
    direction,
    scaler,
    locale,
    ellipsis,
  );
}
