/// Controls text visibility and reserved space inside expanded parent tiles.
final class TreemapParentLabelConfig {
  const TreemapParentLabelConfig({
    this.showTitle = true,
    this.showValue = true,
    this.height,
  }) : assert(height == null || (height >= 0 && height < double.infinity));

  final bool showTitle;
  final bool showValue;

  /// Total header height, including label padding and spacing, in logical pixels.
  ///
  /// Null reserves one normally styled line per enabled part, padding, and the
  /// label layer's title/value spacing when both parts are enabled.
  /// Custom widgets own their content and can override this allocation.
  final double? height;

  bool get enabled => showTitle || showValue;

  /// Omitted height is preserved; an explicit null restores automatic sizing.
  TreemapParentLabelConfig copyWith({
    bool? showTitle,
    bool? showValue,
    Object? height = _unspecifiedHeight,
  }) => TreemapParentLabelConfig(
    showTitle: showTitle ?? this.showTitle,
    showValue: showValue ?? this.showValue,
    height: identical(height, _unspecifiedHeight)
        ? this.height
        : (height as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapParentLabelConfig &&
      showTitle == other.showTitle &&
      showValue == other.showValue &&
      height == other.height;

  @override
  int get hashCode => Object.hash(showTitle, showValue, height);
}

const _unspecifiedHeight = Object();
