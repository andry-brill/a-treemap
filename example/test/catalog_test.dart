import 'dart:io';

import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/datasets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each preset appears exactly once in the feature matrix', () {
    final ids = File('FEATURES.md')
        .readAsLinesSync()
        .where((line) => line.startsWith('|') && line.split('|').length > 3)
        .map((line) => line.split('|')[2].trim())
        .where((cell) => cell.startsWith('`') && cell.endsWith('`'))
        .map((cell) => cell.substring(1, cell.length - 1))
        .toList();
    expect(ids, unorderedEquals(allPresets.map((preset) => preset.id)));
    expect(ids.toSet(), hasLength(ids.length));
    for (final preset in allPresets) {
      expect(preset.title.trim(), isNotEmpty);
      expect(preset.description.trim(), isNotEmpty);
      expect(preset.description.length, lessThan(250));
      expect(datasetsByKey, contains(preset.dataKey));
    }
  });
}
