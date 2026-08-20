import 'dart:async';
import 'dart:collection';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'geometry.dart';
import 'interaction.dart';
import 'layout.dart';
import 'model.dart';
import 'presentation/context.dart';
import 'presentation/contracts.dart';
import 'presentation/transitions.dart';

typedef TreemapSnapshotCallback<K> =
    void Function(TreemapGeometrySnapshot<K> snapshot);

const _neutralTreemapLayout = TreemapLayoutConfig<Never>();

/// Composes treemap geometry, interaction, and explicitly supplied visual
/// layers.
class TreemapChart<K> extends StatefulWidget {
  const TreemapChart({
    super.key,
    required this.root,
    required this.tiles,
    this.controller,
    TreemapLayoutConfig<K> layout = const TreemapLayoutConfig(),
    this.labels,
    this.interaction = const TreemapInteractionConfig(),
    this.selection,
    this.tooltip,
    this.surrounding,
    this.semantics,
    this.transition,
    this.clipBehavior = Clip.none,
    this.autofocus = false,
    this.onSnapshot,
  }) : _layout = layout;

  final TreemapNode<K> root;
  final TreemapTileLayer<K> tiles;
  final TreemapController<K>? controller;
  final TreemapLayoutConfig<K> _layout;

  /// Geometry configuration with const, visual-neutral defaults.
  TreemapLayoutConfig<K> get layout => identical(_layout, _neutralTreemapLayout)
      ? TreemapLayoutConfig<K>()
      : _layout;
  final TreemapLabelLayer<K>? labels;
  final TreemapInteractionConfig<K> interaction;
  final TreemapSelectionConfig<K>? selection;
  final TreemapTooltipLayer<K>? tooltip;
  final TreemapSurroundingLayer<K>? surrounding;
  final TreemapSemanticsLayer<K>? semantics;
  final TreemapTransitionSpec? transition;
  final Clip clipBehavior;
  final bool autofocus;
  final TreemapSnapshotCallback<K>? onSnapshot;

  @override
  State<TreemapChart<K>> createState() => _TreemapChartState<K>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('root', root))
      ..add(DiagnosticsProperty('tiles', tiles))
      ..add(DiagnosticsProperty('controller', controller))
      ..add(DiagnosticsProperty('layout', layout))
      ..add(DiagnosticsProperty('transition', transition))
      ..add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
  }
}

/// Owns or attaches the controller and composes surrounding visual layers.
final class _TreemapChartState<K> extends State<TreemapChart<K>> {
  late TreemapController<K> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _installController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant TreemapChart<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_ownsController) _controller.dispose();
      _installController(widget.controller);
    } else {
      _controller.synchronize(widget.root);
    }
  }

  void _installController(TreemapController<K>? supplied) {
    _ownsController = supplied == null;
    _controller = supplied ?? TreemapController<K>();
    _controller
      ..synchronize(widget.root)
      ..addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _TreemapViewport<K>(
      root: widget.root,
      tiles: widget.tiles,
      controller: _controller,
      layout: widget.layout,
      labels: widget.labels,
      interaction: widget.interaction,
      selection: widget.selection ?? TreemapSelectionConfig<K>(),
      tooltip: widget.tooltip,
      semantics: widget.semantics,
      transition: widget.transition,
      clipBehavior: widget.clipBehavior,
      autofocus: widget.autofocus,
      onSnapshot: widget.onSnapshot,
    );

    if (widget.surrounding case final surrounding?) {
      content = surrounding.wrap(context, content, _controller);
    }
    return content;
  }
}

/// Passes chart configuration into the bounded interactive viewport.
final class _TreemapViewport<K> extends StatefulWidget {
  const _TreemapViewport({
    required this.root,
    required this.tiles,
    required this.controller,
    required this.layout,
    required this.labels,
    required this.interaction,
    required this.selection,
    required this.tooltip,
    required this.semantics,
    required this.transition,
    required this.clipBehavior,
    required this.autofocus,
    required this.onSnapshot,
  });

