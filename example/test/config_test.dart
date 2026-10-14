import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/datasets.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every existing preset expands and round-trips every property', () {
    expect(allPresets, hasLength(52));
    expect(presetsByKey, hasLength(52));
    expect(propertiesByKey, hasLength(playgroundProperties.length));
    expect(datasetKeys, unorderedEquals(datasetsByKey.keys));
    for (final preset in allPresets) {
      expect(preset.description.trim(), isNotEmpty, reason: preset.id);
      final expanded = preset.config;
      final compact = PlaygroundLocationCodec.decode(
        Uri(queryParameters: {'example': preset.id}),
      );
      expect(compact.config, expanded, reason: preset.id);
      expect(compact.uri.queryParameters, {'example': preset.id});
      final custom = PlaygroundLocation(config: expanded);
      final restored = PlaygroundLocationCodec.decode(custom.uri);
      expect(restored.config, expanded, reason: preset.id);
      expect(restored.exampleKey, isNull);
      expect(custom.uri.queryParameters.length, playgroundProperties.length);
      if (preset.dataKey != 'invalid-weight') {
        expect(
          () => TreemapNormalizer.normalize(
            createData(expanded),
            singleChildPolicy: TreemapSingleChildPolicy.values.byName(
              expanded.text('data.singleChildPolicy'),
            ),
          ),
          returnsNormally,
          reason: preset.id,
        );
      }
    }
  });
  test('configuration collections are immutable', () {
    final config = PlaygroundConfig.defaults();
    expect(() => config.values['data'] = 'categories', throwsUnsupportedError);
    expect(
      () => config.palette('color.palette').clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (config.values['color.ranges'] as List).clear(),
      throwsUnsupportedError,
    );
  });
}
