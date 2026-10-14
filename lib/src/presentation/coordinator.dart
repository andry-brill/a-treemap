import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../geometry.dart';
import '../interaction.dart';
import '../layout.dart';
import '../model.dart';
import 'actions.dart';
import 'contracts.dart';
import 'state.dart';

/// The chart's single mutable owner and ordered computation pipeline. Source
/// binding is an input operation; computed layouts never update the controller.
final class TreemapChartCoordinator<K> extends ChangeNotifier
    implements ValueListenable<TreemapPresentationState<K>>, TreemapActions<K> {
  TreemapChartCoordinator({
    required TreemapNormalizedTree<K> tree,
    required TreemapController<K> controller,
    required TreemapLayoutConfig<K> layout,
    required TreemapInteractionConfig<K> interaction,
    required TreemapSelectionConfig<K> selection,
    TreemapTooltipLayer<K>? tooltip,
  }) {
    configure(
      tree: tree,
      controller: controller,
      layout: layout,
      interaction: interaction,
      selection: selection,
      tooltip: tooltip,
    );
    _value = _projector.project(
      tree: tree,
      target: null,
      frame: null,
      selectedEntries: _selected,
      currentPath: controller.currentPath,
      focusKey: controller.focusKey,
      interactionEnabled: interaction.enabled,
    );
  }

  final TreemapLayoutEngine<K> _engine = TreemapLayoutEngine<K>();
  final TreemapPresentationProjector<K> _projector =
      TreemapPresentationProjector<K>();
  TreemapNormalizedTree<K>? _tree;
  late TreemapController<K> _controller;
  late TreemapLayoutConfig<K> _layout;
  late TreemapInteractionConfig<K> _interaction;
  late TreemapSelectionConfig<K> _selection;
  TreemapTooltipLayer<K>? _tooltip;
  late TreemapPresentationState<K> _value;
  TreemapGeometrySnapshot<K>? _target;
  TreemapGeometrySnapshot<K>? _from;
  _LayoutInput<K>? _lastLayout;
  Map<TreemapKey<K>, TreemapNodeDetails<K>> _targetDetails = const {};
  Set<TreemapKey<K>> _controlledSelection = {};
  TreemapKey<K>? _hoveredKey;
  TreemapKey<K>? _keyboardKey;
  TreemapKey<K>? _tooltipKey;
  Timer? _tooltipTimer;
  Timer? _longPressTimer;
  Offset? _pointerDown;
  Offset? _lastPointer;
  bool _longPressFired = false;
  int _pointerGeneration = 0;
  int _publicationGeneration = 0;
  bool _scheduled = false;
  bool _disposed = false;
  bool _hoverClearPending = false;
  Set<TreemapKey<K>>? _selectionProposal;
  int animationGeneration = 0;
  VoidCallback? onInteraction;
  ValueChanged<TreemapPresentationState<K>>? onChanged;

  @override
  TreemapPresentationState<K> get value => _value;
  TreemapGeometrySnapshot<K>? get target => _target;

  Set<TreemapKey<K>> get _selected => _selection.selected == null
      ? _controller.selectedEntries
      : _controlledSelection;

  void configure({
    required TreemapNormalizedTree<K> tree,
    required TreemapController<K> controller,
    required TreemapLayoutConfig<K> layout,
    required TreemapInteractionConfig<K> interaction,
    required TreemapSelectionConfig<K> selection,
    TreemapTooltipLayer<K>? tooltip,
  }) {
    final previousTree = _tree;
    final sourceChanged = !identical(previousTree, tree);
    final controllerChanged =
        previousTree != null && !identical(_controller, controller);
    final controlledChanged =
        previousTree == null ||
        !setEquals(_selection.selected, selection.selected);
    _tree = tree;
    _controller = controller;
    _layout = layout;
    _interaction = interaction;
    _selection = selection;
    if (_tooltip?.activation != tooltip?.activation ||
        _tooltip?.hideDelay != tooltip?.hideDelay) {
      _tooltipTimer?.cancel();
      _tooltipKey = null;
    }
    _tooltip = tooltip;
    controller.synchronize(tree, notify: false);
    if (sourceChanged || controlledChanged) {
      final raw = selection.selected ?? const <Never>{};
      _controlledSelection = {};
      for (final key in raw) {
        if (key.isSource && tree.nodes.containsKey(key.sourceKey)) {
          _controlledSelection.add(key);
        } else if (key.isAggregate &&
            (!sourceChanged || previousTree == null)) {
          _controlledSelection.add(key);
        } else if (key.isSource &&
            selection.fallbackToNearestAncestor &&
            previousTree != null) {
          for (final ancestor
              in previousTree.pathTo(key.sourceKey as K).reversed) {
            if (tree.nodes.containsKey(ancestor.key)) {
              _controlledSelection.add(TreemapKey.source(ancestor.key));
              break;
            }
          }
        }
      }
      if (previousTree != null &&
          sourceChanged &&
          selection.selected != null &&
          !setEquals(_controlledSelection, raw)) {
        _selectionProposal = Set.unmodifiable(_controlledSelection);
      }
    }
    if (controllerChanged) {
      _publicationGeneration++;
      _scheduled = false;
      _hoverClearPending = false;
      _selectionProposal = null;
      _clearTransient();
      _lastLayout = null;
    }
    if (!interaction.enabled) _clearTransient();
    if (sourceChanged) cancelPointer();
  }

  /// Resume an existing chart-owned frame after viewport composition changes.
  void resumeViewport() {
    _from = _value.displayedSnapshot ?? _target;
  }

  TreemapGeometrySnapshot<K> resolveTarget(Size size) {
    final input = _LayoutInput(_tree!, _layout, size, _controller.layoutFocus);
    if (_lastLayout == input && _target != null) return _target!;
    final next = _engine.layout(
      tree: _tree!,
      viewport: TreemapBounds.fromLTWH(0, 0, size.width, size.height),
      config: _layout,
      focus: _controller.layoutFocus,
      previous: _target,
    );
    final previous = _target;
    if (!_sameGeometry(previous, next)) {
      _from = _value.displayedSnapshot ?? previous ?? next;
      animationGeneration++;
    }
    _target = next;
    _lastLayout = input;
    _targetDetails = _projector.detailsFor(next);
    _reconcileTargets();
    cancelPointer();
    return next;
  }

  /// Animation only projects a displayed frame; source and target computations
  /// are reused. Identical completed frames retain their presentation identity.
  TreemapPresentationState<K> displayFrame(double progress) {
    final target = _target!;
    final frame = TreemapGeometryTransition.lerp(
      _from ?? target,
      target,
      progress,
    );
    final animating = progress < 1 && !identical(_from, target);
    if (identical(_value.targetSnapshot, target) &&
        identical(_value.displayedSnapshot, frame) &&
        _value.hoveredKey == _hoveredKey &&
        _value.keyboardFocusedKey == _keyboardKey &&
        _value.tooltipKey == _tooltipKey &&
        _value.isAnimating == animating &&
        _value.interactionEnabled == _interaction.enabled &&
        setEquals(_value.selectedEntries, _selected)) {
      if (_hoverClearPending || _selectionProposal != null) {
        _schedulePublication();
      }
      return _value;
    }
    _value = _projector.project(
      tree: _tree!,
      target: target,
      frame: frame,
      selectedEntries: _selected,
      hoveredKey: _hoveredKey,
      keyboardFocusedKey: _keyboardKey,
      tooltipKey: _tooltipKey,
      currentPath: _controller.currentPath,
      focusKey: _controller.focusKey,
      interactionEnabled: _interaction.enabled,
      isAnimating: animating,
    );
    _schedulePublication();
    return _value;
  }

  bool _isVisible(TreemapKey<K>? key) {
    final node = _target?.index[key];
    return node != null && node.opacity > 0 && !node.bounds.isEmpty;
  }

  void _reconcileTargets() {
    if (_hoveredKey != null && !_isVisible(_hoveredKey)) {
      _hoveredKey = null;
      _hoverClearPending = true;
    }
    if (!_isVisible(_keyboardKey)) _keyboardKey = null;
    if (!_isVisible(_tooltipKey)) {
      _tooltipTimer?.cancel();
      _tooltipKey = null;
    }
  }

  void _clearTransient() {
    if (_hoveredKey != null) _hoverClearPending = true;
    _hoveredKey = null;
    _keyboardKey = null;
    _tooltipKey = null;
    _tooltipTimer?.cancel();
    cancelPointer();
  }

  void _schedulePublication() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    final generation = _publicationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _publicationGeneration) return;
      _scheduled = false;
      final state = _value;
      final clearHover = _hoverClearPending;
      final proposal = _selectionProposal;
      _hoverClearPending = false;
      _selectionProposal = null;
      notifyListeners();
      onChanged?.call(state);
      if (_disposed || generation != _publicationGeneration) return;
      if (clearHover && _hoveredKey == null) {
        _interaction.onHoverChanged?.call(null);
      }
      if (proposal != null) {
        _interaction.onSelectionChanged?.call(proposal, null);
      }
    });
  }

  TreemapNodeDetails<K>? _details(TreemapKey<K>? key) {
    if (!_isVisible(key)) return null;
    // Actions can run immediately after a target update; project cached target
    // details rather than retaining a node from an older displayed frame.
    return _targetDetails[key];
  }

  void _invalidate() {
    if (!_disposed) onInteraction?.call();
  }

  @override
  void hover(TreemapKey<K>? key) {
    if (!_interaction.enabled || _disposed) return;
    if (!_isVisible(key)) key = null;
    if (_hoveredKey == key) return;
    _hoveredKey = key;
    _hoverClearPending = false;
    final details = _details(key);
    _interaction.onHoverChanged?.call(details);
    if (_tooltip != null &&
        _tooltip!.activation != TreemapTooltipActivation.tap) {
      _tooltipTimer?.cancel();
      _tooltipKey = key;
    }
    _invalidate();
  }

  @override
  void focus(TreemapKey<K>? key) {
    if (!_interaction.enabled || _disposed) return;
    if (!_isVisible(key)) key = null;
    if (_keyboardKey == key) return;
    _keyboardKey = key;
    _invalidate();
  }

  void activateFocused({bool zoomOutRequested = false}) {
    final key = _keyboardKey;
    if (key != null) activate(key, zoomOutRequested: zoomOutRequested);
  }

  @override
  void activate(TreemapKey<K> key, {bool zoomOutRequested = false}) {
    if (!_interaction.enabled || _disposed) return;
    final details = _details(key);
    if (details == null) return;
    // External tap, selection, tooltip, navigation is the public gesture order.
    _interaction.onNodeTap?.call(details);
    if (!_interaction.enableBuiltInBehavior) return;
    if (_interaction.selectOnNodeTap) {
      select(key, toggle: _selection.toggleable);
    }
    if (_tooltip != null &&
        _tooltip!.activation != TreemapTooltipActivation.hover) {
      _tooltipKey = key;
      _tooltipTimer?.cancel();
      if (_tooltip!.hideDelay case final delay?) {
        _tooltipTimer = Timer(delay, () {
          if (_disposed) return;
          _tooltipKey = null;
          _invalidate();
        });
      }
      _invalidate();
    }
    if (!_interaction.zoomOnNodeTap) return;
    if (zoomOutRequested) {
      zoomOut();
      return;
    }
    final drill = _drillTarget(details);
    if (drill?.isAggregate ?? false) {
      revealAggregate(drill!.key);
    } else if (drill?.node case final node?) {
      zoomTo(node.key);
    } else if (_interaction.onNodeTap == null && _controller.canZoomOut) {
      zoomOut();
    }
  }

  TreemapNodeDetails<K>? _drillTarget(TreemapNodeDetails<K> details) {
    if (details.isAggregate || details.hasChildren) return details;
    var key = details.geometry.parentKey;
    while (key != null && key != _controller.focusKey) {
      final parent = _details(key);
      if (parent == null) return null;
      if (parent.hasChildren) return parent;
      key = parent.geometry.parentKey;
    }
    return null;
  }

  @override
  void select(TreemapKey<K> key, {bool toggle = false}) {
    if (!_interaction.enabled || _disposed || !_validSelection(key)) return;
    final next = Set<TreemapKey<K>>.of(_selected);
    if (toggle && next.contains(key)) {
      next.remove(key);
    } else {
      if (!_selection.allowMultiple) next.clear();
      next.add(key);
    }
    _applySelection(next, _details(key));
  }

  bool _validSelection(TreemapKey<K> key) => key.isSource
      ? _tree!.nodes.containsKey(key.sourceKey)
      : _isVisible(key) || _selected.contains(key);

  @override
  void setSelection(Iterable<TreemapKey<K>> keys) {
    if (!_interaction.enabled || _disposed) return;
    final next = keys.where(_validSelection).toSet();
    if (!_selection.allowMultiple && next.length > 1) {
      final last = next.last;
      next
        ..clear()
        ..add(last);
    }
    _applySelection(next, null);
  }

  void _applySelection(
    Set<TreemapKey<K>> next,
    TreemapNodeDetails<K>? changed,
  ) {
    if (_selection.selected == null) {
      _controller.setSelection(next);
      next = _controller.selectedEntries;
    }
    _interaction.onSelectionChanged?.call(Set.unmodifiable(next), changed);
    _invalidate();
  }

  @override
  void clearSelection() => setSelection(const []);
  @override
  TreemapCommandResult<K> zoomTo(K key) => _disposed
      ? const TreemapCommandResult(TreemapCommandStatus.unchanged)
      : _controller.zoomTo(key);
  @override
  TreemapCommandResult<K> zoomOut() => _disposed
      ? const TreemapCommandResult(TreemapCommandStatus.unchanged)
      : _controller.zoomOut();
  @override
  TreemapCommandResult<K> reset() => _disposed
      ? const TreemapCommandResult(TreemapCommandStatus.unchanged)
      : _controller.reset();
  @override
  TreemapCommandResult<K> revealAggregate(TreemapKey<K> key) {
    final details = _disposed ? null : _details(key);
    if (details == null || !details.isAggregate) {
      return TreemapCommandResult(TreemapCommandStatus.missingKey, key: key);
    }
    return _controller.revealAggregate(
      key,
      memberKeys: details.aggregateMembers.map((node) => node.key),
    );
  }

  void updatePointerHover(Offset? position) => hover(
    position == null
        ? null
        : _target
              ?.hitTest(
                position.dx,
                position.dy,
                padding: _interaction.hitTestPadding,
              )
              ?.key,
  );

  void pointerDown(Offset position) {
    if (!_interaction.enabled) return;
    cancelPointer();
    _pointerDown = position;
    _lastPointer = position;
    _longPressFired = false;
    final generation = _pointerGeneration;
    _longPressTimer = Timer(_interaction.longPressDuration, () {
      if (_disposed ||
          generation != _pointerGeneration ||
          _lastPointer == null) {
        return;
      }
      final position = _lastPointer!;
      final node = _target?.hitTest(
        position.dx,
        position.dy,
        padding: _interaction.hitTestPadding,
      );
      final details = _details(node?.key);
      if (details == null) return;
      _longPressFired = true;
      _interaction.onNodeLongPress?.call(details);
    });
  }

  void pointerMove(Offset position, {required bool hoverPointer}) {
    _lastPointer = position;
    if (hoverPointer) updatePointerHover(position);
    if (_pointerDown != null &&
        (position - _pointerDown!).distance > _interaction.tapSlop) {
      _longPressTimer?.cancel();
    }
  }

  void pointerUp(Offset position, {bool zoomOutRequested = false}) {
    _longPressTimer?.cancel();
    final down = _pointerDown;
    if (_interaction.enabled &&
        down != null &&
        !_longPressFired &&
        (position - down).distance <= _interaction.tapSlop) {
      final key = _target
          ?.hitTest(
            position.dx,
            position.dy,
            padding: _interaction.hitTestPadding,
          )
          ?.key;
      if (key != null) activate(key, zoomOutRequested: zoomOutRequested);
    }
    cancelPointer();
  }

  void cancelPointer() {
    _pointerGeneration++;
    _longPressTimer?.cancel();
    _pointerDown = null;
    _lastPointer = null;
    _longPressFired = false;
  }

  void moveKeyboard(double dx, double dy) {
    if (!_interaction.enabled) return;
    final nodes = _target?.visibleNodes.toList() ?? [];
    if (nodes.isEmpty) return;
    final origin = _target?.index[_keyboardKey];
    if (origin == null) {
      focus(nodes.first.key);
      return;
    }
    TreemapKey<K>? best;
    var score = double.infinity;
    for (final candidate in nodes) {
      if (candidate.key == origin.key) continue;
      final x = candidate.bounds.centerX - origin.bounds.centerX;
      final y = candidate.bounds.centerY - origin.bounds.centerY;
      if ((dx < 0 && x >= 0) ||
          (dx > 0 && x <= 0) ||
          (dy < 0 && y >= 0) ||
          (dy > 0 && y <= 0)) {
        continue;
      }
      final next =
          (dx == 0 ? y.abs() : x.abs()) +
          (dx == 0 ? x.abs() : y.abs()) *
              _interaction.directionalCrossAxisWeight;
      if (next < score) {
        score = next;
        best = candidate.key;
      }
    }
    if (best != null) focus(best);
  }

  @override
  void dispose() {
    _disposed = true;
    _publicationGeneration++;
    _tooltipTimer?.cancel();
    cancelPointer();
    onInteraction = null;
    onChanged = null;
    super.dispose();
  }
}

