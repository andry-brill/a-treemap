import 'package:flutter/material.dart';

import 'scenario.dart';
import 'scenarios/accessibility.dart';
import 'scenarios/appearance.dart';
import 'scenarios/data.dart';
import 'scenarios/interaction.dart';
import 'scenarios/layout.dart';

void main() => runApp(const TreemapExampleApp());

final allScenarios = <ExampleScenario>[
  ...dataScenarios,
  ...layoutScenarios,
  ...appearanceScenarios,
  ...interactionScenarios,
  ...accessibilityScenarios,
];

class TreemapExampleApp extends StatefulWidget {
  const TreemapExampleApp({super.key});

  @override
  State<TreemapExampleApp> createState() => _TreemapExampleAppState();
}

class _TreemapExampleAppState extends State<TreemapExampleApp> {
  late bool darkMode;

  @override
  void initState() {
    super.initState();
    darkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: TreemapCatalog(
        darkMode: darkMode,
        onToggleTheme: () => setState(() => darkMode = !darkMode),
      ),
    );
  }
}

class TreemapCatalog extends StatefulWidget {
  const TreemapCatalog({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<TreemapCatalog> createState() => _TreemapCatalogState();
}

class _TreemapCatalogState extends State<TreemapCatalog> {
  final scenarios = allScenarios;
  var selected = 0;

  @override
  Widget build(BuildContext context) {
    final scenario = scenarios[selected];
    final subduedForeground = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .68);
    return Scaffold(
      appBar: AppBar(
        title: const Text('any_treemap feature catalog'),
        actions: [
          Tooltip(
            message: widget.darkMode
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            child: IconButton(
              key: const ValueKey('theme-toggle'),
              onPressed: widget.onToggleTheme,
              icon: Icon(widget.darkMode ? Icons.light_mode : Icons.dark_mode),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final picker = _ScenarioPicker(
            scenarios: scenarios,
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(scenario.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scenario.category} · ${scenario.id}',
                      key: const ValueKey('scenario-header-metadata'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: subduedForeground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scenario.description,
                      key: const ValueKey('scenario-header-description'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: scenario.builder(context),
                ),
              ),
            ],
          );
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                SizedBox(width: 300, child: picker),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: constraints.maxHeight < 600 ? 180 : 260,
                child: picker,
              ),
              const Divider(height: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _ScenarioPicker extends StatefulWidget {
  const _ScenarioPicker({
    required this.scenarios,
    required this.selected,
    required this.onSelected,
  });

  final List<ExampleScenario> scenarios;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_ScenarioPicker> createState() => _ScenarioPickerState();
}

class _ScenarioPickerState extends State<_ScenarioPicker> {
  final collapsedGroups = <String>{};

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<int>>{};
    for (final entry in widget.scenarios.indexed) {
      groups.putIfAbsent(entry.$2.category, () => []).add(entry.$1);
    }
    return RepaintBoundary(
      key: const ValueKey('scenario-picker'),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          for (final group in groups.entries)
            _ScenarioGroup(
              category: group.key,
              expanded: !collapsedGroups.contains(group.key),
              onToggle: () => setState(() {
                if (!collapsedGroups.add(group.key)) {
                  collapsedGroups.remove(group.key);
                }
              }),
              children: [
                for (final index in group.value)
                  _ScenarioButton(
                    scenario: widget.scenarios[index],
                    selected: widget.selected == index,
                    onPressed: () => widget.onSelected(index),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScenarioGroup extends StatelessWidget {
  const _ScenarioGroup({
    required this.category,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String category;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupForeground = colorScheme.onSurfaceVariant.withValues(alpha: .68);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('scenario-group-$category'),
                borderRadius: BorderRadius.circular(10),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: groupForeground,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        key: ValueKey('scenario-group-icon-$category'),
                        color: groupForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
    required this.scenario,
    required this.selected,
    required this.onPressed,
  });

  final ExampleScenario scenario;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        key: ValueKey('scenario-tooltip-${scenario.id}'),
        message: scenario.description,
        waitDuration: const Duration(milliseconds: 350),
        child: Semantics(
          button: true,
          selected: selected,
          hint: scenario.description,
          child: Material(
            color: selected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: ValueKey('scenario-${scenario.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        scenario.title,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        key: ValueKey('scenario-check-${scenario.id}'),
                        size: 18,
                        color: foreground,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
