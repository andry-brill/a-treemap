import '../scenario.dart';

final accessibilityScenarios = <ExamplePreset>[
  ExamplePreset(
    id: "accessibility-keyboard-semantics",
    title: "Keyboard and semantics",
    category: "Accessibility",
    description:
        "Arrow keys move focus, Enter/Space activates, and Escape/Backspace returns from drill-down.",
    dataKey: "markets",
    overrides: {
      "semantics.enabled": true,
      "preview.autofocus": true,
      "interaction.selectOnTap": true,
    },
  ),
  ExamplePreset(
    id: "accessibility-rtl",
    title: "RTL labels, tooltip, and geometry",
    category: "Accessibility",
    description:
        "RTL presentation and top-right geometry remain aligned. Text direction and layout origin can be changed separately.",
    dataKey: "markets",
    overrides: {
      "environment.direction": "rtl",
      "layout.origin": "topRight",
      "tooltip.enabled": true,
      "breadcrumbs.enabled": true,
      "semantics.enabled": true,
    },
  ),
  ExamplePreset(
    id: "accessibility-text-theme",
    title: "Large text and dark theme",
    category: "Accessibility",
    description:
        "Dark theme and 180% preview text scale demonstrate bounded labels. Editor text stays unchanged.",
    dataKey: "markets",
    overrides: {
      "environment.theme": "dark",
      "environment.textScale": 1.8,
      "environment.reducedMotion": true,
      "semantics.enabled": true,
    },
  ),
  ExamplePreset(
    id: "accessibility-locale-formatting",
    title: "Locale-aware value formatter",
    category: "Accessibility",
    description:
        "The German formatter shows weights with one decimal and a comma, such as 55,0.",
    dataKey: "markets",
    overrides: {
      "environment.locale": "de-DE",
      "labels.localizedFormatter": "decimal",
    },
  ),
  ExamplePreset(
    id: "accessibility-reduced-motion",
    title: "Reduced motion",
    category: "Accessibility",
    description:
        "A configured two-second transition becomes immediate when reduced motion is enabled. Change Data revision to compare.",
    dataKey: "markets",
    overrides: {
      "animation.enabled": true,
      "animation.durationMs": 2000,
      "environment.reducedMotion": true,
    },
  ),
];
