import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../appearance/color_scale.dart';
import '../controller.dart';
import '../geometry.dart';
import '../model.dart';
import 'actions.dart';

/// One immutable chart output, consumed by viewport layers and surrounding UI.
/// Target geometry owns interaction and visible domains; displayed geometry
/// owns painting, including outgoing animation nodes.
@immutable
final class TreemapPresentationState<K> {
  TreemapPresentationState._({
    required this.targetSnapshot,
    required this.displayedSnapshot,
    required this.focusKey,
    required Iterable<TreemapPathEntry<K>> currentPath,
    required Iterable<TreemapKey<K>> selectedEntries,
    required this.hoveredKey,
    required this.hoveredColor,
    required this.keyboardFocusedKey,
    required this.tooltipKey,
    required this.isAnimating,
    required this.interactionEnabled,
    required this.details,
    required this.targetDetails,
    required this.visibleLeafNodes,
    required Map<TreemapKey<K>, Set<TreemapVisualState>> states,
  }) : currentPath = List.unmodifiable(currentPath),
       selectedEntries = Set.unmodifiable(selectedEntries),
       states = Map.unmodifiable(states);

  /// Projects an already prepared source and optional layout. This uses the
  /// same projection as a chart, without creating or changing a controller.
  factory TreemapPresentationState.fromData({
    required TreemapNormalizedTree<K> tree,
    TreemapGeometrySnapshot<K>? targetSnapshot,
    TreemapGeometrySnapshot<K>? displayedSnapshot,
    Iterable<TreemapKey<K>> selectedEntries = const [],
    TreemapKey<K>? hoveredKey,
    TreemapKey<K>? keyboardFocusedKey,
    TreemapKey<K>? tooltipKey,
    bool interactionEnabled = true,
    bool isAnimating = false,
  }) => TreemapPresentationProjector<K>().project(
    tree: tree,
    target: targetSnapshot,
    frame: displayedSnapshot ?? targetSnapshot,
    selectedEntries: selectedEntries,
    hoveredKey: hoveredKey,
    keyboardFocusedKey: keyboardFocusedKey,
    tooltipKey: tooltipKey,
    interactionEnabled: interactionEnabled,
    isAnimating: isAnimating,
  );

  final TreemapGeometrySnapshot<K>? targetSnapshot;
  final TreemapGeometrySnapshot<K>? displayedSnapshot;
  final TreemapKey<K>? focusKey;
  final List<TreemapPathEntry<K>> currentPath;
  bool get canZoomOut => currentPath.length > 1;
  final Set<TreemapKey<K>> selectedEntries;
  final TreemapKey<K>? hoveredKey;

  /// The hovered destination node's color input or normalized weight.
  final Object? hoveredColor;
  final TreemapKey<K>? keyboardFocusedKey;
  final TreemapKey<K>? tooltipKey;
  final bool isAnimating;
  final bool interactionEnabled;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> targetDetails;
  final Map<TreemapKey<K>, Set<TreemapVisualState>> states;
  final List<TreemapGeometryNode<K>> visibleLeafNodes;

  Set<TreemapVisualState> statesFor(TreemapKey<K> key) =>
      states[key] ?? const {};
  TreemapNodeDetails<K>? get tooltipDetails =>
      details[tooltipKey] ?? targetDetails[tooltipKey];

  /// Resolves from cached source/target extrema. Memoization lives outside this
  /// immutable value and is shared across frames with the same domains.
  TreemapColorScale resolveColorScale(TreemapColorScale scale) =>
      _scaleResolutions[this]!.resolve(scale);
}

/// Immutable interaction states available to presentation implementations.
enum TreemapVisualState { hovered, selected, focused, disabled }

