import 'package:flutter/material.dart';

import 'config.dart';
import 'inputs.dart';
import 'store.dart';
import 'structured_editor.dart';

class PropertyEditorField extends StatelessWidget {
  const PropertyEditorField({
    super.key,
    required this.property,
    required this.store,
  });
  final PlaygroundProperty property;
  final PlaygroundStore store;

  @override
  Widget build(BuildContext context) {
    final value = store.preview.values[property.key];
    final enabled = property.enabled(store.preview);
    final error = store.errors[property.key];
    final raw = store.rawDraft(property.key) ?? property.encodeValue(value);
    final fieldKey = ValueKey('field-${property.key}');
    Widget control;
    switch (property.editor) {
      case PropertyEditor.toggle:
        control = Switch(
          key: fieldKey,
          value: value as bool,
          onChanged: enabled
              ? (value) => store.change(property.key, value)
              : null,
        );
      case PropertyEditor.choice:
        control = Semantics(
          label: property.label,
          child: DropdownButtonFormField<String>(
            key: ValueKey(raw),
            initialValue: value as String,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in property.choices.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: enabled
                ? (value) => store.change(property.key, value)
                : null,
          ),
        );
      case PropertyEditor.number:
        control = Column(
          children: [
            if (property.nullLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DropdownButtonFormField<bool>(
                  key: ValueKey(value == null),
                  initialValue: value == null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text(property.nullLabel!),
                    ),
                    const DropdownMenuItem(value: false, child: Text('Fixed')),
                  ],
                  onChanged: enabled
                      ? (automatic) {
                          var fixed =
                              (property.defaultValue as num?)?.toDouble() ??
                              property.minimum ??
                              0;
                          if (property.key == 'color.maximum') {
                            fixed =
                                (store.preview.optionalNumber(
                                      'color.minimum',
                                    ) ??
                                    0) +
                                1;
                          }
                          if (property.key == 'color.minimum') {
                            fixed =
                                (store.preview.optionalNumber(
                                      'color.maximum',
                                    ) ??
                                    1) -
                                1;
                          }
                          store.change(property.key, automatic! ? null : fixed);
                        }
                      : null,
                ),
              ),
            if (value != null || property.nullLabel == null)
              CommitInput(
                value: raw,
                fieldKey: fieldKey,
                semanticLabel: property.label,
                error: error,
                numeric: true,
                enabled: enabled,
                onChanged: (raw) => store.draftRaw(property.key, raw),
                onCommit: () => store.commitField(property.key),
              ),
            if (enabled &&
                value != null &&
                property.minimum != null &&
                property.maximum != null &&
                property.maximum! <= 256 &&
                property.minimum! >= 0)
              Slider(
                key: ValueKey('slider-${property.key}'),
                value: (value as num).toDouble().clamp(
                  property.minimum!,
                  property.maximum!,
                ),
                min: property.minimum!,
                max: property.maximum!,
                onChanged: (value) => store.draftRaw(
                  property.key,
                  property.key.contains('Ms') ||
                          property.key.contains('Count') ||
                          property.key.contains('Lines') ||
                          property.key.contains('Depth') ||
                          property.key.contains('Children') ||
                          property.key.contains('Digits') ||
                          property.key == 'data.revision'
                      ? value.round().toString()
                      : value.toStringAsFixed(2),
                ),
                onChangeEnd: (_) => store.commitField(property.key),
              ),
          ],
        );
      case PropertyEditor.color:
        control = Column(
          children: [
            if (property.nullLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DropdownButtonFormField<bool>(
                  key: ValueKey(value == null),
                  initialValue: value == null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text(property.nullLabel!),
                    ),
                    const DropdownMenuItem(
                      value: false,
                      child: Text('Override'),
                    ),
                  ],
                  onChanged: enabled
                      ? (inherit) => store.change(
                          property.key,
                          inherit! ? null : Colors.blue,
                        )
                      : null,
                ),
              ),
            if (value != null)
              ColorInput(
                raw: raw,
                error: error,
                enabled: enabled,
                fieldKey: fieldKey,
                semanticLabel: property.label,
                onChanged: (raw) => store.draftRaw(property.key, raw),
                onCommit: () => store.commitField(property.key),
                onPicked: (color) => store.change(property.key, color),
              ),
          ],
        );
      case PropertyEditor.text:
        control = CommitInput(
          value: raw,
          error: error,
          enabled: enabled,
          fieldKey: fieldKey,
          semanticLabel: property.label,
          onChanged: (raw) => store.draftRaw(property.key, raw),
          onCommit: () => store.commitField(property.key),
        );
      case PropertyEditor.palette:
      case PropertyEditor.ranges:
      case PropertyEditor.mappings:
      case PropertyEditor.rules:
        control = StructuredEditor(property: property, store: store);
    }
    control = ExcludeFocus(
      excluding: !enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(opacity: enabled ? 1 : .5, child: control),
      ),
    );
    return Padding(
      key: ValueKey('property-${property.key}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (property.editor == PropertyEditor.toggle) control,
              PropertyHelp(label: property.label, message: property.help),
            ],
          ),
          if (property.editor != PropertyEditor.toggle) control,
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                property.disabledReason(store.preview) ??
                    'Not used by this configuration.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