  final TreemapNode<K> root;
  final TreemapTileLayer<K> tiles;
  final TreemapController<K> controller;
  final TreemapLayoutConfig<K> layout;
  final TreemapLabelLayer<K>? labels;
  final TreemapInteractionConfig<K> interaction;
  final TreemapSelectionConfig<K> selection;
  final TreemapTooltipLayer<K>? tooltip;
  final TreemapSemanticsLayer<K>? semantics;
  final TreemapTransitionSpec? transition;
  final Clip clipBehavior;
  final bool autofocus;
  final TreemapSnapshotCallback<K>? onSnapshot;

  @override
  State<_TreemapViewport<K>> createState() => _TreemapViewportState<K>();
}

/// Resolves, animates, paints, and handles input for viewport geometry.
final class _TreemapViewportState<K> extends State<_TreemapViewport<K>> {
  static const _maximumLayoutCacheEntries = 2;

  final TreemapLayoutEngine<K> _engine = TreemapLayoutEngine<K>();
  final FocusNode _focusNode = FocusNode(debugLabel: 'TreemapChart');
  final LinkedHashMap<_LayoutCacheKey<K>, TreemapGeometrySnapshot<K>> _cache =
      LinkedHashMap();
  TreemapGeometrySnapshot<K>? _target;
  TreemapGeometrySnapshot<K>? _displayed;
  TreemapGeometrySnapshot<K>? _from;
  int _animationGeneration = 0;
  TreemapKey<K>? _tooltipKey;
  TreemapKey<K>? _keyboardKey;
  Offset? _pointerDown;
  Offset? _lastPointer;
  Timer? _longPressTimer;
  Timer? _tooltipTimer;
  bool _longPressFired = false;

