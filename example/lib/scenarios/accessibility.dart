import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../scenario.dart';

final accessibilityScenarios = <ExampleScenario>[
  ExampleScenario(
    id: 'accessibility-keyboard-semantics',
    title: 'Keyboard and semantics',
    category: 'Accessibility',
    description:
        'Explicitly adds TreemapSemantics to the otherwise semantics-free core. It exposes navigable branches plus six leaves with values 55, 30, 15, 38, 24, and 18; arrow keys move spatially, Enter/Space activates and selects, and Escape/Backspace returns from a drilled branch.',
    builder: (_) => Column(
      children: [
        const Text('Use arrow keys, Enter/Space, and Escape/Backspace.'),
        Expanded(
          child: TreemapChart<String>(
            root: sampleTree(),
            tiles: sampleTiles(),
            labels: sampleLabels(),
            semantics: const TreemapSemantics(),
            autofocus: true,
            interaction: const TreemapInteractionConfig(selectOnNodeTap: true),
          ),
        ),
      ],
    ),
  ),
  ExampleScenario(
    id: 'accessibility-rtl',
    title: 'RTL labels, tooltip, and geometry',
    category: 'Accessibility',
    description:
        'Renders the 100-total Consumer and 80-total Business branches with TextDirection.rtl and a top-right origin. Labels, “label: weight” tooltips, breadcrumbs, hit testing, and geometry remain aligned in RTL.',
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: TreemapChart<String>(
        root: sampleTree(),
        tiles: sampleTiles(),
        labels: sampleLabels(),
        semantics: const TreemapSemantics(),
        layout: TreemapLayoutConfig(
          policy: TreemapLayoutPolicy(
            rootRule: const TreemapLayoutRule(
              direction: TreemapLayoutDirection.topRight,
            ),
          ),
        ),
        surrounding: const TreemapBreadcrumbs(),
        tooltip: TreemapTooltip(
          builder: (context, details) => DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Text('${details.label}: ${details.weight}'),
          ),
        ),
      ),
    ),
  ),
  ExampleScenario(
    id: 'accessibility-text-theme',
    title: 'Large text and dark theme',
    category: 'Accessibility',
    description:
        'Forces 180% text scaling, dark Material 3, and disableAnimations true over the six sample leaves with weights 55, 30, 15, 38, 24, and 18. Geometry remains data-driven: canvas labels ellipsize within each leaf or are omitted when their two-line block is taller than the available rectangle.',
    builder: (context) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: const TextScaler.linear(1.8),
          disableAnimations: true,
        ),
        child: Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: TreemapChart<String>(
            root: sampleTree(),
            tiles: sampleTiles(),
            labels: sampleLabels(),
            semantics: const TreemapSemantics(),
          ),
        ),
      );
    },
  ),
  ExampleScenario(
    id: 'accessibility-locale-formatting',
    title: 'Locale-aware value formatter',
    category: 'Accessibility',
    description:
        'Overrides the locale to de-DE and formats each visible weight with one decimal place and a comma: Mobile 55 becomes “de: 55,0”, Web 30 becomes “de: 30,0”, and the remaining four leaves follow the same formatter.',
    builder: (context) => Localizations.override(
      context: context,
      locale: const Locale('de', 'DE'),
      child: TreemapChart<String>(
        root: sampleTree(),
        tiles: sampleTiles(),
        labels: sampleLabels(
          config: TreemapLabelConfig(
            localizedValueFormatter: (details, locale) {
              final number = details.weight
                  .toStringAsFixed(1)
                  .replaceAll('.', ',');
              return '${locale.languageCode}: $number';
            },
          ),
        ),
      ),
    ),
  ),
  ExampleScenario(
    id: 'accessibility-reduced-motion',
    title: 'Reduced motion',
    category: 'Accessibility',
    description:
        'Configures a 2-second chart animation but sets MediaQuery.disableAnimations to true. Geometry for Consumer 100 and Business 80 therefore updates without motion, honoring the platform reduced-motion preference.',
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: TreemapChart<String>(
        root: sampleTree(),
        tiles: sampleTiles(),
        labels: sampleLabels(),
        transition: const TreemapTransitionSpec(
          duration: Duration(seconds: 2),
          curve: Curves.easeInOutCubic,
        ),
      ),
    ),
  ),
];
