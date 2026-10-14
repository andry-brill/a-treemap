import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'properties.dart';

enum PropertyEditor {
  toggle,
  choice,
  number,
  text,
  color,
  palette,
  ranges,
  mappings,
  rules,
}

/// One definition drives the form, validation and query-string codec.
@immutable
final class PlaygroundProperty<T> {
  const PlaygroundProperty({
    required this.key,
    required this.label,
    required this.group,
    required this.help,
    required this.editor,
    required this.defaultValue,
    required this.decode,
    required this.encode,
    this.choices = const {},
    this.minimum,
    this.maximum,
    this.nullLabel,
    this.available,
    this.unavailableReason,
  });

  final String key;
  final String label;
  final String group;
  final String help;
  final PropertyEditor editor;
  final T defaultValue;
  final T Function(String) decode;
  final String Function(T) encode;
  final Map<String, String> choices;
  final double? minimum;
  final double? maximum;
  final String? nullLabel;
  final bool Function(PlaygroundConfig)? available;
  final String? unavailableReason;

  String encodeValue(Object? value) => encode(value as T);
  Object? parse(String value) => decode(value);
  bool enabled(PlaygroundConfig config) => disabledReason(config) == null;
  String? disabledReason(PlaygroundConfig config) =>
      available?.call(config) == false
      ? unavailableReason ?? 'Not used by this configuration.'
      : propertyDisabledReason(key, config);
}

/// Typed access is confined to a validated, deeply immutable configuration.
/// Keys are property descriptors, never caller-supplied library object members.
@immutable
final class PlaygroundConfig {
  PlaygroundConfig._(Map<String, Object?> values)
    : _values = UnmodifiableMapView({
        for (final entry in values.entries) entry.key: _freeze(entry.value),
      });

  factory PlaygroundConfig.defaults() => _defaults;

  static final _defaults = PlaygroundConfig._({
    for (final property in playgroundProperties)
      property.key: property.parse(property.encodeValue(property.defaultValue)),
  });

  factory PlaygroundConfig.fromOverrides(Map<String, Object?> overrides) {
    final values = Map<String, Object?>.of(PlaygroundConfig.defaults()._values);
    for (final entry in overrides.entries) {
      final property = propertiesByKey[entry.key];
      if (property == null) {
        throw FormatException('Unknown property: ${entry.key}');
      }
      // Round-trip also validates programmatically authored presets.
      final value =
          property.editor == PropertyEditor.number && entry.value is num
          ? (entry.value as num).toDouble()
          : entry.value;
      values[entry.key] = property.parse(property.encodeValue(value));
    }
    final result = PlaygroundConfig._(values);
    result.validate();
    return result;
  }

  final Map<String, Object?> _values;
  Map<String, Object?> get values => _values;
  T read<T>(PlaygroundProperty<T> property) => _values[property.key] as T;
  bool flag(String key) => _values[key] as bool;
  String text(String key) => _values[key] as String;
  double number(String key) => (_values[key] as num).toDouble();
  double? optionalNumber(String key) => (_values[key] as num?)?.toDouble();
  int integer(String key) => (_values[key] as num).toInt();
  Color color(String key) => _values[key] as Color;
  Color? optionalColor(String key) => _values[key] as Color?;
  List<Color> palette(String key) => (_values[key] as List).cast<Color>();
  List<Map<String, Object?>> rows(String key) => (_values[key] as List)
      .map((row) => (row as Map).cast<String, Object?>())
      .toList(growable: false);

  PlaygroundConfig withValues(Map<String, Object?> changes) =>
      PlaygroundConfig.fromOverrides({..._values, ...changes});

  void validate() {
    final minimum = optionalNumber('color.minimum');
    final maximum = optionalNumber('color.maximum');
    if (minimum != null && maximum != null && maximum <= minimum) {
      throw const FormatException(
        'Color maximum must be greater than minimum.',
      );
    }
    if (number('color.minimumSaturation') > number('color.maximumSaturation')) {
      throw const FormatException(
        'Maximum saturation must be at least minimum saturation.',
      );
    }
  }

  /// Data identity excludes cosmetic properties and temporary interaction.
  String get dataSignature => jsonEncode({
    for (final key in [
      'data',
      'data.construction',
      'data.count',
      'data.grouping',
      'data.singleChildPolicy',
      'data.revision',
      'color.input',
    ])
      key: propertiesByKey[key]!.encodeValue(_values[key]),
  });

