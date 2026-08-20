import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../scenario.dart';

Widget _tooltipContainer(BuildContext context, Widget child) =>
    TreemapTooltipContainer(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );

Widget _controllerBreadcrumb(
  BuildContext context,
  TreemapPathEntry<String> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) {
  final label =
      entry.label ?? entry.key.sourceKey?.toString() ?? 'Unnamed level';
  return TreemapBreadcrumbItem(
    label: label,
    isCurrent: isCurrent,
    onPressed: onPressed,
    animationDuration: const Duration(milliseconds: 260),
    indicatorColor: Colors.orange,
    indicatorWidth: 3,
    textStyle: const TextStyle(fontSize: 12),
    overflow: TextOverflow.fade,
  );
}

Widget _controllerBreadcrumbSeparator(BuildContext context) =>
    TreemapBreadcrumbSeparator(
      label: '/',
      dimension: 20,
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

Widget _controllerBreadcrumbOverflowIndicator(BuildContext context) => Text(
  '…',
  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
);

Widget _controllerBreadcrumbWrapper(BuildContext context, Widget child) =>
    TreemapOverlayContainer(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    );

final interactionScenarios = <ExampleScenario>[
  ExampleScenario(
    id: 'interaction-uncontrolled-selection',
    title: 'Uncontrolled selection',
    category: 'Interaction',
    description:
        'Lets the chart own one toggleable selection. Tap Mobile 55, Web 30, Desktop 15, Small 38, Medium 24, or Enterprise 18 to move or clear the selected state; zoom-on-tap is disabled.',
    builder: (_) => TreemapChart<String>(
      root: sampleTree(),
      tiles: sampleTiles(),
      labels: sampleLabels(),
      interaction: const TreemapInteractionConfig(
        selectOnNodeTap: true,
        zoomOnNodeTap: false,
      ),
    ),
  ),
  ExampleScenario(
    id: 'interaction-controlled-selection',
    title: 'Controlled selection',
    category: 'Interaction',
    description:
        'Starts with Mobile 55 selected. A parent State owns the Set<TreemapKey>, receives onSelectionChanged after a leaf tap, and rebuilds TreemapSelectionConfig with the proposed single selection.',
    builder: (_) => const _ControlledSelectionExample(),
  ),
  ExampleScenario(
    id: 'interaction-multi-selection',
    title: 'Multi-selection',
    category: 'Interaction',
    description:
        'Uses TreemapController(maximumSelections: null) with allowMultiple enabled. Repeatedly tap the six sample leaves to accumulate or toggle independent selections while their weights remain 55, 30, 15, 38, 24, and 18.',
    builder: (_) => const _MultiSelectionExample(),
  ),
  ExampleScenario(
    id: 'interaction-hover-tooltip',
    title: 'Hover and tooltip lifecycle',
    category: 'Interaction',
    description:
        'Uses TreemapTooltip with replaceable content and container builders. The container builder configures TreemapTooltipContainer with a theme-aware background, 8 px radius, and 12×8 px padding. Hover or tap any deepest visible leaf to show its exact label and weight—for example “Mobile: 55” or “Enterprise: 18”. Auto placement anchors to that leaf’s bounds, tapped tooltips hide after 1 second, and long press shows a SnackBar.',
    builder: (context) => TreemapChart<String>(
      root: sampleTree(),
      tiles: sampleTiles(),
      labels: sampleLabels(),
      tooltip: TreemapTooltip(
        config: const TreemapTooltipConfig(
          activation: TreemapTooltipActivation.hoverAndTap,
          placement: TreemapTooltipPlacement.auto,
          hideDelay: Duration(seconds: 1),
          containerBuilder: _tooltipContainer,
        ),
        builder: (context, details) => Text(
          '${details.label}: ${details.weight}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
        ),
      ),
      interaction: TreemapInteractionConfig(
        onNodeLongPress: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Long pressed ${details.label}')),
          );
        },
      ),
    ),
  ),
  ExampleScenario(
    id: 'interaction-drilldown-controller',
    title: 'Drill-down, controller, breadcrumbs',
    category: 'Navigation',
    description:
        'Use Consumer to zoom from the 180-total root into its 100-total branch (Mobile 55, Web 30, Desktop 15), then Back or Reset. Thin builders configure TreemapBreadcrumbItem, TreemapBreadcrumbSeparator, and TreemapOverlayContainer instead of recreating their widget trees; the two-child ellipsis limit hides the root after drill-down. The current item uses 12 px text, “Unnamed level” fallback, and a 260 ms orange 3 px indicator. Tile taps, leaf/modifier zoom-out, and buttons share the controller.',
    builder: (_) => const _ControllerExample(),
  ),
  ExampleScenario(
    id: 'interaction-aggregate-reveal',
    title: 'Reveal generated Other members',
    category: 'Navigation',
    description:
        'Lays out 40 leaves with repeating weights 1–11 and a 90 px minimum width. Small leaves become a generated Other tile; activate it to reveal its typed members, then use breadcrumbs or a deepest-leaf click to return.',
    builder: (_) => TreemapChart<String>(
      root: manyNodeTree(),
      tiles: sampleTiles(colorScale: manyNodeColorScale()),
      labels: sampleLabels(colorScale: manyNodeColorScale()),
      layout: TreemapLayoutConfig(
        minimumWidth: 90,
        minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
      ),
      surrounding: const TreemapBreadcrumbs(),
      interaction: const TreemapInteractionConfig(zoomOnNodeTap: true),
    ),
  ),
  ExampleScenario(
    id: 'interaction-updates-animation',
    title: 'Keyed updates and animation',
    category: 'Updates',
    description:
        'Press Update weights to toggle Mobile between 55 and 75 while Web stays 30 and Desktop 15. A 700 ms keyed resquarified transition preserves topology as Consumer changes from total 100 to 120 and back.',
    builder: (_) => const _AnimatedUpdateExample(),
  ),
  ExampleScenario(
    id: 'interaction-pointer-modes',
    title: 'Mouse, touch, stylus, long press',
    category: 'Interaction',
    description:
        'Move or press mouse, touch, or stylus input over the six weighted leaves. The example logs typed hover, tap, and long-press labels and resolves SystemMouseCursors.click whenever a visible node is under the pointer.',
    builder: (_) => TreemapChart<String>(
      root: sampleTree(),
      tiles: sampleTiles(),
      labels: sampleLabels(),
      interaction: TreemapInteractionConfig(
        cursorResolver: (details) =>
            details == null ? MouseCursor.defer : SystemMouseCursors.click,
        onNodeTap: (details) => debugPrint('tap ${details.label}'),
        onNodeLongPress: (details) => debugPrint('long ${details.label}'),
        onHoverChanged: (details) => debugPrint('hover ${details?.label}'),
      ),
    ),
  ),
];

