import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'geometry.dart';
import 'layout.dart';
import 'model.dart';

/// Describes the outcome of a controller navigation command.
enum TreemapCommandStatus {
  /// The command changed controller state successfully.
  completed,

  /// The requested state was already active.
  unchanged,

  /// No usable target key was supplied or found.
  missingKey,

  /// The target has no children and therefore cannot become the focus.
  leafCannotBeFocused,

  /// The current focus has no parent to navigate to.
  noAncestor,
}

/// Returns a typed command outcome with optional target and explanation.
final class TreemapCommandResult<K> {
  const TreemapCommandResult(this.status, {this.key, this.message});

  final TreemapCommandStatus status;
  final TreemapKey<K>? key;
  final String? message;
  bool get succeeded => status == TreemapCommandStatus.completed;
}

/// Combines node geometry and navigation path for callbacks and visual layers.
final class TreemapNodeDetails<K> {
  TreemapNodeDetails({
    required this.geometry,
    required Iterable<TreemapPathEntry<K>> path,
  }) : path = List.unmodifiable(path);

  final TreemapGeometryNode<K> geometry;
  final List<TreemapPathEntry<K>> path;

  TreemapKey<K> get key => geometry.key;
  TreemapNode<K>? get node => geometry.node;
  List<TreemapNode<K>> get aggregateMembers => geometry.aggregateMembers;
  TreemapBounds get bounds => geometry.bounds;

  /// Reserved label region for an expanded parent, including label padding.
  TreemapBounds? get headerBounds => geometry.headerBounds;
  double get weight => geometry.weight;
  int get depth => geometry.depth;
  String? get label => geometry.label;

  /// Direct color or color-scale input retained from the source node.
  Object? get color => node?.color;
  bool get isAggregate => geometry.isAggregate;
  bool get hasChildren => geometry.hasChildren;
}

