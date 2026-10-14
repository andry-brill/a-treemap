import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../appearance/color_scale.dart';
import '../geometry.dart';
import '../model.dart';

/// Immutable chart output shared by visual layers and surrounding content.
///
/// Visible color domains describe [targetSnapshot], including during animation;
/// global domains describe the full source hierarchy.
/// Navigation and selection remain on the chart's controller.
@immutable
final class TreemapPresentationState<K> {
  const TreemapPresentationState._({
    required this.targetSnapshot,
    required this.displayedSnapshot,
    required this.hoveredKey,
    required this.hoveredColor,
    required (double, double)? globalDomain,
    required (double, double)? visibleDomain,
  }) : _globalDomain = globalDomain,
       _visibleDomain = visibleDomain;

  /// Resolves presentation data outside a chart, without changing a controller.
  /// Supply a destination layout to resolve visible bounds and hover inputs.
  factory TreemapPresentationState.fromData({
    required TreemapNode<K> root,
    TreemapGeometrySnapshot<K>? targetSnapshot,
    TreemapKey<K>? hoveredKey,
  }) => TreemapPresentationState._(
    targetSnapshot: targetSnapshot,
    displayedSnapshot: targetSnapshot,
    hoveredKey: hoveredKey,
    hoveredColor: _hoverInput(targetSnapshot, hoveredKey),
    globalDomain: _sourceDomain(root),
    visibleDomain: _snapshotDomain(targetSnapshot),
  );

  /// The destination layout; null until the chart receives viewport constraints.
  final TreemapGeometrySnapshot<K>? targetSnapshot;

  /// The currently painted frame, which can contain outgoing animation nodes.
  final TreemapGeometrySnapshot<K>? displayedSnapshot;

  final TreemapKey<K>? hoveredKey;

  /// Effective input from the hovered destination node, or null if it is hidden.
  /// Uses the normalized weight when the source node has no color input.
  final Object? hoveredColor;

  final (double, double)? _globalDomain;
  final (double, double)? _visibleDomain;

  /// Resolves a scale from cached extrema without rescanning the hierarchy.
  /// Explicit scales and custom implementations pass through unchanged.
  TreemapColorScale resolveColorScale(TreemapColorScale scale) {
    final scope = switch (scale) {
      TreemapInterpolatedColorScale(:final domainScope) => domainScope,
      TreemapSaturationColorScale(:final domainScope) => domainScope,
      _ => TreemapColorDomainScope.global,
    };
    final domain = scope == TreemapColorDomainScope.global
        ? _globalDomain
        : _visibleDomain;
    return scale.resolveDomain(
      domain == null ? const [] : [domain.$1, domain.$2],
    );
  }
}

/// Supplies chart-owned presentation state to descendants, including chrome.
/// Reading this scope subscribes only that consumer to presentation changes.
class TreemapPresentationScope<K>
    extends InheritedNotifier<ValueListenable<TreemapPresentationState<K>>> {
  const TreemapPresentationScope({
    super.key,
    required ValueListenable<TreemapPresentationState<K>> presentation,
    required super.child,
  }) : super(notifier: presentation);

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
}

