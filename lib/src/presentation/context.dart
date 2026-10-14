import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../appearance/style.dart';
import '../controller.dart';
import '../model.dart';
import 'actions.dart';
import 'state.dart';

/// Read-only output, commands and environment supplied to every visual layer.
/// Frame rendering resources are separate from the published immutable state.
final class TreemapVisualContext<K> {
  TreemapVisualContext({
    required this.presentation,
    required this.actions,
    required this.textDirection,
    required this.textScaler,
  });

  final TreemapPresentationState<K> presentation;
  final TreemapActions<K> actions;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final _resources = _TreemapFrameResources<K>();

  /// Shares appearance results between layers using the same resolver.
  Map<TreemapKey<K>, TreemapAppearance> resolveAppearances(
    BuildContext context,
    TreemapAppearanceResolver<K> resolver,
  ) => _resources.resolve(context, presentation, resolver);
}

/// Internal frame-scoped memoization. Never stored in published presentation.
final class _TreemapFrameResources<K> {
  final Map<
    BuildContext,
    Map<TreemapAppearanceResolver<K>, Map<TreemapKey<K>, TreemapAppearance>>
  >
  _contexts = HashMap.identity();
  bool _clearScheduled = false;

  Map<TreemapKey<K>, TreemapAppearance> resolve(
    BuildContext context,
    TreemapPresentationState<K> state,
    TreemapAppearanceResolver<K> resolver,
  ) {
    Map<TreemapKey<K>, TreemapAppearance> resolve() {
      final scale = state.resolveColorScale(resolver.colorScale);
      return Map.unmodifiable({
        for (final entry in state.details.entries)
          entry.key: resolver.resolve(
            context,
            entry.value,
            state.statesFor(entry.key),
            resolvedScale: scale,
          ),
      });
    }

    final binding = SchedulerBinding.instance;
    // A custom layer's descendants can rebuild without recreating their visual
    // context. Keep sharing within the frame, but never retain appearances for
    // the next build's inherited environment (or calls outside rendering).
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      return resolve();
    }
    if (!_clearScheduled) {
      _clearScheduled = true;
      binding.addPostFrameCallback((_) {
        _contexts.clear();
        _clearScheduled = false;
      });
    }
    return _contexts
        .putIfAbsent(context, () => HashMap.identity())
        .putIfAbsent(resolver, resolve);
  }
}

/// Tooltip target accompanied by the same visual context as other layers.
final class TreemapTooltipContext<K> {
  const TreemapTooltipContext({required this.details, required this.visual});
  final TreemapNodeDetails<K> details;
  final TreemapVisualContext<K> visual;
}
