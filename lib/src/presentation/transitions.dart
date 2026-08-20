import 'package:flutter/widgets.dart';

/// Explicit transition settings. A null transition means immediate updates.
final class TreemapTransitionSpec {
  const TreemapTransitionSpec({required this.duration, required this.curve});

  final Duration duration;
  final Curve curve;
}

/// Provides reusable transition specifications for explicit chart animation.
abstract final class TreemapTransitions {
  static const standard = TreemapTransitionSpec(
    duration: Duration(milliseconds: 300),
    curve: Curves.easeInOutCubic,
  );
}