/// Supplies chart output and its command boundary to descendants. Publication
/// changes this scope after the frame without notifying the controller.
class TreemapPresentationScope<K>
    extends InheritedNotifier<ValueListenable<TreemapPresentationState<K>>> {
  const TreemapPresentationScope({
    super.key,
    required ValueListenable<TreemapPresentationState<K>> presentation,
    this.actions,
    required super.child,
  }) : super(notifier: presentation);

  final TreemapActions<K>? actions;

  static TreemapPresentationState<T>? maybeOf<T>(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TreemapPresentationScope<T>>()
          ?.notifier
          ?.value;

  static TreemapPresentationState<T> of<T>(BuildContext context) {
    final state = maybeOf<T>(context);
    if (state == null) {
      throw FlutterError(
        'No TreemapPresentationScope<$T> found in this context.',
      );
    }
    return state;
  }

  static TreemapActions<T>? maybeActionsOf<T>(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TreemapPresentationScope<T>>()
      ?.actions;

  static TreemapActions<T> actionsOf<T>(BuildContext context) {
    final actions = maybeActionsOf<T>(context);
    if (actions == null) {
      throw FlutterError('No chart actions for TreemapPresentationScope<$T>.');
    }
    return actions;
  }
}

final _scaleResolutions = Expando<_ScaleResolution>();
final _geometryViews = Expando<Object>();

/// Internal pure projection with reusable geometry and scale computations.
final class TreemapPresentationProjector<K> {
  TreemapNormalizedTree<K>? _tree;
  TreemapGeometrySnapshot<K>? _target;
  _ScaleResolution? _scales;

  Map<TreemapKey<K>, TreemapNodeDetails<K>> detailsFor(
    TreemapGeometrySnapshot<K> snapshot,
  ) => _geometryFor(snapshot).details;

  TreemapPresentationState<K> project({
    required TreemapNormalizedTree<K> tree,
    required TreemapGeometrySnapshot<K>? target,
    required TreemapGeometrySnapshot<K>? frame,
    Iterable<TreemapKey<K>> selectedEntries = const [],
    TreemapKey<K>? hoveredKey,
    TreemapKey<K>? keyboardFocusedKey,
    TreemapKey<K>? tooltipKey,
    bool interactionEnabled = true,
    bool isAnimating = false,
    List<TreemapPathEntry<K>>? currentPath,
    TreemapKey<K>? focusKey,
  }) {
    final targetView = _geometryFor(target);
    final frameView = _geometryFor(frame);
    TreemapKey<K>? visible(TreemapKey<K>? key) =>
        interactionEnabled && targetView.visibleKeys.contains(key) ? key : null;
    hoveredKey = visible(hoveredKey);
    keyboardFocusedKey = visible(keyboardFocusedKey);
    tooltipKey = visible(tooltipKey);
    final selection = Set<TreemapKey<K>>.unmodifiable(
      selectedEntries.where(
        (key) => !key.isSource || tree.nodes.containsKey(key.sourceKey),
      ),
    );
    if (!identical(tree, _tree) || !identical(target, _target)) {
      final global = tree.globalColorDomain;
      final visible = _extents(
        target?.visibleNodes.map((node) => node.node?.color ?? node.weight) ??
            const [],
      );
      if (_scales == null ||
          _scales!.global != global ||
          _scales!.visible != visible) {
        _scales = _ScaleResolution(global, visible);
      }
      _tree = tree;
      _target = target;
    }
    final path =
        currentPath ??
        (target?.path.isNotEmpty == true
            ? target!.path
            : [
                TreemapPathEntry(
                  key: TreemapKey<K>.source(tree.root.key),
                  label: tree.root.label,
                  depth: 0,
                ),
              ]);
    final hover = targetView.details[hoveredKey];
    final state = TreemapPresentationState<K>._(
      targetSnapshot: target,
      displayedSnapshot: frame,
      focusKey:
          focusKey ?? target?.focusKey ?? TreemapKey<K>.source(tree.root.key),
      currentPath: path,
      selectedEntries: selection,
      hoveredKey: hoveredKey,
      hoveredColor: hover == null ? null : hover.color ?? hover.weight,
      keyboardFocusedKey: keyboardFocusedKey,
      tooltipKey: tooltipKey,
      isAnimating: isAnimating,
      interactionEnabled: interactionEnabled,
      details: frameView.details,
      targetDetails: targetView.details,
      visibleLeafNodes: frameView.leaves,
      states: {
        for (final node in frame?.nodes ?? <TreemapGeometryNode<K>>[])
          node.key: Set<TreemapVisualState>.unmodifiable({
            if (node.key == hoveredKey) TreemapVisualState.hovered,
            if (selection.contains(node.key)) TreemapVisualState.selected,
            if (node.key == keyboardFocusedKey) TreemapVisualState.focused,
            if (!interactionEnabled) TreemapVisualState.disabled,
          }),
      },
    );
    _scaleResolutions[state] = _scales;
    return state;
  }

  _GeometryView<K> _geometryFor(TreemapGeometrySnapshot<K>? snapshot) {
    if (snapshot == null) return _GeometryView<K>.empty();
    return (_geometryViews[snapshot] ??= _GeometryView<K>(snapshot))
        as _GeometryView<K>;
  }
}

final class _GeometryView<K> {
  _GeometryView.empty()
    : details = const {},
      leaves = const [],
      visibleKeys = const {};

  _GeometryView(TreemapGeometrySnapshot<K> snapshot) {
    final paths = <TreemapKey<K>, List<TreemapPathEntry<K>>>{};
    List<TreemapPathEntry<K>> pathFor(TreemapGeometryNode<K> node) {
      final cached = paths[node.key];
      if (cached != null) return cached;
      final suffix = <TreemapPathEntry<K>>[];
      TreemapGeometryNode<K>? cursor = node;
      while (cursor != null) {
        suffix.add(
          TreemapPathEntry(
            key: cursor.key,
            label: cursor.label,
            depth: cursor.depth,
          ),
        );
        cursor = snapshot.index[cursor.parentKey];
      }
      final result = <TreemapPathEntry<K>>[...snapshot.path];
      final seen = result.map((entry) => entry.key).toSet();
      for (final entry in suffix.reversed) {
        if (seen.add(entry.key)) result.add(entry);
      }
      return paths[node.key] = List.unmodifiable(result);
    }

    details = Map.unmodifiable({
      for (final node in snapshot.nodes)
        node.key: TreemapNodeDetails(geometry: node, path: pathFor(node)),
    });
    final visible = snapshot.visibleNodes.toList(growable: false);
    visibleKeys = Set.unmodifiable(visible.map((node) => node.key));
    final parents = visible.map((node) => node.parentKey).toSet();
    leaves = List.unmodifiable(
      visible.where((node) => !parents.contains(node.key)),
    );
  }

  late final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  late final List<TreemapGeometryNode<K>> leaves;
  late final Set<TreemapKey<K>> visibleKeys;
}

final class _ScaleResolution {
  _ScaleResolution(this.global, this.visible);
  final (double, double)? global;
  final (double, double)? visible;
  final Map<TreemapColorScale, TreemapColorScale> _cache = HashMap.identity();

  TreemapColorScale resolve(TreemapColorScale scale) => _cache.putIfAbsent(
    scale,
    () {
      final scope = switch (scale) {
        TreemapInterpolatedColorScale(:final domainScope) => domainScope,
        TreemapSaturationColorScale(:final domainScope) => domainScope,
        _ => TreemapColorDomainScope.global,
      };
      final domain = scope == TreemapColorDomainScope.global ? global : visible;
      return scale.resolveDomain(
        domain == null ? const [] : [domain.$1, domain.$2],
      );
    },
  );
}

(double, double)? _extents(Iterable<Object?> values) {
  double? minimum;
  double? maximum;
  for (final value in values) {
    if (value is! num || !value.isFinite) continue;
    final number = value.toDouble();
    if (minimum == null || number < minimum) minimum = number;
    if (maximum == null || number > maximum) maximum = number;
  }
  return minimum == null ? null : (minimum, maximum!);
}
