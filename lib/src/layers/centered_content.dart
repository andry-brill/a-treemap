import 'package:flutter/widgets.dart';

/// Shared allocation policy for centered widgets and canvas text.
Size? resolveCenteredContentSize(
  Size bounds, {
  required double widthFactor,
  required double heightFactor,
  required double? aspect,
  required Size? minimumSize,
}) {
  assert(
    minimumSize == null ||
        (minimumSize.width.isFinite &&
            minimumSize.width >= 0 &&
            minimumSize.height.isFinite &&
            minimumSize.height >= 0),
    'minimumSize dimensions must be finite and nonnegative.',
  );
  var width = bounds.width * widthFactor;
  var height = bounds.height * heightFactor;
  if (aspect != null && width > 0 && height > 0) {
    if (width / height > aspect) {
      width = height * aspect;
    } else {
      height = width / aspect;
    }
  }
  if (width <= 0 ||
      height <= 0 ||
      (minimumSize != null &&
          (width < minimumSize.width || height < minimumSize.height))) {
    return null;
  }
  return Size(width, height);
}
