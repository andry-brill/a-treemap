import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../appearance/style.dart';
import '../controller.dart';
import '../model.dart';
import 'actions.dart';
import 'label_placement.dart';
import 'state.dart';

/// Read-only output, commands and environment supplied to every visual layer.
/// Frame rendering resources are separate from the published immutable state.
final class TreemapVisualContext<K> {
  TreemapVisualContext({
    required this.presentation,
    required this.actions,
    required this.textDirection,
    required this.textScaler,
    this.tileAppearance,
  }) : _contentBounds = const {},
       _resources = _TreemapFrameResources<K>();

  TreemapVisualContext._withContentBounds(
    TreemapVisualContext<K> source,
    Map<TreemapKey<K>, Rect> bounds,
  ) : presentation = source.presentation,
      actions = source.actions,
      textDirection = source.textDirection,
      textScaler = source.textScaler,
      tileAppearance = source.tileAppearance,
      _resources = source._resources,
      _contentBounds = Map.unmodifiable(bounds);

  final TreemapPresentationState<K> presentation;
  final TreemapActions<K> actions;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// Background source declared by the tile layer, independent of build order.
  /// Standalone compositions forward their tile layer's source here. Resources
  /// never enter geometry or published presentation state.
  final TreemapAppearanceResolver<K>? tileAppearance;
  final _TreemapFrameResources<K> _resources;
  final Map<TreemapKey<K>, Rect> _contentBounds;

  /// Shares frame resources while applying a prepared label placement.
  /// Standalone compositions prepare labels first, then pass this context to
  /// their tiles and render [TreemapLabelPlacement.child].
  TreemapVisualContext<K> withContentBounds(Map<TreemapKey<K>, Rect> bounds) =>
      TreemapVisualContext._withContentBounds(this, bounds);

  /// Displayed content space, excluding only this node's own reservations.
  /// Children already exclude their ancestors' headers through geometry.
  Rect contentBoundsFor(
    TreemapKey<K> key, {
    TreemapContentRegion region = TreemapContentRegion.available,
  }) {
    final details = presentation.details[key]!;
    final bounds = details.bounds;
    final tile = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );
    if (region == TreemapContentRegion.tile) return tile;
    final top = (details.headerBounds?.bottom ?? tile.top).clamp(
      tile.top,
      tile.bottom,
    );
    final body = Rect.fromLTRB(tile.left, top, tile.right, tile.bottom);
    final reserved = _contentBounds[key];
    if (reserved == null) return body;
    // Clamp custom reservations to the body, including empty rectangles.
    final left = reserved.left.clamp(body.left, body.right);
    final y = reserved.top.clamp(body.top, body.bottom);
    return Rect.fromLTRB(
      left,
      y,
      reserved.right.clamp(left, body.right),
      reserved.bottom.clamp(y, body.bottom),
    );
  }

  /// Shares appearance results between layers using the same resolver.
  Map<TreemapKey<K>, TreemapAppearance> resolveAppearances(
    BuildContext context,
    TreemapAppearanceResolver<K> resolver,
  ) => _resources.resolve(context, presentation, resolver);

  /// Resolves the source declared by the tile layer.
  /// Results share the ordinary frame/environment cache with tile painting.
  /// A missing source is an error; no background color is guessed.
  Map<TreemapKey<K>, TreemapAppearance> resolveTileAppearances(
    BuildContext context,
  ) {
    final resolver = tileAppearance;
    if (resolver == null) {
      throw FlutterError(
        'No tile appearance source is available. Use TreemapTiles, declare '
        'TreemapTileLayer.appearance on a custom tile layer, '
        'or set appearance on TreemapNoopTileLayer, TreemapCompositeTileLayer '
        'or TreemapBuilderTileLayer. Standalone compositions must forward their '
        'tile source to TreemapVisualContext.tileAppearance.',
      );
    }
    return resolveAppearances(context, resolver);
  }
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
