import 'dart:convert';

import 'package:flutter/material.dart';

import 'config.dart';
import 'inputs.dart';
import 'store.dart';

/// Rows are edited as drafts; only a validated collection can become a URL.
class StructuredEditor extends StatefulWidget {
  const StructuredEditor({
    super.key,
    required this.property,
    required this.store,
  });
  final PlaygroundProperty property;
  final PlaygroundStore store;
  @override
  State<StructuredEditor> createState() => _StructuredEditorState();
}

class _StructuredEditorState extends State<StructuredEditor> {
  late List<Object?> _rows;
  late List<int> _ids;
  late List<bool> _numericMappings;
  int _nextId = 0;
  String _loaded = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _encoded =>
      widget.store.rawDraft(widget.property.key) ??
      widget.property.encodeValue(
        widget.store.preview.values[widget.property.key],
      );
  void _load() {
    _loaded = _encoded;
    _rows = (jsonDecode(_loaded) as List)
        .map((row) => row is Map ? Map<String, Object?>.from(row) : row)
        .toList();
    _ids = [for (final _ in _rows) _nextId++];
    _numericMappings = [
      for (final row in _rows)
        widget.property.editor == PropertyEditor.mappings &&
            ((row as Map)['valueType'] == 'number' || row['value'] is num),
    ];
  }