class _ControlledSelectionExample extends StatefulWidget {
  const _ControlledSelectionExample();

  @override
  State<_ControlledSelectionExample> createState() =>
      _ControlledSelectionExampleState();
}

class _ControlledSelectionExampleState
    extends State<_ControlledSelectionExample> {
  Set<TreemapKey<String>> selection = {const TreemapKey.source('mobile')};

  @override
  Widget build(BuildContext context) => TreemapChart<String>(
    root: sampleTree(),
    tiles: sampleTiles(),
    labels: sampleLabels(),
    selection: TreemapSelectionConfig(selected: selection),
    interaction: TreemapInteractionConfig(
      selectOnNodeTap: true,
      zoomOnNodeTap: false,
      onSelectionChanged: (value, changed) => setState(() => selection = value),
    ),
  );
}

class _MultiSelectionExample extends StatefulWidget {
  const _MultiSelectionExample();

  @override
  State<_MultiSelectionExample> createState() => _MultiSelectionExampleState();
}

class _MultiSelectionExampleState extends State<_MultiSelectionExample> {
  final controller = TreemapController<String>(maximumSelections: null);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TreemapChart<String>(
    root: sampleTree(),
    tiles: sampleTiles(),
    labels: sampleLabels(),
    controller: controller,
    selection: TreemapSelectionConfig(allowMultiple: true),
    interaction: const TreemapInteractionConfig(
      selectOnNodeTap: true,
      zoomOnNodeTap: false,
    ),
  );
}

class _ControllerExample extends StatefulWidget {
  const _ControllerExample();

  @override
  State<_ControllerExample> createState() => _ControllerExampleState();
}

class _ControllerExampleState extends State<_ControllerExample> {
  final controller = TreemapController<String>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        children: [
          TextButton(
            onPressed: () => controller.zoomTo('consumer'),
            child: const Text('Consumer'),
          ),
          TextButton(onPressed: controller.zoomOut, child: const Text('Back')),
          TextButton(onPressed: controller.reset, child: const Text('Reset')),
        ],
      ),
      Expanded(
        child: TreemapChart<String>(
          root: sampleTree(),
          tiles: sampleTiles(),
          labels: sampleLabels(),
          controller: controller,
          surrounding: const TreemapBreadcrumbs(
            config: TreemapBreadcrumbsConfig(
              separatorBuilder: _controllerBreadcrumbSeparator,
              itemBuilder: _controllerBreadcrumb,
              wrapperBuilder: _controllerBreadcrumbWrapper,
              overflow: TreemapOverflowMode.ellipsis,
              ellipsisMaximumChildren: 2,
              overflowIndicatorBuilder: _controllerBreadcrumbOverflowIndicator,
            ),
          ),
        ),
      ),
    ],
  );
}

class _AnimatedUpdateExample extends StatefulWidget {
  const _AnimatedUpdateExample();

  @override
  State<_AnimatedUpdateExample> createState() => _AnimatedUpdateExampleState();
}

class _AnimatedUpdateExampleState extends State<_AnimatedUpdateExample> {
  var revision = 0.0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilledButton(
        onPressed: () => setState(() => revision = revision == 0 ? 20 : 0),
        child: const Text('Update weights'),
      ),
      Expanded(
        child: TreemapChart<String>(
          root: sampleTree(revision: revision),
          tiles: sampleTiles(),
          labels: sampleLabels(),
          transition: const TreemapTransitionSpec(
            duration: Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
          ),
          layout: TreemapLayoutConfig(
            policy: TreemapLayoutPolicy(
              rootRule: const TreemapLayoutRule(
                algorithm: TreemapLayoutAlgorithm.resquarified,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