  @override
  bool operator ==(Object other) =>
      other is PlaygroundConfig &&
      mapEquals(encodedValues, other.encodedValues);
  @override
  int get hashCode => Object.hashAll(
    encodedValues.entries.map((e) => Object.hash(e.key, e.value)),
  );
  Map<String, String> get encodedValues => {
    for (final property in playgroundProperties)
      property.key: property.encodeValue(_values[property.key]),
  };
}

Object? _freeze(Object? value) => switch (value) {
  List<Color> colors => List<Color>.unmodifiable(colors),
  List<Map<String, Object?>> rows => List<Map<String, Object?>>.unmodifiable(
    rows.map(
      (row) => Map<String, Object?>.unmodifiable(
        row.map((key, value) => MapEntry(key, _freeze(value))),
      ),
    ),
  ),
  List list => List<Object?>.unmodifiable(list.map(_freeze)),
  Map map => Map<String, Object?>.unmodifiable(
    map.map((key, value) => MapEntry(key as String, _freeze(value))),
  ),
  _ => value,
};

PlaygroundProperty<bool> toggle(
  String key,
  String label,
  String group,
  String help,
  bool value, {
  bool Function(PlaygroundConfig)? available,
  String? reason,
}) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.toggle,
  defaultValue: value,
  encode: (value) => value.toString(),
  decode: (raw) => switch (raw) {
    'true' => true,
    'false' => false,
    _ => throw const FormatException('Use true or false.'),
  },
  available: available,
  unavailableReason: reason,
);

PlaygroundProperty<String> choice(
  String key,
  String label,
  String group,
  String help,
  String value,
  List<String> options, {
  Map<String, String> labels = const {},
  bool Function(PlaygroundConfig)? available,
  String? reason,
}) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.choice,
  defaultValue: value,
  choices: {
    for (final option in options) option: labels[option] ?? _humanize(option),
  },
  encode: (value) => value,
  decode: (raw) => options.contains(raw)
      ? raw
      : throw FormatException('Choose one of: ${options.join(', ')}'),
  available: available,
  unavailableReason: reason,
);

PlaygroundProperty<double?> numeric(
  String key,
  String label,
  String group,
  String help,
  double? value, {
  double? min = 0,
  double? max,
  bool integer = false,
  String? nullLabel,
  bool Function(PlaygroundConfig)? available,
  String? reason,
}) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.number,
  defaultValue: value,
  minimum: min,
  maximum: max,
  nullLabel: nullLabel,
  encode: (value) => value == null
      ? (nullLabel == 'Auto' ? 'auto' : 'none')
      : integer
      ? value.toInt().toString()
      : value.toString().replaceFirst(RegExp(r'\.0$'), ''),
  decode: (raw) {
    if ((raw == 'none' || raw == 'auto') && nullLabel != null) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null ||
        !parsed.isFinite ||
        (min != null && parsed < min) ||
        (max != null && parsed > max) ||
        (integer && parsed != parsed.roundToDouble())) {
      throw FormatException(
        'Enter a ${integer ? 'whole ' : ''}number${min == null ? '' : ' ≥ $min'}${max == null ? '' : ' and ≤ $max'}.',
      );
    }
    return parsed;
  },
  available: available,
  unavailableReason: reason,
);

PlaygroundProperty<String> stringField(
  String key,
  String label,
  String group,
  String help,
  String value, {
  bool nonempty = false,
}) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.text,
  defaultValue: value,
  encode: (value) => value,
  decode: (raw) => nonempty && raw.isEmpty
      ? throw const FormatException('Cannot be empty.')
      : raw,
);

String colorHex(Color value) =>
    value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
Color parseColor(String raw) {
  final text = raw.replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(text)) {
    throw const FormatException('Use RRGGBB or AARRGGBB hex.');
  }
  return Color(int.parse(text.length == 6 ? 'FF$text' : text, radix: 16));
}

PlaygroundProperty<Color?> colorField(
  String key,
  String label,
  String group,
  String help,
  Color? value, {
  bool optional = false,
}) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.color,
  defaultValue: value,
  nullLabel: optional ? 'Inherit' : null,
  encode: (value) => value == null ? 'none' : colorHex(value),
  decode: (raw) => raw == 'none' && optional ? null : parseColor(raw),
);

