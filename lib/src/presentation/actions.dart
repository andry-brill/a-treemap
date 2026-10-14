import '../controller.dart';
import '../model.dart';

/// Commands accepted by a chart. All identities are resolved against current
/// source or target geometry when a command executes.
abstract interface class TreemapActions<K> {
  void activate(TreemapKey<K> key, {bool zoomOutRequested = false});
  void hover(TreemapKey<K>? key);
  void focus(TreemapKey<K>? key);
  void select(TreemapKey<K> key, {bool toggle = false});
  void setSelection(Iterable<TreemapKey<K>> keys);
  void clearSelection();
  TreemapCommandResult<K> zoomTo(K key);
  TreemapCommandResult<K> zoomOut();
  TreemapCommandResult<K> reset();
  TreemapCommandResult<K> revealAggregate(TreemapKey<K> key);
}
