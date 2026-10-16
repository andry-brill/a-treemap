import 'package:flutter/widgets.dart';

enum _Edge { automatic, top, bottom, none }

/// Space kept clear for labels before centered content is allocated.
///
/// Automatic canvas reservations use the complete measured text block, padding
/// and spacing. An explicit [height] includes padding, remains reserved even
/// when text is omitted, and can keep allocations stable across label changes.
/// Widget labels require an explicit height because their content is arbitrary.
final class TreemapLabelReservation {
  /// Reserve for top/bottom aligned canvas labels; middle labels stay overlays.
  const TreemapLabelReservation.automatic()
    : _edge = _Edge.automatic,
      height = null;

  /// Dock at the top. Null [height] measures canvas labels automatically.
  const TreemapLabelReservation.top({this.height})
    : _edge = _Edge.top,
      assert(height == null || (height >= 0 && height < double.infinity));

  /// Dock at the bottom. Null [height] measures canvas labels automatically.
  const TreemapLabelReservation.bottom({this.height})
    : _edge = _Edge.bottom,
      assert(height == null || (height >= 0 && height < double.infinity));

  /// Keep labels as overlays without reserving additional content space.
  const TreemapLabelReservation.none() : _edge = _Edge.none, height = null;

  final _Edge _edge;
  final double? height;
}

/// Internal helpers shared by canvas and widget label preparation.
Alignment reservationAlignment(
  TreemapLabelReservation reservation,
  Alignment alignment,
) => switch (reservation._edge) {
  _Edge.top => Alignment(alignment.x, -1),
  _Edge.bottom => Alignment(alignment.x, 1),
  _ => alignment,
};

Rect? labelReservationBounds(
  Rect bounds,
  TreemapLabelReservation reservation,
  Alignment alignment,
  double measuredHeight,
) {
  final resolved = reservationAlignment(reservation, alignment);
  if (!hasLabelReservation(reservation, alignment)) return null;
  final height = (reservation.height ?? measuredHeight).clamp(
    0.0,
    bounds.height,
  );
  return Rect.fromLTWH(
    bounds.left,
    resolved.y == -1 ? bounds.top : bounds.bottom - height,
    bounds.width,
    height,
  );
}

bool hasLabelReservation(
  TreemapLabelReservation reservation,
  Alignment alignment,
) =>
    reservation._edge != _Edge.none &&
    reservationAlignment(reservation, alignment).y.abs() == 1;

Rect remainingLabelBounds(Rect bounds, Rect reservation, Alignment alignment) =>
    alignment.y == -1
    ? Rect.fromLTRB(
        bounds.left,
        reservation.bottom,
        bounds.right,
        bounds.bottom,
      )
    : Rect.fromLTRB(bounds.left, bounds.top, bounds.right, reservation.top);