  @override
  void didUpdateWidget(covariant _TreemapViewport<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.root, widget.root) ||
        !identical(oldWidget.layout, widget.layout)) {
      _cache.clear();
    }
    if (oldWidget.interaction.enabled && !widget.interaction.enabled) {
      _clearPointerState();
      widget.controller.setHovered(null);
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _tooltipTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          throw FlutterError.fromParts([
            ErrorSummary('TreemapChart requires finite width and height.'),
            ErrorDescription(
              'Place it in SizedBox, Expanded, or another widget with bounded constraints.',
            ),
          ]);
        }
        final size = constraints.biggest;
        if (size.isEmpty) return const SizedBox.shrink();
        final media = MediaQuery.of(context);
        final next = _resolveSnapshot(size);
        if (!_sameGeometry(_target, next)) {
          _from = _displayed ?? _target ?? next;
          _target = next;
          _animationGeneration++;
          widget.onSnapshot?.call(next);
        }
        final reduceMotion =
            media.disableAnimations || media.accessibleNavigation;
        return TweenAnimationBuilder<double>(
          key: ValueKey(_animationGeneration),
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion
              ? Duration.zero
              : widget.transition?.duration ?? Duration.zero,
          curve: widget.transition?.curve ?? Curves.linear,
          builder: (context, value, _) {
            final frame = TreemapGeometryTransition.lerp(
              _from!,
              _target!,
              value,
            );
            _displayed = frame;
            return _buildFrame(context, frame, _target!, value < 1);
          },
        );
      },
    );
  }

  TreemapGeometrySnapshot<K> _resolveSnapshot(Size size) {
    final focus = widget.controller.layoutFocus;
    final key = _LayoutCacheKey(
      widget.root,
      widget.layout,
      size,
      focus?.key,
      Object.hashAll(
        focus?.aggregateMembers.map((node) => node.key) ?? const [],
      ),
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    final snapshot = _engine.layout(
      root: widget.root,
      viewport: TreemapBounds.fromLTWH(0, 0, size.width, size.height),
      config: widget.layout,
      focus: focus,
      previous: _target,
    );
    _cache[key] = snapshot;
    while (_cache.length > _maximumLayoutCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return snapshot;
  }

  Widget _buildFrame(
    BuildContext context,
    TreemapGeometrySnapshot<K> frame,
    TreemapGeometrySnapshot<K> target,
    bool isAnimating,
  ) {
    if (target.nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    final direction = Directionality.of(context);
    final media = MediaQuery.of(context);
    final details = _detailsFor(frame);
    final targetDetails = _detailsFor(target);
    final selection =
        widget.selection.selected ?? widget.controller.selectedEntries;
    final tooltipDetails = _tooltipKey == null
        ? null
        : details[_tooltipKey] ?? targetDetails[_tooltipKey];
    final cursor =
        widget.interaction.cursorResolver?.call(
          widget.controller.hoveredKey == null
              ? null
              : targetDetails[widget.controller.hoveredKey],
        ) ??
        MouseCursor.defer;

    final states = <TreemapKey<K>, Set<TreemapVisualState>>{
      for (final node in frame.nodes)
        node.key: {
          if (widget.controller.hoveredKey == node.key)
            TreemapVisualState.hovered,
          if (selection.contains(node.key)) TreemapVisualState.selected,
          if (_keyboardKey == node.key) TreemapVisualState.focused,
          if (!widget.interaction.enabled) TreemapVisualState.disabled,
        },
    };
    final visual = TreemapVisualContext<K>(
      snapshot: frame,
      details: details,
      states: states,
      controller: widget.controller,
      selection: selection,
      textDirection: direction,
      textScaler: media.textScaler,
      isAnimating: isAnimating,
      onActivate: _dispatchTap,
      onFocus: (details) {
        if (_keyboardKey != details.key) {
          setState(() => _keyboardKey = details.key);
        }
      },
    );
    final tooltipLayer = widget.tooltip;
    final tooltipWidget =
        tooltipDetails != null &&
            tooltipLayer != null &&
            !(isAnimating && tooltipLayer.suppressDuringAnimation)
        ? tooltipLayer.build(
            context,
            TreemapTooltipContext(details: tooltipDetails, visual: visual),
          )
        : null;

    Widget chart = Stack(
      clipBehavior: widget.clipBehavior,
      children: [
        Positioned.fill(child: widget.tiles.build(context, visual)),
        if (widget.labels case final labels?)
          Positioned.fill(child: labels.build(context, visual)),
        if (widget.semantics case final semantics?)
          Positioned.fill(child: semantics.build(context, visual)),
        ?tooltipWidget,
      ],
    );
    chart = MouseRegion(
      cursor: cursor,
      onHover: (event) => _updateHover(target, event.localPosition),
      onExit: (_) => _updateHover(target, null),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _onPointerDown(target, event),
        onPointerMove: (event) {
          _lastPointer = event.localPosition;
          if (event.kind != PointerDeviceKind.mouse) {
            _updateHover(target, event.localPosition);
          }
          if (_pointerDown != null &&
              (event.localPosition - _pointerDown!).distance >
                  widget.interaction.tapSlop) {
            _longPressTimer?.cancel();
          }
        },
        onPointerUp: (event) => _onPointerUp(target, event),
        onPointerCancel: (_) => _clearPointerState(),
        child: chart,
      ),
    );
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) => _handleKey(target, event),
      child: chart,
    );
  }

  Map<TreemapKey<K>, TreemapNodeDetails<K>> _detailsFor(
    TreemapGeometrySnapshot<K> snapshot,
  ) => {
    for (final node in snapshot.nodes)
      node.key: TreemapNodeDetails(
        geometry: node,
        path: _pathFor(snapshot, node),
      ),
  };

  List<TreemapPathEntry<K>> _pathFor(
    TreemapGeometrySnapshot<K> snapshot,
    TreemapGeometryNode<K> node,
  ) {
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
      cursor = cursor.parentKey == null
          ? null
          : snapshot.index[cursor.parentKey];
    }
    final result = <TreemapPathEntry<K>>[...snapshot.path];
    for (final entry in suffix.reversed) {
      if (!result.any((existing) => existing.key == entry.key)) {
        result.add(entry);
      }
    }
    return List.unmodifiable(result);
  }

  void _updateHover(TreemapGeometrySnapshot<K> snapshot, Offset? position) {
    if (!widget.interaction.enabled) return;
    final geometry = position == null
        ? null
        : _hitTestVisibleNode(
            snapshot,
            position.dx,
            position.dy,
            padding: widget.interaction.hitTestPadding,
          );
    if (geometry?.key == widget.controller.hoveredKey) return;
    final details = geometry == null
        ? null
        : TreemapNodeDetails(
            geometry: geometry,
            path: _pathFor(snapshot, geometry),
          );
    widget.controller.setHovered(geometry?.key, color: details?.color);
    widget.interaction.onHoverChanged?.call(details);
    final tooltip = widget.tooltip;
    if (tooltip != null && tooltip.activation != TreemapTooltipActivation.tap) {
      setState(() => _tooltipKey = geometry?.key);
    }
  }

  void _onPointerDown(
    TreemapGeometrySnapshot<K> snapshot,
    PointerDownEvent event,
  ) {
    if (!widget.interaction.enabled) return;
    _focusNode.requestFocus();
    _pointerDown = event.localPosition;
    _lastPointer = event.localPosition;
    _longPressFired = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(widget.interaction.longPressDuration, () {
      final position = _lastPointer;
      if (!mounted || position == null) return;
      final geometry = _hitTestVisibleNode(snapshot, position.dx, position.dy);
      if (geometry == null) return;
      _longPressFired = true;
      widget.interaction.onNodeLongPress?.call(
        TreemapNodeDetails(
          geometry: geometry,
          path: _pathFor(snapshot, geometry),
        ),
      );
    });
  }

  void _onPointerUp(TreemapGeometrySnapshot<K> snapshot, PointerUpEvent event) {
    _longPressTimer?.cancel();
    final down = _pointerDown;
    if (down != null &&
        !_longPressFired &&
        (event.localPosition - down).distance <= widget.interaction.tapSlop) {
      final geometry = _hitTestVisibleNode(
        snapshot,
        event.localPosition.dx,
        event.localPosition.dy,
        padding: widget.interaction.hitTestPadding,
      );
      if (geometry != null) {
        _dispatchTap(
          TreemapNodeDetails(
            geometry: geometry,
            path: _pathFor(snapshot, geometry),
          ),
          zoomOutRequested: _isZoomOutModifierPressed,
        );
      }
    }
    _clearPointerState();
  }

  void _dispatchTap(
    TreemapNodeDetails<K> details, {
    bool zoomOutRequested = false,
  }) {
    if (!widget.interaction.enabled) return;
    // Documented order: external tap, selection, tooltip, then drill-down.
    widget.interaction.onNodeTap?.call(details);
    if (widget.interaction.enableBuiltInBehavior) {
      if (widget.interaction.selectOnNodeTap) _updateSelection(details);
      final tooltip = widget.tooltip;
      if (tooltip != null &&
          tooltip.activation != TreemapTooltipActivation.hover) {
        setState(() => _tooltipKey = details.key);
        _tooltipTimer?.cancel();
        if (tooltip.hideDelay case final hideDelay?) {
          _tooltipTimer = Timer(hideDelay, () {
            if (mounted) setState(() => _tooltipKey = null);
          });
        }
      }
      if (widget.interaction.zoomOnNodeTap) {
        if (zoomOutRequested) {
          widget.controller.zoomOut();
        } else {
          final drillTarget = _drillDownTarget(details);
          if (drillTarget?.isAggregate ?? false) {
            widget.controller.revealAggregate(drillTarget!);
          } else if (drillTarget != null) {
            widget.controller.zoomTo(drillTarget.node!.key);
          } else if (widget.interaction.onNodeTap == null &&
              widget.controller.canZoomOut) {
            widget.controller.zoomOut();
          }
        }
      }
    }
  }

  TreemapNodeDetails<K>? _drillDownTarget(TreemapNodeDetails<K> details) {
    if (details.isAggregate || details.hasChildren) return details;
    final snapshot = _target;
    var parentKey = details.geometry.parentKey;
    while (parentKey != null && parentKey != widget.controller.focusKey) {
      final parent = snapshot?.index[parentKey];
      if (parent == null) return null;
      if (parent.hasChildren) {
        return TreemapNodeDetails(
          geometry: parent,
          path: _pathFor(snapshot!, parent),
        );
      }
      parentKey = parent.parentKey;
    }
    return null;
  }

  bool get _isZoomOutModifierPressed {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed;
  }

  void _updateSelection(TreemapNodeDetails<K> details) {
    final controlled = widget.selection.selected;
    final current = Set<TreemapKey<K>>.of(
      controlled ?? widget.controller.selectedEntries,
    );
    if (widget.selection.toggleable && current.contains(details.key)) {
      current.remove(details.key);
    } else {
      if (!widget.selection.allowMultiple) current.clear();
      current.add(details.key);
    }
    if (controlled == null) widget.controller.setSelection(current);
    widget.interaction.onSelectionChanged?.call(
      Set.unmodifiable(current),
      details,
    );
  }

  KeyEventResult _handleKey(
    TreemapGeometrySnapshot<K> snapshot,
    KeyEvent event,
  ) {
    if (!widget.interaction.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      widget.controller.zoomOut();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      final details = _detailsFor(snapshot)[_keyboardKey];
      if (details != null) {
        _dispatchTap(details, zoomOutRequested: _isZoomOutModifierPressed);
      }
      return KeyEventResult.handled;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    _moveKeyboard(snapshot, _keyboardKey, direction.dx, direction.dy);
    return KeyEventResult.handled;
  }

  void _moveKeyboard(
    TreemapGeometrySnapshot<K> snapshot,
    TreemapKey<K>? from,
    double dx,
    double dy,
  ) {
    final candidates = snapshot.visibleNodes.toList();
    if (candidates.isEmpty) return;
    final origin = from == null ? null : snapshot.index[from];
    if (origin == null) {
      setState(() => _keyboardKey = candidates.first.key);
      return;
    }
    TreemapGeometryNode<K>? best;
    var bestScore = double.infinity;
    for (final candidate in candidates) {
      if (candidate.key == origin.key) continue;
      final deltaX = candidate.bounds.centerX - origin.bounds.centerX;
      final deltaY = candidate.bounds.centerY - origin.bounds.centerY;
      if ((dx < 0 && deltaX >= 0) ||
          (dx > 0 && deltaX <= 0) ||
          (dy < 0 && deltaY >= 0) ||
          (dy > 0 && deltaY <= 0)) {
        continue;
      }
      final primary = dx == 0 ? deltaY.abs() : deltaX.abs();
      final secondary = dx == 0 ? deltaX.abs() : deltaY.abs();
      final score =
          primary + secondary * widget.interaction.directionalCrossAxisWeight;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (best != null) setState(() => _keyboardKey = best!.key);
  }

  void _clearPointerState() {
    _longPressTimer?.cancel();
    _pointerDown = null;
    _lastPointer = null;
    _longPressFired = false;
  }

  TreemapGeometryNode<K>? _hitTestVisibleNode(
    TreemapGeometrySnapshot<K> snapshot,
    double x,
    double y, {
    double padding = 0,
  }) => snapshot.hitTest(x, y, padding: padding);

  bool _sameGeometry(
    TreemapGeometrySnapshot<K>? a,
    TreemapGeometrySnapshot<K> b,
  ) {
    if (a == null || a.viewport != b.viewport || a.focusKey != b.focusKey) {
      return false;
    }
    if (a.nodes.length != b.nodes.length) return false;
    for (var i = 0; i < a.nodes.length; i++) {
      final left = a.nodes[i];
      final right = b.nodes[i];
      if (left.key != right.key ||
          left.bounds != right.bounds ||
          left.weight != right.weight ||
          left.aggregateMembers.length != right.aggregateMembers.length) {
        return false;
      }
    }
    return true;
  }
}

/// Identifies a reusable layout snapshot by data, focus, viewport, and config.
final class _LayoutCacheKey<K> {
  const _LayoutCacheKey(
    this.root,
    this.config,
    this.size,
    this.focusKey,
    this.aggregateSignature,
  );

  final TreemapNode<K> root;
  final TreemapLayoutConfig<K> config;
  final Size size;
  final TreemapKey<K>? focusKey;
  final int aggregateSignature;

  @override
  bool operator ==(Object other) =>
      other is _LayoutCacheKey<K> &&
      identical(root, other.root) &&
      identical(config, other.config) &&
      size == other.size &&
      focusKey == other.focusKey &&
      aggregateSignature == other.aggregateSignature;

  @override
  int get hashCode => Object.hash(
    identityHashCode(root),
    identityHashCode(config),
    size,
    focusKey,
    aggregateSignature,
  );
}