/// Owns navigation and uncontrolled selection against a prepared source tree.
final class TreemapController<K> extends ChangeNotifier
    with DiagnosticableTreeMixin {
  TreemapController({this.maximumSelections = 1})
    : assert(maximumSelections == null || maximumSelections > 0);

  final int? maximumSelections;
  TreemapNormalizedTree<K>? _tree;
  TreemapFocus<K>? _focus;
  List<TreemapPathEntry<K>> _path = const [];
  final LinkedHashSet<TreemapKey<K>> _selected = LinkedHashSet();
  TreemapKey<K>? get focusKey => _focus?.key;
  List<TreemapPathEntry<K>> get currentPath => List.unmodifiable(_path);
  Set<TreemapKey<K>> get selectedEntries => Set.unmodifiable(_selected);
  Set<K> get selectedKeys => Set.unmodifiable(
    _selected.where((key) => key.isSource).map((key) => key.sourceKey as K),
  );
  bool get canZoomOut => _path.length > 1;

  TreemapFocus<K>? get layoutFocus => _focus;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TreemapKey<K>?>('focusKey', focusKey))
      ..add(IntProperty('pathLength', _path.length))
      ..add(IntProperty('selectionCount', _selected.length))
      ..add(IntProperty('nodeCount', _tree?.nodes.length ?? 0));
  }

  /// Synchronizes state after a caller supplies a new immutable tree.
  void synchronize(TreemapNormalizedTree<K> next, {bool notify = true}) {
    if (identical(next, _tree)) return;
    final oldFocus = _focus;
    final previousTree = _tree;
    _tree = next;
    if (oldFocus?.key.isAggregate == true) {
      final survivingMembers = oldFocus!.aggregateMembers
          .map((node) => next.nodes[node.key])
          .whereType<TreemapNode<K>>()
          .toList();
      final parent = previousTree?.parents[oldFocus.aggregateMembers.first.key];
      if (parent != null &&
          survivingMembers.isNotEmpty &&
          survivingMembers.every((node) => next.parents[node.key] == parent)) {
        _setAggregateFocus(oldFocus.key, survivingMembers);
      } else {
        _fallbackToNearestAncestor(next, oldFocus.path);
      }
    } else {
      final sourceKey = oldFocus?.key.sourceKey;
      if (sourceKey != null &&
          (next.nodes[sourceKey]?.children.isNotEmpty == true ||
              sourceKey == next.root.key)) {
        _setSourceFocus(next.nodes[sourceKey]!, notify: false);
      } else {
        _fallbackToNearestAncestor(next, _path);
      }
    }

    _selected.removeWhere((key) {
      if (key.isSource) return !next.nodes.containsKey(key.sourceKey);
      return true;
    });
    if (notify) {
      notifyListeners();
    }
  }

  TreemapCommandResult<K> zoomTo(K key) {
    final node = _tree?.nodes[key];
    if (node == null) {
      return TreemapCommandResult(
        TreemapCommandStatus.missingKey,
        key: TreemapKey.source(key),
        message: 'No node with key $key exists in the current tree.',
      );
    }
    if (node.children.isEmpty) {
      return TreemapCommandResult(
        TreemapCommandStatus.leafCannotBeFocused,
        key: TreemapKey.source(key),
        message: 'Leaf nodes cannot be used as a drill-down focus.',
      );
    }
    if (_focus?.key == TreemapKey<K>.source(key)) {
      return TreemapCommandResult(
        TreemapCommandStatus.unchanged,
        key: TreemapKey.source(key),
      );
    }
    _setSourceFocus(node);
    return TreemapCommandResult(
      TreemapCommandStatus.completed,
      key: TreemapKey.source(key),
    );
  }

  /// Reveals source members of a generated aggregate without retaining geometry.
  TreemapCommandResult<K> revealAggregate(
    TreemapKey<K> key, {
    required Iterable<K> memberKeys,
  }) {
    final keys = memberKeys.toSet();
    final members = keys
        .map((key) => _tree?.nodes[key])
        .whereType<TreemapNode<K>>()
        .toList();
    final parents = members.map((node) => _tree!.parents[node.key]).toSet();
    if (!key.isAggregate ||
        members.isEmpty ||
        members.length != keys.length ||
        parents.length != 1 ||
        parents.single == null) {
      return TreemapCommandResult(
        TreemapCommandStatus.missingKey,
        key: key,
        message: 'An aggregate requires valid sibling source member keys.',
      );
    }
    _setAggregateFocus(key, members);
    notifyListeners();
    return TreemapCommandResult(TreemapCommandStatus.completed, key: key);
  }

  TreemapCommandResult<K> zoomOut() {
    if (_path.length <= 1) {
      return const TreemapCommandResult(TreemapCommandStatus.noAncestor);
    }
    final target = _path[_path.length - 2];
    if (target.key.isSource) return zoomTo(target.key.sourceKey as K);
    return reset();
  }

  TreemapCommandResult<K> reset() {
    final root = _tree?.root;
    if (root == null) {
      return const TreemapCommandResult(TreemapCommandStatus.missingKey);
    }
    if (_focus?.key == TreemapKey<K>.source(root.key)) {
      return TreemapCommandResult(
        TreemapCommandStatus.unchanged,
        key: TreemapKey.source(root.key),
      );
    }
    _setSourceFocus(root);
    return TreemapCommandResult(
      TreemapCommandStatus.completed,
      key: TreemapKey.source(root.key),
    );
  }

  void select(K key, {bool toggle = false}) {
    selectEntry(TreemapKey.source(key), toggle: toggle);
  }

  void selectEntry(TreemapKey<K> key, {bool toggle = false}) {
    if (key.isSource && !(_tree?.nodes.containsKey(key.sourceKey) ?? false)) {
      return;
    }
    if (toggle && _selected.remove(key)) {
      notifyListeners();
      return;
    }
    if (_selected.contains(key)) return;
    if (maximumSelections != null) {
      while (_selected.length >= maximumSelections!) {
        _selected.remove(_selected.first);
      }
    }
    _selected.add(key);
    notifyListeners();
  }

  void setSelection(Iterable<TreemapKey<K>> keys) {
    final next = LinkedHashSet<TreemapKey<K>>.of(
      keys.where(
        (key) =>
            !key.isSource || (_tree?.nodes.containsKey(key.sourceKey) ?? false),
      ),
    );
    if (maximumSelections != null && next.length > maximumSelections!) {
      next.removeAll(next.take(next.length - maximumSelections!).toList());
    }
    if (setEquals(next, _selected)) return;
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  List<TreemapPathEntry<K>> _sourcePath(K key) => List.unmodifiable(
    _tree!
        .pathTo(key)
        .indexed
        .map(
          (entry) => TreemapPathEntry(
            key: TreemapKey.source(entry.$2.key),
            label: entry.$2.label,
            depth: entry.$1,
          ),
        ),
  );

  void _setAggregateFocus(TreemapKey<K> key, List<TreemapNode<K>> members) {
    // Rebuild source ancestry from the current tree, including changed labels
    // and depths. A revealed aggregate belongs to its source members' parent,
    // even when it was activated from a more distant chart focus.
    final path = _sourcePath(_tree!.parents[members.first.key] as K);
    _path = List.unmodifiable([
      ...path,
      TreemapPathEntry(key: key, depth: path.length),
    ]);
    _focus = TreemapFocus.aggregate(key: key, members: members, path: _path);
  }

  void _setSourceFocus(TreemapNode<K> node, {bool notify = true}) {
    _path = _sourcePath(node.key);
    _focus = TreemapFocus.source(node.key);
    if (notify) notifyListeners();
  }

  void _fallbackToNearestAncestor(
    TreemapNormalizedTree<K> tree,
    Iterable<TreemapPathEntry<K>> previousPath,
  ) {
    for (final entry in previousPath.toList().reversed) {
      final key = entry.key.sourceKey;
      if (key != null && tree.nodes[key]?.children.isNotEmpty == true) {
        _setSourceFocus(tree.nodes[key]!, notify: false);
        return;
      }
    }
    _setSourceFocus(tree.root, notify: false);
  }
}
