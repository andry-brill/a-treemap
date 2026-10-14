import '../scenario.dart';

final interactionScenarios = <ExamplePreset>[
  ExamplePreset(
    id: "interaction-uncontrolled-selection",
    title: "Uncontrolled selection",
    category: "Interaction",
    description:
        "Tap leaves to toggle one controller-owned selection. Drill-down is disabled.",
    dataKey: "markets",
    overrides: {
      "interaction.selectOnTap": true,
      "interaction.zoomOnTap": false,
    },
  ),
  ExamplePreset(
    id: "interaction-controlled-selection",
    title: "Controlled selection",
    category: "Interaction",
    description:
        "Mobile starts selected. The playground owns and accepts the proposed selection set.",
    dataKey: "markets",
    overrides: {
      "selection.controlled": true,
      "selection.initial": "mobile",
      "interaction.selectOnTap": true,
      "interaction.zoomOnTap": false,
    },
  ),
  ExamplePreset(
    id: "interaction-multi-selection",
    title: "Multi-selection",
    category: "Interaction",
    description:
        "Tap several leaves to accumulate or toggle selections without a controller limit.",
    dataKey: "markets",
    overrides: {
      "selection.allowMultiple": true,
      "selection.maximum": null,
      "interaction.selectOnTap": true,
      "interaction.zoomOnTap": false,
    },
  ),
  ExamplePreset(
    id: "interaction-hover-tooltip",
    title: "Hover and tooltip lifecycle",
    category: "Interaction",
    description:
        "Hover or tap a leaf for label and weight. A tapped tooltip hides after one second; long press shows a message.",
    dataKey: "markets",
    overrides: {
      "tooltip.enabled": true,
      "tooltip.hideDelayMs": 1000,
      "tooltip.containerBuilder": "rounded",
      "interaction.longPressCallback": "snackbar",
    },
  ),
  ExamplePreset(
    id: "interaction-drilldown-controller",
    title: "Drill-down, controller, breadcrumbs",
    category: "Interaction",
    description:
        "Drill into Consumer, then use Back or Reset. Breadcrumbs read presentation and send navigation actions.",
    dataKey: "markets",
    overrides: {
      "breadcrumbs.enabled": true,
      "breadcrumbs.overflow": "ellipsis",
      "breadcrumbs.itemBuilder": "indicator",
      "breadcrumbs.separatorBuilder": "slash",
      "breadcrumbs.wrapper": "rounded",
    },
  ),
  ExamplePreset(
    id: "interaction-aggregate-reveal",
    title: "Reveal generated Other members",
    category: "Interaction",
    description:
        "Activate Other to reveal the generated small-node members, then navigate back.",
    dataKey: "many-nodes",
    overrides: {
      "layout.minimumWidth": 90,
      "layout.minimumNodePolicy": "aggregate",
      "breadcrumbs.enabled": true,
      "color.scale": "interpolated",
      "color.minimum": 0,
      "color.maximum": 39,
    },
  ),
  ExamplePreset(
    id: "interaction-updates-animation",
    title: "Keyed updates and animation",
    category: "Interaction",
    description:
        "Change Data revision to increase Mobile by 20. Resquarified geometry animates for 700 milliseconds.",
    dataKey: "markets",
    overrides: {
      "layout.algorithm": "resquarified",
      "animation.enabled": true,
      "animation.durationMs": 700,
    },
  ),
  ExamplePreset(
    id: "interaction-pointer-modes",
    title: "Mouse, touch, stylus, long press",
    category: "Interaction",
    description:
        "Mouse, touch and stylus events appear in the preview readout. Hold for long press.",
    dataKey: "markets",
    overrides: {
      "interaction.tapCallback": "log",
      "interaction.longPressCallback": "log",
      "interaction.hoverCallback": "log",
      "interaction.cursor": "click",
    },
  ),
];