/// Internal mutable owner. The chart writes computation results here; only
/// presentation consumers are notified. It never references a controller.
final class TreemapPresentationOwner<K> extends ChangeNotifier
    implements ValueListenable<TreemapPresentationState<K>> {
  TreemapPresentationOwner(TreemapNode<K> root)
    : _root = root,
      _value = TreemapPresentationState.fromData(root: root) {
    _globalDomain = _value._globalDomain;
  }

  TreemapNode<K> _root;
  late (double, double)? _globalDomain;
  (double, double)? _visibleDomain;
  TreemapGeometrySnapshot<K>? targetSnapshot;
  TreemapGeometrySnapshot<K>? transitionOrigin;
  TreemapPresentationState<K> _value;
  bool _scheduled = false;
  bool _disposed = false;
  ValueChanged<TreemapPresentationState<K>>? onChanged;

  @override
  TreemapPresentationState<K> get value => _value;

  void updateSource(TreemapNode<K> root) {
    if (identical(root, _root)) return;
    _root = root;
    _globalDomain = _sourceDomain(root);
  }

  void updateTarget(TreemapGeometrySnapshot<K> snapshot) {
    if (_sameSnapshot(targetSnapshot, snapshot)) return;
    targetSnapshot = snapshot;
    _visibleDomain = _snapshotDomain(snapshot);
  }

  void displayFrame(
    TreemapGeometrySnapshot<K> frame, {
    required TreemapKey<K>? hoveredKey,
  }) {
    final hoveredColor = _hoverInput(targetSnapshot, hoveredKey);
    if (identical(_value.targetSnapshot, targetSnapshot) &&
        _sameSnapshot(_value.displayedSnapshot, frame) &&
        _value._globalDomain == _globalDomain &&
        _value.hoveredKey == hoveredKey &&
        _sameInput(_value.hoveredColor, hoveredColor)) {
      return;
    }
    _value = TreemapPresentationState._(
      targetSnapshot: targetSnapshot,
      displayedSnapshot: frame,
      hoveredKey: hoveredKey,
      hoveredColor: hoveredColor,
      globalDomain: _globalDomain,
      visibleDomain: _visibleDomain,
    );
    // Layout can run during build. Publish to chrome and external observers
    // after the frame; in-viewport layers consume the new value immediately.
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      notifyListeners();
      onChanged?.call(_value);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

(double, double)? _sourceDomain<K>(TreemapNode<K> root) {
  final tree = TreemapNormalizer.normalize(root);
  return _extents(
    tree.nodes.values
        .where((node) => node.key != root.key)
        .map((node) => node.color ?? tree.totals[node.key]),
  );
}

(double, double)? _snapshotDomain<K>(TreemapGeometrySnapshot<K>? snapshot) =>
    _extents(
      snapshot?.visibleNodes.map((node) => node.node?.color ?? node.weight) ??
          const [],
    );

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

Object? _hoverInput<K>(
  TreemapGeometrySnapshot<K>? snapshot,
  TreemapKey<K>? key,
) {
  final node = snapshot?.index[key];
  return node == null || node.opacity <= 0 || node.bounds.isEmpty
      ? null
      : node.node?.color ?? node.weight;
}

bool _sameInput(Object? a, Object? b) =>
    a == b || (a is num && b is num && a.isNaN && b.isNaN);

// Ignore engine revision counters when a repeated layout has identical output.
// Retain source identity comparisons so color, labels and data cannot go stale.
bool _sameSnapshot<K>(
  TreemapGeometrySnapshot<K>? a,
  TreemapGeometrySnapshot<K> b,
) {
  if (identical(a, b)) return true;
  if (a == null ||
      a.viewport != b.viewport ||
      a.focusKey != b.focusKey ||
      a.nodes.length != b.nodes.length ||
      a.path.length != b.path.length) {
    return false;
  }
  for (var i = 0; i < a.path.length; i++) {
    final left = a.path[i];
    final right = b.path[i];
    if (left.key != right.key ||
        left.label != right.label ||
        left.depth != right.depth) {
      return false;
    }
  }
  for (var i = 0; i < a.nodes.length; i++) {
    final left = a.nodes[i];
    final right = b.nodes[i];
    if (left.key != right.key ||
        !identical(left.node, right.node) ||
        left.bounds != right.bounds ||
        left.weight != right.weight ||
        left.depth != right.depth ||
        left.kind != right.kind ||
        left.label != right.label ||
        left.parentKey != right.parentKey ||
        left.opacity != right.opacity ||
        !listEquals(left.aggregateMembers, right.aggregateMembers)) {
      return false;
    }
  }
  return true;
}