  @override
  void didUpdateWidget(covariant StructuredEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loaded != _encoded) _load();
  }

  void _emit({bool commit = false}) {
    _loaded = jsonEncode([
      for (final entry in _rows.indexed)
        if (widget.property.editor == PropertyEditor.mappings)
          {
            ...(entry.$2 as Map<String, Object?>),
            'valueType': _numericMappings[entry.$1] ? 'number' : 'text',
          }
        else
          entry.$2,
    ]);
    widget.store.draftRaw(widget.property.key, _loaded);
    if (commit) widget.store.commitField(widget.property.key);
  }

  void _set(int index, String key, Object? value, {bool commit = false}) {
    setState(() => (_rows[index] as Map<String, Object?>)[key] = value);
    _emit(commit: commit);
  }

  Widget _text(int index, String key, String label, {bool numeric = false}) {
    final value = (_rows[index] as Map)[key];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: CommitInput(
        fieldKey: ValueKey('row-${widget.property.key}-${_ids[index]}-$key'),
        label: label,
        value: value?.toString() ?? '',
        numeric: numeric,
        onChanged: (raw) =>
            _set(index, key, numeric ? num.tryParse(raw) ?? raw : raw),
        onCommit: () => widget.store.commitField(widget.property.key),
      ),
    );
  }

  Widget _choice(
    int index,
    String key,
    String label,
    Map<String, String> options, {
    String fallback = 'inherit',
  }) {
    final row = _rows[index] as Map;
    final value = row[key]?.toString() ?? fallback;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DropdownButtonFormField<String>(
        key: ValueKey('row-${_ids[index]}-$key-$value'),
        initialValue: options.containsKey(value) ? value : fallback,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, style: const TextStyle(fontSize: 12)),
            ),
        ],
        onChanged: (value) => _set(index, key, value, commit: true),
      ),
    );
  }

  Widget _color(int index) {
    final raw = widget.property.editor == PropertyEditor.palette
        ? _rows[index].toString()
        : (_rows[index] as Map)['color'].toString();
    void change(String value, bool commit) {
      setState(() {
        if (widget.property.editor == PropertyEditor.palette) {
          _rows[index] = value;
        } else {
          (_rows[index] as Map)['color'] = value;
        }
      });
      _emit(commit: commit);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ColorInput(
        fieldKey: ValueKey('row-${widget.property.key}-${_ids[index]}-color'),
        semanticLabel: '${widget.property.label} color ${index + 1}',
        raw: raw,
        onChanged: (raw) => change(raw, false),
        onPicked: (color) => change(colorHex(color), true),
        onCommit: () => widget.store.commitField(widget.property.key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final palette = property.editor == PropertyEditor.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _rows.length; index++)
          Container(
            key: ValueKey(_ids[index]),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (palette ? 'Color ' : 'Row ') + (index + 1).toString(),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove row',
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: palette && _rows.length <= 2
                          ? null
                          : () {
                              setState(() {
                                _rows.removeAt(index);
                                _ids.removeAt(index);
                                _numericMappings.removeAt(index);
                              });
                              _emit(commit: true);
                            },
                    ),
                  ],
                ),
                if (property.editor == PropertyEditor.rules) ...[
                  _choice(index, 'target', 'Target', const {
                    'depth': 'Child depth',
                    'parent': 'Parent key',
                  }, fallback: 'depth'),
                  _text(index, 'key', 'Depth or parent key'),
                  for (final key in [
                    'algorithm',
                    'sort',
                    'origin',
                    'axisOrder',
                    'strategy',
                    'comparator',
                  ])
                    _choice(index, key, propertiesByKey['layout.$key']!.label, {
                      'inherit': 'Inherit',
                      ...propertiesByKey['layout.$key']!.choices,
                    }),
                ] else ...[
                  if (property.editor == PropertyEditor.ranges) ...[
                    _text(index, 'minimum', 'Minimum', numeric: true),
                    _text(index, 'maximum', 'Maximum', numeric: true),
                  ],
                  if (property.editor == PropertyEditor.mappings) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _numericMappings[index] ? 'number' : 'text',
                      decoration: const InputDecoration(
                        labelText: 'Value type',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(
                          value: 'number',
                          child: Text('Number'),
                        ),
                      ],
                      onChanged: (type) {
                        final old = (_rows[index] as Map)['value'];
                        _numericMappings[index] = type == 'number';
                        _set(
                          index,
                          'value',
                          type == 'number'
                              ? num.tryParse(old.toString()) ?? 0
                              : old.toString(),
                          commit: true,
                        );
                      },
                    ),
                    _text(
                      index,
                      'value',
                      'Exact value',
                      numeric: _numericMappings[index],
                    ),
                  ],
                  _color(index),
                  if (!palette) _text(index, 'label', 'Legend label'),
                ],
              ],
            ),
          ),
        if (widget.store.errors[property.key] case final error?)
          Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        OutlinedButton.icon(
          onPressed: _rows.length >= (palette ? 32 : 64)
              ? null
              : () {
                  final editor = property.editor;
                  var nextMinimum = 0.0;
                  if (editor == PropertyEditor.ranges) {
                    for (final row in _rows) {
                      final maximum = num.tryParse(
                        (row as Map)['maximum'].toString(),
                      );
                      if (maximum != null &&
                          maximum.isFinite &&
                          maximum > nextMinimum) {
                        nextMinimum = maximum.toDouble();
                      }
                    }
                  }
                  var nextValue = 0;
                  var nextDepth = 2;
                  if (editor == PropertyEditor.mappings) {
                    while (_rows.any(
                      (row) => (row as Map)['value'] == 'value-$nextValue',
                    )) {
                      nextValue++;
                    }
                  }
                  if (editor == PropertyEditor.rules) {
                    while (_rows.any(
                      (row) =>
                          (row as Map)['target'] == 'depth' &&
                          row['key'].toString() == nextDepth.toString(),
                    )) {
                      nextDepth++;
                    }
                  }
                  setState(() {
                    _ids.add(_nextId++);
                    _numericMappings.add(false);
                    _rows.add(switch (editor) {
                      PropertyEditor.palette => 'FF2196F3',
                      PropertyEditor.ranges => {
                        'minimum': nextMinimum,
                        'maximum': nextMinimum + 20,
                        'color': 'FF2196F3',
                        'label': '',
                      },
                      PropertyEditor.mappings => {
                        'value': 'value-$nextValue',
                        'color': 'FF2196F3',
                        'label': '',
                      },
                      _ => {
                        'target': 'depth',
                        'key': nextDepth.toString(),
                        'algorithm': 'squarified',
                      },
                    });
                  });
                  _emit(commit: true);
                },
          icon: const Icon(Icons.add, size: 16),
          label: Text(palette ? 'Add color' : 'Add row'),
        ),
      ],
    );
  }
}
