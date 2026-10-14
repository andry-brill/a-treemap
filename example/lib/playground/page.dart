import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'datasets.dart';
import 'inputs.dart';
import 'presets.dart';
import 'preview.dart';
import 'property_editor.dart';
import 'store.dart';

class PlaygroundPage extends StatelessWidget {
  const PlaygroundPage({super.key, required this.store});
  final PlaygroundStore store;

  Future<void> _copy(BuildContext context) async {
    store.commitValidDrafts();
    final uri = Uri.base.replace(
      queryParameters: store.location.uri.queryParameters,
      fragment: '',
    );
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const Text('any_treemap playground'),
            titleTextStyle: Theme.of(context).textTheme.titleMedium,
            leading: wide
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      key: const ValueKey('open-properties'),
                      tooltip: 'Properties',
                      icon: const Icon(Icons.tune),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            actions: [
              IconButton(
                key: const ValueKey('copy-link'),
                tooltip: 'Copy link',
                icon: const Icon(Icons.link),
                onPressed: () => _copy(context),
              ),
              IconButton(
                key: const ValueKey('reset-config'),
                tooltip: 'Reset configuration',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => store.selectPreset(defaultPresetKey),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : Drawer(
                  width: math.min(360, constraints.maxWidth),
                  child: SafeArea(child: PropertyPanel(store: store)),
                ),
          body: Column(
            children: [
              if (store.location.notices.isNotEmpty)
                MaterialBanner(
                  content: Text(
                    store.location.notices.take(3).join('\n') +
                        (store.location.notices.length > 3
                            ? '\nAdditional invalid properties were reset.'
                            : ''),
                    style: const TextStyle(fontSize: 12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: store.dismissNotices,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: Row(
                  children: [
                    if (wide) ...[
                      SizedBox(width: 360, child: PropertyPanel(store: store)),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: PlaygroundPreview(
                          config: store.preview,
                          resetGeneration: store.resetGeneration,
                          onPropertyChange: store.change,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class PropertyPanel extends StatefulWidget {
  const PropertyPanel({super.key, required this.store});
  final PlaygroundStore store;
  @override
  State<PropertyPanel> createState() => _PropertyPanelState();
}

class _PropertyPanelState extends State<PropertyPanel> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final preset = presetsByKey[store.exampleKey];
    final groups = <String, List<PlaygroundProperty>>{};
    for (final field in playgroundProperties.where(
      (field) => field.key != 'data',
    )) {
      if (_search.isNotEmpty &&
          !('${field.label} ${field.key} ${field.help}').toLowerCase().contains(
            _search,
          )) {
        continue;
      }
      groups.putIfAbsent(field.group, () => []).add(field);
    }
    return ListView(
      key: const ValueKey('property-panel'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Example',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const PropertyHelp(
              label: 'Example',
              message:
                  'Choose a saved configuration. Editing a property switches to Custom and puts the complete configuration in the URL.',
            ),
          ],
        ),
        Semantics(
          label: 'Example',
          child: LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              key: ValueKey(
                'example-chooser-${store.formGeneration}-${store.exampleKey ?? 'custom'}',
              ),
              width: constraints.maxWidth,
              initialSelection: store.exampleKey ?? '__custom',
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              textStyle: const TextStyle(fontSize: 13),
              inputDecorationTheme: const InputDecorationTheme(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              dropdownMenuEntries: [
                const DropdownMenuEntry(
                  value: '__custom',
                  label: 'Custom',
                  enabled: false,
                ),
                for (final group
                    in allPresets.map((preset) => preset.category).toSet()) ...[
                  DropdownMenuEntry(
                    value: '__group-$group',
                    label: group,
                    enabled: false,
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  for (final preset in allPresets.where(
                    (preset) => preset.category == group,
                  ))
                    DropdownMenuEntry(value: preset.id, label: preset.title),
                ],
              ],
              onSelected: (key) {
                if (presetsByKey.containsKey(key)) {
                  FocusScope.of(context).unfocus();
                  store.selectPreset(key!);
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            preset?.description ??
                'Custom configuration. Copy the link to share these settings.',
            key: const ValueKey('example-description'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        PropertyEditorField(
          key: ValueKey('data-${store.formGeneration}'),
          property: propertiesByKey['data']!,
          store: store,
        ),
        Text(
          datasetsByKey[store.preview.text('data')]!.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('property-search'),
          onChanged: (raw) =>
              setState(() => _search = raw.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Find a property',
            prefixIcon: Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No matching properties.'),
          ),
        for (final group in groups.entries)
          ExpansionTile(
            key: ValueKey('property-group-${group.key}-${_search.isNotEmpty}'),
            title: Text(
              group.key,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            initiallyExpanded:
                _search.isNotEmpty ||
                group.key == 'Data' ||
                group.key == 'Layout',
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            children: [
              for (final property in group.value)
                PropertyEditorField(
                  key: ValueKey('${property.key}-${store.formGeneration}'),
                  property: property,
                  store: store,
                ),
            ],
          ),
      ],
    );
  }
}
