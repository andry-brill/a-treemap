import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'interaction.dart';
import 'layout.dart';
import 'model.dart';
import 'presentation/context.dart';
import 'presentation/contracts.dart';
import 'presentation/coordinator.dart';
import 'presentation/state.dart';
import 'presentation/transitions.dart';

const _neutralTreemapLayout = TreemapLayoutConfig<Never>();

/// Composes a prepared source with explicitly supplied presentation layers.
class TreemapChart<K> extends StatefulWidget {
  const TreemapChart({
    super.key,
    required this.tree,
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
    this.onPresentationChanged,
  }) : _layout = layout;

  final TreemapNormalizedTree<K> tree;
  final TreemapTileLayer<K> tiles;
  final TreemapController<K>? controller;
  final TreemapLayoutConfig<K> _layout;
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

  /// Observes the same immutable output as the chart's visual layers. Changes
  /// are coalesced and published after the frame, never during layout/build.
  final ValueChanged<TreemapPresentationState<K>>? onPresentationChanged;

  @override
  State<TreemapChart<K>> createState() => _TreemapChartState<K>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('tree', tree))
      ..add(DiagnosticsProperty('tiles', tiles))
      ..add(DiagnosticsProperty('controller', controller))
      ..add(DiagnosticsProperty('layout', layout))
      ..add(DiagnosticsProperty('transition', transition));
  }
}

final class _TreemapChartState<K> extends State<TreemapChart<K>> {
  late TreemapController<K> _controller;
  late bool _ownsController;
  late final TreemapChartCoordinator<K> _coordinator;

  @override
  void initState() {
    super.initState();
    _installController();
    _coordinator = TreemapChartCoordinator(
      tree: widget.tree,
      controller: _controller,
      layout: widget.layout,
      interaction: widget.interaction,
      selection: widget.selection ?? TreemapSelectionConfig<K>(),
      tooltip: widget.tooltip,
    )..onChanged = ((state) => widget.onPresentationChanged?.call(state));
  }

  void _installController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TreemapController<K>();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TreemapChart<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_ownsController) _controller.dispose();
      _installController();
    }
    _coordinator.configure(
      tree: widget.tree,
      controller: _controller,
      layout: widget.layout,
      interaction: widget.interaction,
      selection: widget.selection ?? TreemapSelectionConfig<K>(),
      tooltip: widget.tooltip,
    );
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _coordinator.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _TreemapViewport<K>(
      chart: widget,
      coordinator: _coordinator,
    );
    return TreemapPresentationScope<K>(
      presentation: _coordinator,
      actions: _coordinator,
      child: Builder(
        builder: (context) {
          final presentation = TreemapPresentationScope.of<K>(context);
          final visual = TreemapVisualContext<K>(
            presentation: presentation,
            actions: _coordinator,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            tileAppearance: widget.tiles.appearance,
          );
          return widget.surrounding?.wrap(context, viewport, visual) ??
              viewport;
        },
      ),
    );
  }
}

/// Flutter adapter: constraints and animation progress flow into the owner;
/// pointer/key events enter its command boundary; output flows into layers.
final class _TreemapViewport<K> extends StatefulWidget {
  const _TreemapViewport({required this.chart, required this.coordinator});
  final TreemapChart<K> chart;
  final TreemapChartCoordinator<K> coordinator;
  @override
  State<_TreemapViewport<K>> createState() => _TreemapViewportState<K>();
}

final class _TreemapViewportState<K> extends State<_TreemapViewport<K>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'TreemapChart');

  @override
  void initState() {
    super.initState();
    widget.coordinator
      ..resumeViewport()
      ..onInteraction = _rebuild;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.coordinator.onInteraction == _rebuild) {
      widget.coordinator.onInteraction = null;
    }
    widget.coordinator.cancelPointer();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError.fromParts([
          ErrorSummary('TreemapChart requires finite width and height.'),
          ErrorDescription(
            'Place it in SizedBox, Expanded, or another widget with bounded constraints.',
          ),
        ]);
      }
      final owner = widget.coordinator;
      final labels = widget.chart.labels;
      final parentHeaderHeight = labels?.resolveParentHeaderHeight(context);
      owner.resolveTarget(
        constraints.biggest,
        parentHeaderHeight: parentHeaderHeight,
      );
      final media = MediaQuery.of(context);
      final reduceMotion =
          media.disableAnimations || media.accessibleNavigation;
      return TweenAnimationBuilder<double>(
        key: ValueKey(owner.animationGeneration),
        tween: Tween(begin: 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : widget.chart.transition?.duration ?? Duration.zero,
        curve: widget.chart.transition?.curve ?? Curves.linear,
        builder: (context, progress, _) =>
            _buildFrame(context, owner.displayFrame(progress)),
      );
    },
  );

  Widget _buildFrame(BuildContext context, TreemapPresentationState<K> state) {
    final chart = widget.chart;
    final owner = widget.coordinator;
    if (state.targetSnapshot!.nodes.isEmpty) return const SizedBox.shrink();
    final visual = TreemapVisualContext<K>(
      presentation: state,
      actions: owner,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      tileAppearance: chart.tiles.appearance,
    );
    final tooltip = chart.tooltip;
    final details = state.tooltipDetails;
    final tooltipWidget =
        details != null &&
            tooltip != null &&
            !(state.isAnimating && tooltip.suppressDuringAnimation)
        ? tooltip.build(
            context,
            TreemapTooltipContext(details: details, visual: visual),
          )
        : null;
    final cursor =
        chart.interaction.cursorResolver?.call(
          state.targetDetails[state.hoveredKey],
        ) ??
        MouseCursor.defer;
    return Focus(
      focusNode: _focusNode,
      autofocus: chart.autofocus,
      onKeyEvent: (_, event) => _handleKey(event),
      child: MouseRegion(
        cursor: cursor,
        onHover: (event) => owner.updatePointerHover(event.localPosition),
        onExit: (_) => owner.updatePointerHover(null),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (!chart.interaction.enabled) return;
            _focusNode.requestFocus();
            owner.pointerDown(event.localPosition);
          },
          onPointerMove: (event) => owner.pointerMove(
            event.localPosition,
            hoverPointer: event.kind != PointerDeviceKind.mouse,
          ),
          onPointerUp: (event) => owner.pointerUp(
            event.localPosition,
            zoomOutRequested: _zoomOutModifier,
          ),
          onPointerCancel: (_) => owner.cancelPointer(),
          child: Stack(
            clipBehavior: chart.clipBehavior,
            children: [
              Positioned.fill(child: chart.tiles.build(context, visual)),
              if (chart.labels case final labels?)
                Positioned.fill(child: labels.build(context, visual)),
              if (chart.semantics case final semantics?)
                Positioned.fill(child: semantics.build(context, visual)),
              ?tooltipWidget,
            ],
          ),
        ),
      ),
    );
  }

  bool get _zoomOutModifier {
    final keys = HardwareKeyboard.instance;
    return keys.isControlPressed ||
        keys.isMetaPressed ||
        keys.isAltPressed ||
        keys.isShiftPressed;
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!widget.chart.interaction.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final owner = widget.coordinator;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      owner.zoomOut();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      owner.activateFocused(zoomOutRequested: _zoomOutModifier);
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
    owner.moveKeyboard(direction.dx, direction.dy);
    return KeyEventResult.handled;
  }
}
