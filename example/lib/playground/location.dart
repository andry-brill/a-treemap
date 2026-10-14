import 'config.dart';
import 'presets.dart';

final class PlaygroundLocation {
  PlaygroundLocation({
    required this.config,
    this.exampleKey,
    this.path = '/',
    Iterable<String> notices = const [],
  }) : notices = List.unmodifiable(notices);
  final PlaygroundConfig config;
  final String? exampleKey;
  final String path;
  final List<String> notices;

  Uri get uri => Uri(
    path: path.isEmpty ? '/' : path,
    queryParameters: exampleKey == null
        ? config.encodedValues
        : {'example': exampleKey!},
  );
}

/// URL interpretation is pure and independent of browser or widget lifecycle.
abstract final class PlaygroundLocationCodec {
  static PlaygroundLocation decode(Uri uri) {
    final notices = <String>[];
    final params = uri.queryParametersAll.map(
      (key, values) => MapEntry(key, values.last),
    );
    final requested = params['example'];
    final preset = presetsByKey[requested ?? defaultPresetKey];
    var base = preset?.config ?? presetsByKey[defaultPresetKey]!.config;
    if (requested != null && preset == null) {
      notices.add('Unknown example; using the default configuration.');
    }
    final overrides = <String, Object?>{};
    for (final entry in params.entries) {
      if (entry.key == 'example') continue;
      final field = propertiesByKey[entry.key];
      if (field == null) {
        notices.add('Ignored unknown property: ${entry.key}');
        continue;
      }
      try {
        overrides[entry.key] = field.parse(entry.value);
      } catch (_) {
        overrides[entry.key] = field.defaultValue;
        notices.add('${field.label}: invalid value; using the default.');
      }
    }
    for (final entry in uri.queryParametersAll.entries) {
      if (entry.value.length > 1) {
        notices.add('Repeated property: ${entry.key}. Using the last value.');
      }
    }
    final values = {...base.values, ...overrides};
    final min = values['color.minimum'] as double?;
    final max = values['color.maximum'] as double?;
    if (min != null && max != null && max <= min) {
      values['color.maximum'] = null;
      notices.add(
        'Color maximum must exceed minimum; maximum was reset to Auto.',
      );
    }
    if ((values['color.minimumSaturation'] as double) >
        (values['color.maximumSaturation'] as double)) {
      values['color.maximumSaturation'] = 1.0;
      notices.add('Maximum saturation was reset to 1.');
    }
    base = PlaygroundConfig.fromOverrides(values);
    final isCompact =
        overrides.isEmpty && (requested == null || preset != null);
    return PlaygroundLocation(
      config: base,
      path: uri.path,
      exampleKey: isCompact ? preset?.id ?? defaultPresetKey : null,
      notices: notices,
    );
  }
}