PlaygroundProperty<List<Color>> paletteField(
  String key,
  String label,
  String group,
  String help,
  List<Color> value,
) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: PropertyEditor.palette,
  defaultValue: List.unmodifiable(value),
  encode: (value) => jsonEncode(value.map(colorHex).toList()),
  decode: (raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.length < 2 || decoded.length > 32) {
      throw const FormatException('Use between 2 and 32 colors.');
    }
    return List.unmodifiable(
      decoded.map((value) => parseColor(value as String)),
    );
  },
);

PlaygroundProperty<List<Map<String, Object?>>> rowField(
  String key,
  String label,
  String group,
  String help,
  PropertyEditor editor,
  List<Map<String, Object?>> defaults,
) => PlaygroundProperty(
  key: key,
  label: label,
  group: group,
  help: help,
  editor: editor,
  defaultValue: defaults,
  encode: jsonEncode,
  decode: (raw) {
    final result = jsonDecode(raw);
    if (result is! List || result.length > 64) {
      throw const FormatException('Use at most 64 rows.');
    }
    final rows = result
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Every row must be an object.');
          }
          final map = Map<String, Object?>.from(row);
          if (editor == PropertyEditor.rules) {
            if (map['target'] != 'depth' && map['target'] != 'parent') {
              throw const FormatException('Choose depth or parent.');
            }
            if (map['target'] == 'depth' &&
                (int.tryParse(map['key'].toString()) ?? 0) < 1) {
              throw const FormatException('Depth must be positive.');
            }
            if (map['key'] is! String ||
                (map['key'] as String).trim().isEmpty) {
              throw const FormatException('A rule needs a target key.');
            }
            for (final field in [
              'algorithm',
              'sort',
              'origin',
              'axisOrder',
              'strategy',
              'comparator',
            ]) {
              if (map[field] != null && map[field] != 'inherit') {
                final descriptor = propertiesByKey['layout.$field']!;
                descriptor.parse(map[field] as String);
              }
            }
          } else {
            map['color'] = colorHex(parseColor(map['color'] as String));
            if (map['label'] != null && map['label'] is! String) {
              throw const FormatException('Legend labels must be text.');
            }
            if (editor == PropertyEditor.ranges) {
              final min = (map['minimum'] as num).toDouble();
              final max = (map['maximum'] as num).toDouble();
              if (!min.isFinite || !max.isFinite || max <= min) {
                throw const FormatException(
                  'Range maximum must exceed minimum.',
                );
              }
            } else if (map['valueType'] == 'number' && map['value'] is! num) {
              throw const FormatException(
                'Enter a finite numeric mapping value.',
              );
            } else if (map['value'] is! String && map['value'] is! num ||
                map['value'] is num && !(map['value'] as num).isFinite) {
              throw const FormatException(
                'A mapping needs a text or finite numeric value.',
              );
            } else if (map['value'] is num) {
              map['value'] = (map['value'] as num).toDouble();
            }
            map.remove('valueType');
          }
          return Map<String, Object?>.unmodifiable(map);
        })
        .toList(growable: false);
    if (editor == PropertyEditor.rules) {
      final targets = rows.map((row) => '${row['target']}:${row['key']}');
      if (targets.toSet().length != rows.length) {
        throw const FormatException('Rule targets must be unique.');
      }
    }
    if (editor == PropertyEditor.ranges) {
      final ordered = [...rows]
        ..sort((a, b) => (a['minimum'] as num).compareTo(b['minimum'] as num));
      for (var index = 1; index < ordered.length; index++) {
        if ((ordered[index - 1]['maximum'] as num) >
            (ordered[index]['minimum'] as num)) {
          throw const FormatException('Numeric ranges must not overlap.');
        }
      }
    }
    if (editor == PropertyEditor.mappings) {
      final keys = rows.map(
        (row) =>
            jsonEncode([row['value'] is num ? 'number' : 'text', row['value']]),
      );
      if (keys.toSet().length != rows.length) {
        throw const FormatException('Exact mapping keys must be unique.');
      }
    }
    return List.unmodifiable(rows);
  },
);

String _humanize(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]!} ${match[2]!}',
    )
    .replaceAll('-', ' ');

// Filled by the public-property inventory below. All fields, including inactive
// ones, participate in URL round-tripping and preset validation.
final List<PlaygroundProperty> playgroundProperties = buildProperties();
final Map<String, PlaygroundProperty> propertiesByKey = {
  for (final property in playgroundProperties) property.key: property,
};

List<PlaygroundProperty> buildProperties() => propertyDefinitions();

// Definitions are part of this library so typed descriptors cannot diverge
// from the configuration accessors or collection validation.
