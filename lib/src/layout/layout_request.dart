part of '../layout.dart';

/// Internal geometry input, excluded from the package's public exports.
///
/// Label sizing is prepared upstream. Only the resulting numeric allocation
/// crosses this boundary, so geometry and isolate execution stay Flutter-free.
final class TreemapLayoutRequest<K> {
  const TreemapLayoutRequest({
    required this.tree,
    required this.viewport,
    this.config,
    this.focus,
    this.previous,
    this.parentHeaderHeight,
  });

  final TreemapNormalizedTree<K> tree;
  final TreemapBounds viewport;
  final TreemapLayoutConfig<K>? config;
  final TreemapFocus<K>? focus;
  final TreemapGeometrySnapshot<K>? previous;

  /// Null disables headers; zero records an empty header region.
  final double? parentHeaderHeight;

  TreemapGeometrySnapshot<K> execute(TreemapLayoutEngine<K> engine) =>
      engine._layout(this);

  Future<TreemapGeometrySnapshot<K>> executeAsync(
    TreemapLayoutEngine<K> engine, {
    bool fallbackToSynchronous = true,
  }) async {
    try {
      return await Isolate.run(() => execute(TreemapLayoutEngine<K>()));
    } on Object {
      if (!fallbackToSynchronous) rethrow;
      return execute(engine);
    }
  }
}