final class _LayoutInput<K> {
  _LayoutInput(
    this.tree,
    TreemapLayoutConfig<K> layout,
    this.size,
    TreemapFocus<K>? focus,
  ) : layout = layout.copyWith(
        policy: TreemapLayoutPolicy(
          rootRule: layout.policy.rootRule,
          byChildDepth: Map.unmodifiable(layout.policy.byChildDepth),
          byParentKey: Map.unmodifiable(layout.policy.byParentKey),
          resolver: layout.policy.resolver,
          inheritResolvedRule: layout.policy.inheritResolvedRule,
        ),
      ),
      focusKey = focus?.key,
      members = List.unmodifiable(
        focus?.aggregateMembers.map((node) => node.key) ?? <K>[],
      );
  final TreemapNormalizedTree<K> tree;
  final TreemapLayoutConfig<K> layout;
  final Size size;
  final TreemapKey<K>? focusKey;
  final List<K> members;
  @override
  bool operator ==(Object other) =>
      other is _LayoutInput<K> &&
      identical(tree, other.tree) &&
      layout == other.layout &&
      size == other.size &&
      focusKey == other.focusKey &&
      listEquals(members, other.members);
  @override
  int get hashCode => Object.hash(
    identityHashCode(tree),
    layout,
    size,
    focusKey,
    Object.hashAll(members),
  );
}

bool _sameGeometry<K>(
  TreemapGeometrySnapshot<K>? a,
  TreemapGeometrySnapshot<K> b,
) {
  if (a == null ||
      a.viewport != b.viewport ||
      a.focusKey != b.focusKey ||
      a.nodes.length != b.nodes.length) {
    return false;
  }
  for (var i = 0; i < a.nodes.length; i++) {
    final left = a.nodes[i];
    final right = b.nodes[i];
    if (left.key != right.key ||
        left.bounds != right.bounds ||
        left.opacity != right.opacity ||
        left.depth != right.depth ||
        left.kind != right.kind ||
        left.parentKey != right.parentKey) {
      return false;
    }
  }
  return true;
}
