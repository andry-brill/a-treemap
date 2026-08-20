# any_treemap

[![Tests](https://github.com/andry-brill/a-treemap/actions/workflows/test.yml/badge.svg)](https://github.com/andry-brill/a-treemap/actions/workflows/test.yml)

A composable Flutter treemap for immutable hierarchical data. It separates data, geometry, interaction, and presentation so an application can use the included Material-oriented layers, replace only one layer, or consume the layout engine without rendering a chart.

The package includes eight layout algorithms, branch-specific layout rules, responsive aggregation, typed selection and navigation, keyboard support, color scales, legends, breadcrumbs, tooltips, canvas or widget labels, and keyed geometry transitions.

![App Screenshot](https://raw.githubusercontent.com/andry-brill/a-treemap/main/example/web/example.png)

> You might also like my other packages: [any_timeago](https://pub.dev/packages/any_timeago), [any_sparklines](https://pub.dev/packages/any_sparklines), and [any_borders](https://pub.dev/packages/any_borders).

## Requirements and installation

`any_treemap` requires Dart 3.8 or later and Flutter 3.32 or later.

```console
flutter pub add any_treemap
```

Import the single public library:

```dart
import 'package:any_treemap/any_treemap.dart';
```

## Quick start

A chart always needs a hierarchy and a tile layer. Colors are explicit: the package does not silently choose a palette or fallback color.

```dart
import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

final root = TreemapNode<String>(
  key: 'products',
  label: 'Products',
  children: [
    TreemapNode(
      key: 'mobile',
      label: 'Mobile',
      weight: 55,
      color: 'mobile',
    ),
    TreemapNode(
      key: 'web',
      label: 'Web',
      weight: 30,
      color: 'web',
    ),
    TreemapNode(
      key: 'desktop',
      label: 'Desktop',
      weight: 15,
      color: 'desktop',
    ),
  ],
);

final scale = TreemapColorScale.exact(
  const {
    'mobile': Color(0xFF3F51B5),
    'web': Color(0xFF5C6BC0),
    'desktop': Color(0xFF9FA8DA),
  },
  fallback: const Color(0xFF607D8B),
);

final appearance = TreemapAppearanceResolver<String>(colorScale: scale);

class ProductTreemap extends StatelessWidget {
  const ProductTreemap({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 640,
      height: 400,
      child: TreemapChart<String>(
        root: root,
        tiles: TreemapTiles(appearance: appearance),
        labels: TreemapCanvasLabels(appearance: appearance),
        tooltip: TreemapTooltip(
          builder: (context, details) => Text(
            '${details.label}: ${details.weight}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        layout: const TreemapLayoutConfig(
          innerSpacing: 3,
          outerPadding: TreemapInsets.all(8),
        ),
      ),
    );
  }
}
```

`TreemapChart` needs finite width and height. Put it in `SizedBox`, `Expanded`, or another bounded parent. A zero-sized chart or a hierarchy with no positive descendant weight produces `SizedBox.shrink`.

## Architecture

The rendering pipeline has four separate responsibilities:

1. `TreemapNode<K>` describes caller-owned data. `TreemapNormalizer` validates it and derives branch totals.
2. `TreemapLayoutEngine<K>` turns the hierarchy into a `TreemapGeometrySnapshot<K>` for a viewport and focus.
3. `TreemapChart<K>` coordinates geometry, controller state, input, and animation.
4. Replaceable presentation layers receive a `TreemapVisualContext<K>` and render tiles, labels, semantics, tooltips, or surrounding chrome.

This separation lets an application replace labels without reimplementing navigation, use the layout engine without constructing widgets, or change colors without changing geometry.

## Data model

**`TreemapNode<K>`** - immutable, caller-owned source data for one hierarchy node. Stable identity is separate from every display value so updates, selection, navigation, and animation can survive label or weight changes.

- `key` - required globally unique domain identity. Prefer a database ID, enum, or stable path over display text.
- `weight` - non-negative finite leaf weight; defaults to `0`. A branch's effective weight is calculated from descendant leaves instead.
- `label` - optional human-readable title used by included presentation layers.
- `valueLabel` - optional preformatted display value for the standard canvas label layer; it never changes layout weight.
- `semanticLabel` - optional spoken label for the standard semantics layer.
- `color` - optional direct Flutter `Color` or input value for a configured `TreemapColorScale`.
- `data` - optional opaque application payload retained for builders and callbacks.
- `children` - immutable descendants; an empty iterable makes the node a source leaf.

The constructor copies `children` into an unmodifiable list. A direct `Color` bypasses scale lookup; another value is resolved through the scale; a null color input makes the included resolver use the resolved weight. Use `copyWith` for immutable updates and reuse keys across revisions so `resquarified` layout and transitions can preserve continuity.

**`TreemapNode.fromRecords<T, K>`** - builds an immutable hierarchy by grouping flat records through one or more record levels.

- `rootKey` - required stable key for the generated root.
- `records` - required source records; the method snapshots the iterable before grouping.
- `leafKey` - required mapper that produces a globally unique key for each leaf.
- `weight` - required mapper that produces each leaf's non-negative finite weight.
- `levels` - ordered `TreemapRecordLevel<T, K>` definitions, from the root grouping down to the leaf parent.
- `leafLabel` - optional visual-label mapper.
- `leafValueLabel` - optional preformatted-value mapper.
- `leafSemanticLabel` - optional accessibility-label mapper.
- `leafColor` - optional direct-color or color-scale-input mapper.
- `leafData` - optional payload mapper; the original record becomes the payload when this is absent.
- `rootLabel` - optional visual label for the generated root.

Grouping keys and leaf keys share one namespace. If a group name can repeat under different parents, include its ancestry in the generated key.

```dart
final root = TreemapNode.fromRecords<Sale, String>(
  rootKey: 'all-sales',
  rootLabel: 'All sales',
  records: sales,
  levels: [
    TreemapRecordLevel(
      key: (sale) => 'region:${sale.region}',
      label: (sale) => sale.region,
      color: (sale) => sale.region,
    ),
    TreemapRecordLevel(
      key: (sale) => 'team:${sale.region}:${sale.team}',
      label: (sale) => sale.team,
    ),
  ],
  leafKey: (sale) => 'sale:${sale.id}',
  leafLabel: (sale) => sale.product,
  weight: (sale) => sale.revenue,
  leafData: (sale) => sale,
);
```

**`TreemapRecordLevel<T, K>`** - describes one grouping step used by `TreemapNode.fromRecords`.

- `key` - required mapper that identifies a group.
- `label` - optional mapper for the group's visual label.
- `semanticLabel` - optional mapper for the group's accessibility label.
- `color` - optional mapper for the group's direct color or scale input.

The mappers receive the first record in a group. The class describes group nodes only; leaf values come from the separate `fromRecords` leaf mappers.

**`TreemapKey<K>`** - collision-free identity for either caller-owned data or a generated aggregate.

- `sourceKey` - the original `K` for a source identity; null for an aggregate identity.
- `aggregateParent` - parent identity used to scope a generated aggregate.
- `aggregateSignature` - generated membership signature; its presence marks the key as an aggregate.
- `isSource` - true when the key wraps caller data.
- `isAggregate` - true when the layout engine generated the identity.

Create domain identities with `TreemapKey.source(key)`. The layout engine creates `TreemapKey.aggregate` values when minimum-node aggregation combines siblings. Selection uses `TreemapKey<K>` so aggregates never need fake domain keys.

**`TreemapNormalizer.normalize<K>(root)`** - validates a source hierarchy and derives the indexes needed by the layout engine.

- `root` - the immutable `TreemapNode<K>` hierarchy to validate and index.

Normalization checks all nodes in one traversal, calculates descendant totals after their children, and throws one `TreemapValidationException<K>` containing every detected issue.

**`TreemapNormalizedTree<K>`** - validated, indexed representation returned by `TreemapNormalizer`.

- `root` - original hierarchy root.
- `nodes` - unmodifiable source-key-to-node index.
- `parents` - unmodifiable source-key-to-parent-key index; the root maps to null.
- `depths` - unmodifiable absolute source depth for every node.
- `totals` - unmodifiable effective-weight index; branch values are descendant sums.
- `pathTo(key)` - returns the immutable root-to-node source path, or an empty list when the key is absent.

`TreemapChart` and `TreemapLayoutEngine` normalize automatically. Use this class directly for validation, preprocessing, tests, or headless integrations.

**`TreemapValidationIssue<K>`** - one actionable problem discovered while normalizing source data.

- `code` - typed `TreemapValidationCode`: `emptyKey`, `duplicateKey`, `cycle`, or `invalidWeight`.
- `key` - affected source key when one is available.
- `message` - explanation of the invalid input.
- `correction` - suggested way to repair it.

Issues are data rather than formatted UI, allowing an application to localize or regroup validation output.

**`TreemapValidationException<K>`** - collects every hierarchy issue found during one normalization pass.

- `issues` - immutable list of `TreemapValidationIssue<K>` values.

Catch this exception when records are user-generated and validation failures should be rendered in an application-specific way.

## Chart

**`TreemapChart<K>`** - orchestration widget that connects immutable data, layout, controller state, input, animation, and replaceable presentation layers.

- `root` - required already-constructed hierarchy.
- `tiles` - required complete tile-surface implementation; use `TreemapNoopTileLayer` for an intentionally invisible host.
- `controller` - optional externally owned controller. The chart creates and disposes an internal controller when omitted.
- `layout` - geometry configuration; defaults to a visual-neutral `TreemapLayoutConfig`.
- `labels` - optional label layer.
- `interaction` - pointer and keyboard policy; defaults to enabled built-in navigation.
- `selection` - optional controlled/uncontrolled selection policy.
- `tooltip` - optional tooltip layer.
- `surrounding` - optional single layer that composes breadcrumbs, legends, or other chrome around the viewport.
- `semantics` - optional accessibility layer; canvas paint has no semantics by itself.
- `transition` - optional keyed geometry animation; null applies updates immediately.
- `clipBehavior` - clipping for the chart stack; defaults to `Clip.none`.
- `autofocus` - whether the chart initially requests keyboard focus; defaults to false.
- `onSnapshot` - optional callback invoked when a new target layout is produced.

The chart requires finite width and height, caches recent layouts, hit-tests the deepest visible block, and synchronizes controller state when `root` changes. The surrounding layer wraps the bounded viewport exactly once; tile, label, semantics, and tooltip layers share its geometry.

**`TreemapTransitionSpec`** - opt-in duration and curve for keyed chart geometry animation.

- `duration` - required transition duration.
- `curve` - required Flutter animation curve.

The chart interpolates bounds and opacity by `TreemapKey`. It overrides the configured duration with zero when `MediaQuery.disableAnimations` or accessible navigation requests reduced motion.

**`TreemapTransitions.standard`** - reusable transition preset for ordinary chart updates.

- `duration` - 300 milliseconds.
- `curve` - `Curves.easeInOutCubic`.

Pass this constant to `TreemapChart.transition`; leave `transition` null when updates should be immediate.

## Layout

**`TreemapLayoutConfig<K>`** - top-level geometry configuration for spacing, minimum visible size, aggregation, and branch rule resolution.

- `policy` - `TreemapLayoutPolicy<K>` used to resolve a rule for each branch; defaults to the standard squarified policy.
- `outerPadding` - space removed from the viewport before root layout; defaults to zero.
- `levelPadding` - space removed inside every branch before laying out its children; defaults to zero.
- `innerSpacing` - gutter applied between sibling rectangles; defaults to `0`.
- `minimumWidth` - minimum acceptable node width for hide/aggregate policies; defaults to `0`.
- `minimumHeight` - minimum acceptable node height for hide/aggregate policies; defaults to `0`.
- `minimumArea` - minimum acceptable node area for hide/aggregate policies; defaults to `0`.
- `minimumNodePolicy` - `show`, `hide`, or `aggregate`; defaults to `show`.
- `insufficientSpacePolicy` - behavior when every sibling fails its minimum: keep/aggregate, hide, or throw; defaults to `show`.

Padding and spacing affect geometry. Minimums affect which data is visible and can redistribute area, unlike layer-level `maximumNodes`, which only limits rendering.

```dart
const layout = TreemapLayoutConfig<String>(
  outerPadding: TreemapInsets.all(8),
  levelPadding: TreemapInsets.all(4),
  innerSpacing: 2,
  minimumWidth: 40,
  minimumHeight: 28,
  minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
  insufficientSpacePolicy: TreemapInsufficientSpacePolicy.show,
);
```

**`TreemapLayoutAlgorithm`** - built-in strategy selected by a resolved layout rule.

- `squarified` - produces compact rectangles close to square; the general-purpose default.
- `resquarified` - reuses previous keyed topology during updates to reduce reordering.
- `slice` - divides height into horizontal slices.
- `dice` - divides width into vertical slices.
- `alternatingSliceDice` - alternates slice and dice by absolute tree depth.
- `strip` - builds ordered strips while improving their aspect ratios.
- `binaryByWeight` - recursively partitions siblings into groups with similar total weight.
- `binaryByCount` - recursively partitions siblings into groups with similar item counts.

Stable keys and a previous snapshot are especially important for `resquarified`; the other strategies do not require previous geometry.

**`TreemapLayoutRule<K>`** - partial branch rule whose null choices inherit from a resolved fallback.

- `algorithm` - optional built-in layout algorithm.
- `sort` - optional `sourceOrder`, `ascending`, `descending`, or `custom` sibling ordering.
- `comparator` - comparator used when `sort` is `custom`.
- `direction` - optional starting corner: top-left, top-right, bottom-left, or bottom-right.
- `axisOrder` - optional horizontal-first or vertical-first preference.
- `strategy` - optional custom `ITreemapLayoutStrategy<K>` that replaces the built-in algorithm for the branch.

Call `resolve` with an optional fallback to produce a complete `TreemapResolvedLayoutRule<K>`. Layout direction is independent of Flutter `TextDirection`.

**`TreemapResolvedLayoutRule<K>`** - complete non-null choices consumed by the layout engine after inheritance.

- `algorithm` - selected built-in algorithm.
- `sort` - selected sibling sort policy.
- `comparator` - optional custom comparator.
- `direction` - selected starting corner.
- `axisOrder` - selected primary-axis preference.
- `strategy` - optional custom strategy, which takes precedence over the built-in algorithm.

`TreemapResolvedLayoutRule.defaults()` produces squarified, descending, top-left, horizontal-first behavior.

**`TreemapLayoutPolicy<K>`** - resolves different rules for different branches without requiring separate charts.

- `rootRule` - base partial rule; omitted values resolve against package defaults.
- `byChildDepth` - partial rules keyed by the absolute depth of the children being placed.
- `byParentKey` - partial rules keyed by the source parent.
- `resolver` - optional callback for data- or bounds-dependent choices.
- `inheritResolvedRule` - whether a branch starts with its parent's resolved rule; defaults to true.

Resolution overlays depth, parent, and callback rules in that order. Set `inheritResolvedRule` to false when each branch should restart from `rootRule`.

```dart
final layout = TreemapLayoutConfig<String>(
  policy: TreemapLayoutPolicy(
    rootRule: const TreemapLayoutRule(
      algorithm: TreemapLayoutAlgorithm.squarified,
      sort: TreemapSortPolicy.descending,
    ),
    byChildDepth: const {
      2: TreemapLayoutRule(
        algorithm: TreemapLayoutAlgorithm.alternatingSliceDice,
      ),
    },
    resolver: (context) => context.children.length > 40
        ? const TreemapLayoutRule(
            algorithm: TreemapLayoutAlgorithm.binaryByWeight,
          )
        : null,
  ),
);
```

**`TreemapLayoutContext<K>`** - read-only branch state passed to `TreemapLayoutPolicy.resolver`.

- `parent` - source node whose immediate children are being partitioned.
- `children` - immutable immediate-child list.
- `childDepth` - absolute depth assigned to those children.
- `bounds` - rectangle available to the branch before sibling partitioning.
- `focusKey` - current source or aggregate focus identity.
- `inheritedRule` - complete rule inherited from the parent branch.

Use this context to select a rule from local structure without reaching into mutable engine state.

**`ITreemapLayoutStrategy<K>.layout(input)`** - extension contract for laying out one level of immediate siblings.

- `input` - immutable `TreemapStrategyInput<K>` containing sibling items and their available rectangle.
- return value - one `TreemapBounds` for every input `TreemapKey<K>`.

The engine still owns hierarchy traversal, rule resolution, spacing, minimum-node handling, focus, diagnostics, and snapshot creation.

**`TreemapStrategyInput<K>`** - complete input supplied to a custom immediate-children strategy.

- `items` - immutable `TreemapLayoutItem<K>` siblings in already-resolved order.
- `bounds` - rectangle the strategy must partition.
- `childDepth` - absolute depth of the items.
- `axisOrder` - preferred first axis selected by the resolved rule.

A strategy should remain deterministic and return finite, contained, non-overlapping rectangles.

**`TreemapLayoutItem<K>`** - layout-safe representation of one source or generated sibling.

- `key` - source or aggregate identity that must appear in the strategy result.
- `node` - source node, or null for a generated aggregate item.
- `weight` - resolved effective weight used to assign relative area.
- `sourceIndex` - stable pre-sort position from the source hierarchy.

Custom strategies should use `key` rather than assuming every item has a source node.

**`TreemapLayoutEngine<K>.layout`** - synchronous, deterministic conversion from hierarchy data to immutable geometry.

- `root` - required source hierarchy.
- `viewport` - required finite, non-negative output bounds.
- `config` - optional geometry configuration.
- `focus` - optional source branch or aggregate members to use as the viewport root.
- `previous` - optional prior snapshot used by topology-stable layout and transitions.

The method normalizes input, validates configuration, traverses branches iteratively, validates its output geometry, and throws typed validation or layout exceptions on invalid input.

**`TreemapLayoutEngine<K>.layoutAsync`** - isolate-backed version of `layout` for large sendable inputs.

- `root` - required isolate-sendable hierarchy.
- `viewport` - required output bounds.
- `config` - optional isolate-sendable configuration.
- `focus` - optional focus.
- `previous` - optional previous snapshot.
- `fallbackToSynchronous` - retries on the calling isolate when isolate execution fails; defaults to true.

Keys, payloads, callbacks, strategies, and configuration captured by the request must be isolate-sendable. Set `fallbackToSynchronous: false` when an isolate failure must be surfaced rather than retried.

```dart
final snapshot = await TreemapLayoutEngine<String>().layoutAsync(
  root: root,
  viewport: const TreemapBounds.fromLTWH(0, 0, 1200, 800),
  config: layout,
);
```

**`TreemapFocus<K>`** - identifies the source branch or generated aggregate whose children should fill the viewport.

- `key` - source or aggregate focus identity.
- `aggregateMembers` - source members represented by an aggregate focus; empty for source focus.
- `path` - navigation path retained for an aggregate focus.

Use `TreemapFocus.source(key)` for domain branches. `TreemapController.revealAggregate` constructs aggregate focus state during interactive navigation.

**`TreemapLayoutException`** - reports invalid layout configuration, insufficient configured space, or invalid generated geometry.

- `message` - human-readable failure explanation.

This exception covers geometry and configuration failures; source hierarchy failures use `TreemapValidationException<K>`.

## Geometry and callback data

**`TreemapInsets`** - Flutter-independent edge distances used by the pure layout engine.

- `left` - left inset.
- `top` - top inset.
- `right` - right inset.
- `bottom` - bottom inset.
- `horizontal` - derived sum of left and right.
- `vertical` - derived sum of top and bottom.

Construct uniform values with `TreemapInsets.all`, paired values with `TreemapInsets.symmetric`, or individual values with `TreemapInsets.fromLTRB`. `TreemapInsets.zero` is the visual-neutral default.

**`TreemapBounds`** - immutable, axis-aligned rectangle used for layout, hit testing, positioning, diagnostics, and transitions.

- `left` - x-coordinate of the left edge.
- `top` - y-coordinate of the top edge.
- `width` - horizontal extent.
- `height` - vertical extent.
- `right`, `bottom`, `area`, `centerX`, `centerY` - derived geometry.
- `contains(x, y, {padding})` - point containment with optional expanded hit-test padding.
- `inset(insets)` - returns a rectangle reduced by `TreemapInsets`.
- `inflate(value)` - returns a rectangle expanded or contracted on every edge.
- `clampTo(container)` - confines the rectangle to another rectangle.
- `overlaps(other, {tolerance})` - tests positive-area overlap.
- `lerp(a, b, t)` - linearly interpolates two rectangles.

Use `TreemapBounds.fromLTWH` for a concrete rectangle and `TreemapBounds.zero` for an empty origin rectangle. The type intentionally does not depend on Flutter's `Rect`.

**`TreemapGeometryNode<K>`** - resolved rectangle and hierarchy metadata for one source node or generated aggregate.

- `key` - source or aggregate geometry identity.
- `node` - original source node; null for a generated aggregate.
- `bounds` - resolved rectangle.
- `weight` - effective source or combined aggregate weight.
- `depth` - absolute hierarchy depth.
- `kind` - `TreemapGeometryKind.source` or `.aggregate`.
- `label` - retained source label; aggregates leave naming to presentation.
- `parentKey` - parent geometry identity, or null for top-level visible geometry.
- `opacity` - transition visibility from `0` to `1`.
- `aggregateMembers` - immutable source nodes represented by an aggregate.
- `hasChildren` - true for a source branch or revealable aggregate.

A geometry node is layout output, not caller data. Use `node` and `aggregateMembers` to get back to the application model.

**`TreemapPathEntry<K>`** - lightweight entry in the root-to-focus or root-to-node navigation path.

- `key` - source or aggregate identity.
- `label` - optional display label.
- `depth` - absolute hierarchy depth.

Breadcrumbs consume these entries without retaining the complete source tree.

**`TreemapGeometrySnapshot<K>`** - complete immutable output of one layout pass.

- `viewport` - bounds used for the pass.
- `nodes` - every source and aggregate geometry node, including visible ancestors.
- `index` - unmodifiable key-to-geometry lookup.
- `path` - current focus path.
- `focusKey` - source or aggregate identity filling the viewport.
- `revision` - monotonically increasing engine-local pass number.
- `visibleNodes` - nodes with positive opacity and non-empty bounds.
- `hitTest(x, y, {padding})` - deepest visible node containing a point.
- `toStringDeep({maximumNodes})` - bounded diagnostic dump.

Tile layers often use all visible nodes to paint hierarchy. Labels, semantics, and tooltips normally use only the deepest visible blocks exposed by `TreemapVisualContext.visibleLeafNodes`.

**`TreemapNodeDetails<K>`** - application-facing callback and builder view that combines geometry with a complete navigation path.

- `geometry` - underlying `TreemapGeometryNode<K>`.
- `path` - immutable root-to-node path.
- `key`, `bounds`, `weight`, `depth`, `label` - convenient geometry projections.
- `node` - original source node when this is source geometry.
- `color` - source node's direct color or scale input.
- `aggregateMembers` - source members for generated aggregate geometry.
- `isAggregate` - whether the layout generated this block.
- `hasChildren` - whether activation can drill into a branch or reveal an aggregate.

The class deliberately does not synthesize labels, values, or colors. Builders decide how missing labels and aggregate nodes should look.

**`TreemapGeometryIssue<K>`** - one invariant violation found in an existing geometry snapshot.

- `code` - `nonFinite`, `negativeSize`, `outsideParent`, `overlap`, `duplicateKey`, or `invalidParent`.
- `message` - diagnostic explanation.
- `key` - affected geometry identity when available.

Geometry issues are returned as data so tests and developer tools can report more than one problem.

**`TreemapGeometryDiagnostics.validate<K>(snapshot, {tolerance})`** - validates identity, finiteness, containment, and sibling overlap.

- `snapshot` - geometry to inspect.
- `tolerance` - floating-point tolerance used for size, containment, and overlap checks; defaults to `1e-7`.
- return value - immutable list of `TreemapGeometryIssue<K>` values; an empty list means the snapshot passed.

Use this function when testing a custom layout strategy or geometry transformation. `TreemapLayoutEngine` already validates snapshots it produces.

**`TreemapGeometryTransition.lerp<K>(from, to, t)`** - lower-level keyed interpolation used by chart transitions.

- `from` - starting snapshot.
- `to` - target snapshot.
- `t` - interpolation fraction; values at or below `0` return `from`, and values at or above `1` return `to`.

Surviving keys interpolate their rectangles and opacity. Entering or exiting keys expand from or collapse toward their parent or viewport anchor.

## Presentation contracts and context

**`TreemapTileLayer<K>.build(context, visual)`** - required contract for rendering the complete tile surface.

- `context` - Flutter build context for inherited theme, locale, and application state.
- `visual` - immutable snapshot, details, states, selection, controller, and callbacks.
- return value - widget filling the chart viewport.

A tile layer may render source ancestors as well as deepest blocks. `TreemapChart` requires this contract but does not require a particular painter.

**`TreemapLabelLayer<K>.build(context, visual)`** - optional contract for rendering content inside resolved node bounds.

- `context` - Flutter build context.
- `visual` - current immutable visual state.
- return value - label surface filling the chart viewport.

Label implementations normally iterate `visual.visibleLeafNodes` to avoid drawing over their own descendants.

**`TreemapSemanticsLayer<K>.build(context, visual)`** - optional contract for exposing canvas-rendered nodes to assistive technology.

- `context` - Flutter build context.
- `visual` - current geometry, node details, interaction state, and activation callbacks.
- return value - semantics surface filling the viewport.

Canvas paint does not create Flutter semantics automatically. Supply this layer whenever the chart must be accessible.

**`TreemapTooltipLayer<K>`** - optional contract owning tooltip activation preferences, lifecycle, and output.

- `activation` - hover, tap, or combined activation policy.
- `hideDelay` - optional delay before a tapped tooltip is hidden.
- `suppressDuringAnimation` - whether tooltips disappear while geometry is moving.
- `build(context, tooltip)` - builds the complete positioned tooltip output.

The chart identifies and tracks the target; the layer decides how it is represented.

**`TreemapSurroundingLayer<K>.wrap(context, treemap, controller)`** - optional chart contract for composing chrome around the bounded viewport.

- `context` - Flutter build context.
- `treemap` - already-built chart viewport.
- `controller` - active chart controller.
- return value - widget containing the viewport and surrounding content.

The chart applies one surrounding layer. Breadcrumbs and legends implement this contract for direct one-sided placement, while `TreemapSurroundingGrid` combines multiple pieces of content under one layer.

**`TreemapSurroundingContent<K>.build(context, controller)`** - content contract for one grid cell.

- `TreemapSurroundingContent<K>.widget(child: ...)` adapts a static widget.
- `TreemapSurroundingContent<K>.builder(builder: ...)` adapts a
  `TreemapSurroundingContentBuilder<K>` callback that receives the active
  controller.
- `TreemapBreadcrumbs<K>` and `TreemapLegend<K>` implement both the content and layer contracts.

Custom content therefore receives the same active controller without implementing viewport composition itself.

**`TreemapVisualContext<K>`** - immutable state shared by every in-viewport presentation layer.

- `snapshot` - geometry for the current animation frame.
- `details` - unmodifiable node-details map keyed by `TreemapKey<K>`.
- `states` - unmodifiable hover, selection, keyboard-focus, and disabled-state sets per key.
- `controller` - active chart controller.
- `selection` - effective controlled or uncontrolled selection.
- `textDirection` - inherited Flutter text direction.
- `textScaler` - inherited text scaling policy.
- `isAnimating` - whether this frame is between target geometries.
- `onActivate` - callback a custom layer can use to invoke standard activation.
- `onFocus` - callback a custom layer can use to update keyboard target state.
- `visibleLeafNodes` - deepest visible blocks suitable for labels and semantics.

Custom layers should consume `statesFor(key)` instead of maintaining duplicate pointer or selection state.

**`TreemapTooltipContext<K>`** - current tooltip target plus the complete shared visual context.

- `details` - target node details.
- `visual` - same `TreemapVisualContext<K>` received by other layers.

This lets a custom tooltip inspect selection, animation state, text direction, or neighboring geometry without separate wiring.

## Included tile and label layers

**`TreemapTiles<K>`** - optimized canvas implementation of `TreemapTileLayer<K>` using the package's appearance system.

- `appearance` - required `TreemapAppearanceResolver<K>` shared by tile and label presentation.

It resolves appearance for every geometry node and paints background, fills, gradients, borders, radii, opacity, and state styles in one custom-paint surface.

**`TreemapNoopTileLayer<K>`** - explicit invisible tile layer for geometry-only or interaction-only chart hosts.

- `build(context, visual)` - returns an expanding empty widget.

Use it to satisfy the required tile contract without implying any package-defined appearance.

**`TreemapCompositeTileLayer<K>`** - stacks multiple independent tile layers over the same geometry.

- `layers` - immutable ordered layer list; earlier layers are below later layers.

This is useful when a base painter, domain overlay, and debugging overlay should remain separate implementations.

**`TreemapBuilderTileLayer<K>`** - widget-per-deepest-block tile implementation for fully custom visual content.

- `builder` - required callback receiving context, node details, and visual states.
- `maximumNodes` - optional positive cap; the largest blocks are retained first.
- `ignorePointer` - whether generated widgets ignore input; defaults to false.

The layer supplies positioning but no clipping or styling. Choose it for images, embedded controls, platform views, or effects that genuinely need widgets.

**`TreemapCanvasLabels<K>`** - high-throughput text label layer using cached `TextPainter` layouts.

- `appearance` - required resolver used to derive text-compatible tile appearance.
- `config` - formatting and layout policy; defaults to `TreemapLabelConfig<K>()`.

It clips every label independently, constrains text to available width, and omits a complete label block when it cannot fit vertically. Choose it for large charts whose labels are text.

**`TreemapWidgetLabels<K>`** - tightly positions an arbitrary widget inside every retained deepest visible block.

- `builder` - required callback receiving context, node details, and visual states.
- `maximumNodes` - optional positive cap; largest blocks are retained first.
- `ignorePointer` - whether label widgets ignore input; defaults to true so chart gestures remain available.
- `clipBehavior` - per-block clipping; defaults to `Clip.hardEdge`.

Choose this layer for icons, badges, SVGs, images, animations, or rich compositions. Configure layout minimums when the custom content requires guaranteed usable space.

**`TreemapTextLayoutCache.layout`** - bounded cache operation for custom canvas label implementations.

- `text` - required line contents.
- `style` - required complete `TextStyle`.
- `maxWidth` - required layout width, bucketed in four-pixel increments for cache reuse.
- `maxLines` - required maximum line count.
- `direction` - required text direction.
- `scaler` - required text scaler.
- `locale` - optional locale.
- `ellipsis` - optional overflow marker.
- return value - laid-out `TextPainter` retained in a 256-entry least-recently-used cache.

`TreemapCanvasLabels` owns its own cache. Use this public cache only when building another canvas implementation that needs the same bounded reuse behavior.

## Appearance and color

**`TreemapAppearanceResolver<K>`** - converts source color data and visual states into the complete appearance consumed by standard tiles and canvas labels.

- `colorScale` - required scale for category, numeric, or missing color inputs.
- `style` - base and state-specific `TreemapStyle`; defaults to `TreemapStyle()`.
- `nodeStyleResolver` - optional final per-node override receiving build context, node details, and current visual states.
- `resolve(context, details, states)` - returns one complete `TreemapAppearance` or throws when neither a color nor gradient remains.

Resolution starts with a direct source `Color`, otherwise sends the source color value or resolved weight through `colorScale`. It then merges base, hovered, selected, focused, and node-specific appearances in that order.

**`TreemapAppearance`** - paint and text styling for one tile state or override layer.

- `color` - optional solid fill.
- `gradient` - optional gradient fill.
- `border` - border side; defaults to none.
- `borderRadius` - tile corner radius; defaults to zero.
- `opacity` - value from `0` to `1`; defaults to `1`.
- `titleStyle` - optional canvas-title style override.
- `valueStyle` - optional canvas-value style override.

`merge(other)` treats null/neutral values as absent overrides and multiplies opacity. This lets a hover appearance add a border without restating the base fill.

**`TreemapStyle`** - groups the chart-wide base appearance, interaction-state overrides, background, and label padding.

- `backgroundColor` - canvas background behind geometry; defaults to transparent.
- `tileAppearance` - base override merged onto every scale-derived fill.
- `hoverAppearance` - override applied to hovered nodes; defaults to a two-pixel white border.
- `selectedAppearance` - override applied to selected nodes; defaults to a three-pixel amber border.
- `focusedAppearance` - override applied to the keyboard target; defaults to neutral.
- `labelPadding` - space reserved inside each tile for canvas text; defaults to six pixels on every edge.

The style is consumed by `TreemapAppearanceResolver`; it does not affect geometry spacing or minimum dimensions.

### Color scales

**`TreemapColorScale`** - abstract mapping from caller values to explicit colors and legend metadata.

- `colorFor(value)` - maps one value to a color.
- `legendEntries` - discrete values, ranges, or stops suitable for a legend.
- `isContinuous` - whether values form a continuous domain; defaults to false.
- `minimum` - optional continuous lower bound.
- `maximum` - optional continuous upper bound.

Every included factory requires an explicit fallback color. This ensures null, unknown, out-of-domain, or invalid input has application-selected behavior.

**`TreemapColorScale.exact / TreemapExactColorScale`** - exact value-to-color mapping for known categories or semantic values.

- `colors` - required value-to-color map, copied into an unmodifiable map.
- `labels` - optional value-to-legend-label map; missing labels use `toString()`.
- `fallback` - required color for unmapped values.

Legend entries preserve map iteration order and retain each exact value.

**`TreemapColorScale.categorical / TreemapCategoricalColorScale`** - deterministic distribution of arbitrary non-null values across a fixed palette.

- `colors` - required non-empty palette.
- `labels` - optional labels for palette positions.
- `fallback` - required color for null values.

The value hash selects a palette entry. Legend entries describe palette positions, not the categories encountered in a particular tree.

**`TreemapNumericColorRange`** - one numeric interval and its discrete appearance.

- `minimum` - inclusive lower bound.
- `maximum` - upper bound; exclusive except for the final range in a scale.
- `color` - color assigned within the interval.
- `label` - optional legend label; defaults to a generated minimum-maximum label.

Use several ranges for explicit bands such as low, medium, and high.

**`TreemapColorScale.numericRange / TreemapNumericRangeColorScale`** - maps numbers through ordered, non-overlapping intervals.

- `ranges` - interval list; copied and sorted by minimum.
- `fallback` - required color for non-numeric, non-finite, out-of-range, or gap values.

Construction rejects reversed, non-finite, or overlapping ranges. Its `minimum` and `maximum` come from the outer range bounds.

**`TreemapColorScale.interpolated / TreemapInterpolatedColorScale`** - continuous linear interpolation across two or more colors.

- `minimum` - required finite lower domain bound.
- `maximum` - required finite upper bound greater than `minimum`.
- `colors` - required list of at least two ordered color stops.
- `fallback` - required color for non-numeric or non-finite input.
- `labelFormatter` - formats legend stop values; defaults to one fractional digit.

Finite numeric input is clamped to the domain, then interpolated between adjacent stops. Legend entries are positioned evenly across the domain.

**`TreemapColorScale.saturation / TreemapSaturationColorScale`** - continuous numeric scale that varies one base hue's saturation.

- `minimum` - required finite lower domain bound.
- `maximum` - required finite upper bound greater than `minimum`.
- `color` - required base color whose hue and lightness are retained.
- `minimumSaturation` - saturation at the lower bound; defaults to `0.15`.
- `maximumSaturation` - saturation at the upper bound; defaults to `1`.
- `fallback` - required color for non-numeric or non-finite input.
- `labelFormatter` - formats the two endpoint labels.

Numeric input is clamped to the domain. Saturation values must remain in an ordered `0` to `1` range.

**`TreemapLegendEntry`** - presentation-neutral metadata for one discrete value, numeric interval, or continuous stop.

- `label` - required display text.
- `color` - required representative color.
- `value` - optional exact value or continuous stop value.
- `minimum` - optional interval lower bound.
- `maximum` - optional interval upper bound.

`TreemapLegendView` consumes these entries, and custom legend implementations can use them without depending on a particular scale class.

**`treemapContrastingTextColor(color)`** - chooses black or white text from a background luminance threshold.

- `color` - background color to inspect.
- return value - opaque black for luminance above `0.42`, otherwise opaque white.

This is the default basis for canvas label color resolution.

**`treemapColorFraction(scale, value)`** - normalizes a numeric value within a continuous scale domain.

- `scale` - scale supplying minimum and maximum.
- `value` - candidate numeric value.
- return value - clamped fraction from `0` to `1`; returns `0` for non-numeric values or scales without a continuous domain.

Bar legends use the fraction to position their current-value pointer.

**`treemapSampleScale(scale, {count})`** - produces colors for a custom discrete or continuous legend.

- `scale` - scale to sample.
- `count` - requested continuous sample count; defaults to `32` and produces at least two samples.
- return value - sampled domain colors, or existing legend-entry colors when the scale has no numeric domain.

Use a higher count for a smoother custom gradient at the cost of more color stops.

### Canvas labels

**`TreemapLabelConfig<K>`** - formatting, measurement, overflow, and text-style policy for `TreemapCanvasLabels<K>`.

- `showTitle` - whether the built-in resolver emits a title line; defaults to true.
- `showValue` - whether the built-in resolver emits a value line; defaults to true.
- `titleFormatter` - optional complete title formatter receiving `TreemapNodeDetails<K>`.
- `valueFormatter` - optional locale-independent value formatter.
- `localizedValueFormatter` - optional formatter receiving node details and the inherited `Locale`.
- `fallbackTitle` - title used when neither a source label nor a source key is available, normally for an aggregate; defaults to `Other`.
- `weightFractionDigits` - decimal precision for non-integer default weights; defaults to `2`.
- `titleStyle` - base title style when appearance does not override it.
- `valueStyle` - base value style when appearance does not override it.
- `valueColorOpacity` - opacity applied to the inferred value color; defaults to `0.82`.
- `colorResolver` - derives the base text color from resolved tile appearance.
- `linesBuilder` - optional complete replacement for built-in title/value line construction.
- `maxLines` - maximum lines per individual `TextPainter`; defaults to `1`.
- `overflow` - Flutter text overflow mode; defaults to ellipsis.
- `ellipsis` - non-empty ellipsis marker; defaults to `...`.
- `alignment` - position of the complete line block inside padded bounds; defaults to top-left.
- `textDirection` - optional explicit text direction; inherited direction is used when absent.

Formatter precedence is localized formatter, ordinary value formatter, node `valueLabel`, then formatted weight. `linesBuilder` retains clipping, text scaling, cached measurement, alignment, and overflow while replacing the generated lines. A localized formatter requires a `Localizations` ancestor.

**`TreemapCanvasLabelLine`** - one complete styled line returned by a custom canvas `linesBuilder`.

- `text` - required text to measure and paint.
- `style` - required complete `TextStyle`.

Return an iterable of these values when text belongs on canvas but built-in title/value construction is too restrictive. Use `TreemapWidgetLabels` when the content itself must be a widget.

## Interaction, selection, and navigation

**`TreemapInteractionConfig<K>`** - pointer, keyboard, built-in behavior, and typed callback policy for a chart.

- `enabled` - master input switch; defaults to true. Disabled nodes receive `TreemapVisualState.disabled`.
- `enableBuiltInBehavior` - whether selection, tooltip activation, and navigation run after callbacks; defaults to true.
- `zoomOnNodeTap` - whether ordinary activation drills into branches and can zoom out from the deepest level; defaults to true.
- `selectOnNodeTap` - whether activation updates selection; defaults to false.
- `longPressDuration` - delay before the long-press callback; defaults to Flutter's `kLongPressTimeout`.
- `tapSlop` - maximum movement still treated as tap or long press; defaults to `kTouchSlop`.
- `hitTestPadding` - expansion around geometry during hit testing; defaults to `0`.
- `directionalCrossAxisWeight` - cross-axis cost used by spatial arrow-key traversal; defaults to `0.35`.
- `onNodeTap` - callback receiving the deepest activated node before built-in behavior.
- `onNodeLongPress` - callback receiving a long-pressed node.
- `onHoverChanged` - callback receiving the current node or null when hover exits.
- `onSelectionChanged` - callback receiving the complete next selection and changed node.
- `cursorResolver` - maps current hover details, or null, to a `MouseCursor`.

Activating a branch drills into it. Activating a deepest leaf with no custom `onNodeTap` zooms out. Holding Control, Meta, Alt, or Shift requests zoom-out instead. Arrow keys move spatially; Enter and Space activate; Escape and Backspace zoom out.

**`TreemapSelectionConfig<K>`** - controls ownership and tap behavior for node selection.

- `selected` - non-null immutable set means controlled selection; null delegates storage to `TreemapController`.
- `toggleable` - whether activating an already selected entry removes it; defaults to true.
- `allowMultiple` - whether activation retains earlier selected entries; defaults to false.
- `fallbackToNearestAncestor` - retained nearest-ancestor selection preference; defaults to false. The current chart selection path does not consume this flag.

Selection uses `TreemapKey<K>` rather than `K` so generated aggregate blocks can participate without masquerading as source data. In controlled mode, update application state from `onSelectionChanged`; the chart does not mutate the supplied set.

```dart
Set<TreemapKey<String>> selected = {
  const TreemapKey.source('mobile'),
};

TreemapChart<String>(
  root: root,
  tiles: TreemapTiles(appearance: appearance),
  selection: TreemapSelectionConfig(selected: selected),
  interaction: TreemapInteractionConfig(
    zoomOnNodeTap: false,
    selectOnNodeTap: true,
    onSelectionChanged: (next, changed) {
      setState(() => selected = next);
    },
  ),
)
```

**`TreemapController<K>`** - observable owner of drill-down focus, navigation path, hover, and uncontrolled selection.

- `maximumSelections` - maximum programmatic selection count; defaults to `1`. Use null for no limit.
- `focusKey` - current source or aggregate focus identity.
- `currentPath` - immutable path to the current focus.
- `canZoomOut` - whether the current path has an ancestor.
- `selectedEntries` - immutable source and aggregate selection identities.
- `selectedKeys` - source-domain keys only; generated aggregate selections are excluded.
- `hoveredKey` - current source or aggregate hover identity.
- `hoveredColor` - source color/scale input associated with hover, used by bar legends.
- `zoomTo(key)` - focuses a source branch.
- `zoomIn([key])` - focuses an explicit key or the hovered/selected source node.
- `zoomOut()` - focuses the previous path entry.
- `reset()` - focuses the source root.
- `revealAggregate(details)` - focuses the source members represented by aggregate geometry.
- `select(key, {toggle})` - selects a source-domain key.
- `selectEntry(key, {toggle})` - selects a source or aggregate identity.
- `setSelection(keys)` - replaces uncontrolled selection while enforcing `maximumSelections`.
- `clearSelection()` - removes uncontrolled selection.

Supply a controller when toolbars, breadcrumbs, legends, or sibling widgets need to observe or command the chart. Dispose a controller your widget creates; `TreemapChart` disposes only its own internal controller. On data updates, `synchronize` removes vanished selections and hover, preserves surviving focus, and falls back to the nearest surviving ancestor.

```dart
class _DashboardState extends State<Dashboard> {
  final controller = TreemapController<String>(maximumSelections: 3);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Row(
            children: [
              FilledButton(
                onPressed: () => controller.zoomTo('products'),
                child: const Text('Products'),
              ),
              TextButton(
                onPressed: controller.canZoomOut ? controller.zoomOut : null,
                child: const Text('Back'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TreemapChart<String>(
            root: root,
            controller: controller,
            tiles: TreemapTiles(appearance: appearance),
            surrounding: const TreemapBreadcrumbs(),
          ),
        ),
      ],
    );
  }
}
```

**`TreemapCommandResult<K>`** - typed outcome of a controller navigation command.

- `status` - `completed`, `unchanged`, `missingKey`, `leafCannotBeFocused`, or `noAncestor`.
- `key` - optional source or aggregate target identity.
- `message` - optional failure explanation.
- `succeeded` - true only for `completed`.

Normal navigation failures return this object rather than throwing, which makes toolbar feedback and disabled states straightforward.

## Tooltips

**`TreemapTooltip<K>`** - standard `TreemapTooltipLayer<K>` adapter combining content, lifecycle configuration, and positioned output.

- `builder` - required node widget builder for tooltip content.
- `config` - activation, placement, sizing, lifecycle, and shell configuration; defaults to `TreemapTooltipConfig()`.

The chart owns target tracking and calls this layer for the deepest visible block. Content and container builders are independent, so application data formatting does not need to recreate positioning or decoration.

**`TreemapTooltipConfig`** - behavior and presentation-shell policy for the standard tooltip layer.

- `activation` - `hover`, `tap`, or `hoverAndTap`; defaults to combined activation.
- `placement` - `auto`, `above`, `below`, `left`, or `right`; defaults to auto.
- `fitInside` - clamps tooltip position to viewport bounds; defaults to true.
- `hideDelay` - duration before a tapped tooltip hides; defaults to two seconds.
- `margin` - gap between tooltip and target rectangle; defaults to eight pixels.
- `maxWidth` - maximum content width; defaults to 280 pixels.
- `containerBuilder` - builds the complete shell around content; defaults to `TreemapTooltipContainer`.
- `suppressDuringAnimation` - hides the tooltip while geometry moves; defaults to true.

Auto placement prefers above when it fits and otherwise uses below. `fitInside` can alter that ideal position to keep the complete tooltip visible.

**`TreemapTooltipView<K>`** - standalone positioned tooltip widget for custom `Stack` compositions.

- `details` - target node and rectangle.
- `config` - placement, sizing, and shell policy.
- `builder` - content builder.

`TreemapTooltip<K>` creates this view automatically. Use it directly only when implementing a custom tooltip layer or external geometry composition.

**`TreemapTooltipContainer`** - reusable standard decorated shell around tooltip content.

- `child` - required content widget.
- `decoration` - background decoration; defaults to a dark translucent rounded box.
- `padding` - content inset; defaults to 12 horizontal and 8 vertical pixels.

Configure this widget from `TreemapTooltipConfig.containerBuilder` when only the standard shell's appearance should change.

## Surrounding grid

**`TreemapSurroundingGrid<K>`** - strict, direction-aware 3×3 composition whose center is always the treemap viewport.

- `topStart`, `topCenter`, `topEnd` - content in the top row.
- `middleStart`, `middleEnd` - side content beside the treemap.
- `bottomStart`, `bottomCenter`, `bottomEnd` - content in the bottom row.
- `padding` - inset around the complete grid; defaults to zero.
- `rowGap`, `columnGap` - nonnegative gaps between rows and cells; default to zero.
- `clipBehavior` - grid painting clip; defaults to `Clip.none`.

Slots accept `TreemapSurroundingContent<K>`, so built-in breadcrumbs and legends can be used directly. Use `TreemapSurroundingContent.widget` for an ordinary widget or `TreemapSurroundingContent.builder` when content needs the active chart controller.

**`TreemapSurroundingGrid.fromMap(content)`** - dynamic alternative to the named-slot constructor. The map associates `TreemapOverlayPosition` values with surrounding content and is read immediately rather than retained. Optional padding, gaps, and clipping have the same defaults as the named constructor.

The grid uses ordinary Flutter flex layout rather than measuring shared tracks. Populated top and bottom rows contain three equal-width logical cells, align content according to the slot name, and take the maximum natural height of their children. A lone `topCenter` or `bottomCenter` spans its full row, and empty top or bottom rows are omitted. The middle row receives the remaining height; its optional start and end widgets use their own widths and the treemap expands through everything left over. With no middle-side content, the treemap spans the full width.

Sizing and overflow belong to supplied content. Use `SizedBox` for a fixed row contribution, `ConstrainedBox` for bounds, and scrolling or text overflow inside the slot when necessary. For example, wrapping one top-row child in `SizedBox(height: 56)` makes that row at least 56 pixels high. If content cannot fit, Flutter's normal flex-overflow diagnostics apply; the grid does not compress or reject it with custom sizing errors.

Start and end resolve through ambient `Directionality`: they map to left and right in LTR and swap in RTL. Because rows and cells do not overlap, normal Flutter paint and hit-test order applies. `Clip.none` preserves ordinary overflow painting; other clip values wrap the composition in `ClipRect`.

## Breadcrumbs

**`TreemapBreadcrumbs<K>`** - controller-driven surrounding content that can also place navigation breadcrumbs directly on one side of the chart.

- `config` - placement, overflow, builders, and wrapper configuration; defaults to `TreemapBreadcrumbsConfig<K>()`.

It implements both `TreemapSurroundingContent<K>` and `TreemapSurroundingLayer<K>` and creates `TreemapBreadcrumbsView<K>` with the chart's active controller. `config.position` controls direct layer placement; a `TreemapSurroundingGrid` slot controls placement when the breadcrumb is grid content.

**`TreemapBreadcrumbsView<K>`** - standalone breadcrumb widget that observes controller focus and builds actionable ancestors.

- `controller` - required navigation controller to observe and command.
- `config` - breadcrumb construction and overflow policy.

The current item has no navigation action. Ancestor items call `zoomToPathEntry`, while generated aggregate paths retain their current navigation semantics.

**`TreemapBreadcrumbsConfig<K>`** - complete construction and overflow policy for a breadcrumb row.

- `position` - directional grid cell; defaults to `topCenter`.
- `separatorBuilder` - builds a fresh separator between adjacent entries.
- `overflow` - `wrap`, `scroll`, or `ellipsis`; defaults to horizontal scrolling.
- `itemBuilder` - builds each complete item from context, path entry, current state, and optional action.
- `wrapperBuilder` - wraps the complete breadcrumb surface with layout or decoration.
- `ellipsisMaximumChildren` - positive number of trailing widgets retained in ellipsis mode; defaults to `5`.
- `overflowIndicatorBuilder` - builds the marker shown before retained content.

Builders own complete widgets, including semantics and interaction. The defaults compose `TreemapBreadcrumbItem`, `TreemapBreadcrumbSeparator`, and `TreemapOverlayContainer`.

**`TreemapBreadcrumbItem`** - standard accessible, animated breadcrumb item used by the default builder.

- `label` - required visible text.
- `isCurrent` - required current-level state.
- `onPressed` - ancestor navigation action; normally null for the current item.
- `semanticLabel` - optional spoken label replacing visible text.
- `animationDuration` - indicator animation duration; defaults to 180 milliseconds.
- `animationCurve` - indicator animation curve; defaults to linear.
- `indicatorColor` - current-level color; defaults to the theme primary color.
- `inactiveIndicatorColor` - ancestor indicator color; defaults to transparent.
- `indicatorWidth` - bottom indicator thickness; defaults to two pixels.
- `textStyle` - optional label style; defaults to theme body-medium.
- `maxLines` - positive label line limit; defaults to `1`.
- `overflow` - text overflow policy; defaults to ellipsis.
- `buttonStyle` - optional containing `TextButton` style.

The widget marks current items selected in semantics and ancestor items as buttons. Use it inside a custom `itemBuilder` to retain standard behavior with application-specific styling.

**`TreemapBreadcrumbSeparator`** - standard centered separator between adjacent breadcrumb items.

- `label` - separator text; defaults to `›`.
- `dimension` - square reserved extent; defaults to 16 pixels.
- `textStyle` - separator style; defaults to a compact 16-pixel style.

Use the config's separator builder to replace it with an icon or localized glyph.

## Legends

**`TreemapLegend<K>`** - surrounding content that can also place a color-scale legend directly around the chart and connects hover state when needed.

- `scale` - required scale supplying colors, entries, and optional continuous domain.
- `config` - required discrete or bar legend configuration.

It implements both surrounding contracts and creates `TreemapLegendView<K>` with the active chart controller. A bar pointer follows `controller.hoveredColor`; a discrete legend does not require controller state. `config.position` controls direct layer placement but is ignored in favor of the selected grid slot when used inside `TreemapSurroundingGrid`.

**`TreemapLegendView<K>`** - standalone legend renderer for use inside or outside a chart.

- `scale` - required color scale.
- `config` - required legend structure and builders.
- `controller` - optional controller used to move a bar pointer from hover values.

Without a controller, a bar legend still renders its colors and labels but has no current-value pointer.

**`TreemapLegendConfig.discrete`** - configures separate legend items for exact values, categories, or numeric ranges.

- `position` - directional grid cell; defaults to `bottomCenter`.
- `title` - optional title.
- `overflow` - wrap or scroll behavior; defaults to wrap.
- `direction` - item flow axis; defaults to horizontal.
- `wrapperBuilder` - complete legend shell builder.
- `spacing` - gap between title/items and individual runs; defaults to eight pixels.
- `semanticsLabel` - base spoken label; defaults to `Treemap legend`.
- `titleBuilder` - complete title builder.
- `labelBuilder` - builder for each entry label.
- `itemBuilder` - complete color-and-label item builder.
- `runSpacing` - cross-run gap in wrap mode; defaults to four pixels.

The default builders compose theme text, `TreemapLegendItem`, and `TreemapOverlayContainer`.

**`TreemapLegendConfig.bar`** - configures a continuous sampled or segmented color bar and optional hover pointer.

- `position` - directional grid cell; defaults to `bottomCenter`.
- `title` - optional title.
- `overflow` - surrounding overflow policy; defaults to scroll.
- `direction` - horizontal or vertical bar axis; defaults to horizontal.
- `wrapperBuilder` - complete legend shell builder.
- `spacing` - gap between title, bar, and related content; defaults to eight pixels.
- `semanticsLabel` - base spoken label; defaults to `Treemap legend`.
- `titleBuilder` - complete title builder.
- `labelBuilder` - endpoint label builder.
- `segmented` - uses legend-entry colors instead of continuous sampling; defaults to false.
- `barBuilder` - builds the complete bar from resolved colors and direction.
- `pointerBuilder` - builds the current-value marker from color and normalized fraction.
- `horizontalBarSize` - defaults to 160 by 20 pixels.
- `verticalBarSize` - defaults to 20 by 120 pixels.
- `pointerExtent` - main-axis pointer extent used for centering; defaults to 18 pixels.
- `horizontalPointerOffset` - distance the pointer extends above a horizontal bar; defaults to 16 pixels.
- `verticalPointerOffset` - distance the pointer extends left of a vertical bar; defaults to 18 pixels.
- `showLabels` - displays first and last scale labels; defaults to true.
- `sampleCount` - number of colors sampled from a continuous scale; defaults to `32`.

Use `segmented: true` for hard color bands. Continuous scales otherwise produce a smooth sampled bar.

**`TreemapLegendItem`** - standard discrete legend composition of a swatch and caller-built label.

- `color` - required swatch color.
- `label` - required label widget.
- `swatchSize` - square swatch extent; defaults to 12 pixels.
- `spacing` - horizontal gap before the label; defaults to four pixels.
- `swatchBorderRadius` - swatch corners; defaults to two pixels.
- `swatchBorder` - optional swatch border.

Configure it from a custom legend item builder when standard structure is suitable but sizing or decoration differs.

**`TreemapLegendBar`** - standard directional gradient used by bar legends.

- `colors` - required ordered list with at least two colors.
- `direction` - required axis; colors run left-to-right or bottom-to-top.
- `borderRadius` - bar corners; defaults to three pixels.
- `stops` - optional normalized position for each color; length must match `colors`.
- `tileMode` - gradient behavior outside its endpoints; defaults to clamp.

The legend config determines whether these colors came from continuous sampling or discrete segments.

**`TreemapLegendPointer`** - standard text-glyph marker for the current value on a color bar.

- `symbol` - marker glyph; defaults to `▼`.
- `dimension` - square reserved extent; defaults to 18 pixels.
- `color` - optional marker color; defaults to theme on-surface.
- `textStyle` - optional additional text styling.

The legend rotates this widget for vertical bars and positions it from `treemapColorFraction`.

## Shared overlay types

**`TreemapOverlayContainer`** - reusable shell for breadcrumb, legend, or other surrounding content.

- `child` - required overlay content.
- `padding` - inset around content; defaults to zero.
- `decoration` - optional background decoration.

Use it from wrapper builders to change standard padding or decoration without recreating layer composition.

**`TreemapOverlayPosition`** - one of eight direction-aware cells around the treemap.

- `topStart`, `topCenter`, `topEnd` - cells in the natural-height top row.
- `middleStart`, `middleEnd` - caller-sized cells beside the expanding treemap.
- `bottomStart`, `bottomCenter`, `bottomEnd` - cells in the natural-height bottom row.

A lone top or bottom center cell spans the full row. Start and end resolve through ambient `Directionality`.

**`TreemapOverflowMode`** - shared insufficient-space policy for breadcrumbs and legends.

- `wrap` - continues items on additional runs.
- `scroll` - exposes overflow through scrolling.
- `ellipsis` - retains a compact subset and marks omitted content.

Individual layers define which modes they support and how the compact subset is selected.

## Accessibility, locale, and visual state

**`TreemapSemantics<K>`** - standard accessibility layer for canvas-rendered treemap nodes.

- `labelResolver` - optional spoken-label resolver.
- `valueResolver` - optional spoken-value resolver.
- `hintResolver` - optional hierarchy or interaction-hint resolver.

It exposes visible blocks with label, value, hierarchy hint, selection/focus state, and activation actions. Supply it explicitly because canvas tile and label layers do not create semantics nodes.

**`TreemapVisualState`** - state values supplied to appearance resolvers and custom layer builders.

- `hovered` - pointer currently targets the node.
- `selected` - node belongs to effective selection.
- `focused` - node is the keyboard-navigation target.
- `disabled` - chart interaction is disabled.

State sets can contain multiple values. Appearance merges hover, selection, and focus in a defined order before applying the final node resolver.

The chart reads `Directionality`, `MediaQuery.textScaler`, and reduced-motion settings from context. Canvas labels can use `localizedValueFormatter`; custom presentation layers receive the same direction and scale through `TreemapVisualContext`. Layout direction remains independent, so an RTL interface can explicitly choose whether geometry also begins at the right edge.

For a keyboard-first chart, supply `TreemapSemantics`, set `autofocus` only when appropriate for the screen, and keep `interaction.enabled` true.

## Empty, invalid, and changing data

- An empty child list makes a source node a leaf.
- A source root with no children, or a hierarchy with no positive descendant weight, produces no geometry and renders `SizedBox.shrink`.
- Invalid source data throws `TreemapValidationException<K>`; invalid core layout values or geometry throw `TreemapLayoutException`. Oversized surrounding content follows Flutter's normal flex-overflow diagnostics.
- Reuse stable source keys when data changes. The controller preserves surviving focus, selection, and hover and falls back to a surviving focus ancestor.
- Generated aggregate keys are layout identities, not domain IDs. Use `aggregateMembers` or `revealAggregate` instead of persisting them as business data.

## Choosing the right extension point

| Requirement | Start with |
|---|---|
| Standard colored rectangles | `TreemapTiles` + `TreemapAppearanceResolver` |
| Lots of text labels | `TreemapCanvasLabels` + `TreemapLabelConfig` |
| Icons, images, badges, or rich labels | `TreemapWidgetLabels` |
| Entirely custom tile widgets | `TreemapBuilderTileLayer` |
| Extra paint above or below tiles | `TreemapCompositeTileLayer` |
| Custom layout of immediate siblings | `ITreemapLayoutStrategy` |
| Headless geometry | `TreemapLayoutEngine` |
| External navigation/selection controls | `TreemapController` |
| Custom accessibility tree | `TreemapSemanticsLayer` |
| One custom composition around the viewport | `TreemapSurroundingLayer` |
| Breadcrumbs, legends, or controls in a strict 3×3 grid | `TreemapSurroundingGrid` |
