import 'dart:convert';

import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact URLs, full configuration, mixed URLs and malformed recovery', () {
    final empty = PlaygroundLocationCodec.decode(Uri(path: '/'));
    expect(empty.uri.queryParameters, {'example': 'data-explicit-tree'});
    final mixed = PlaygroundLocationCodec.decode(
      Uri.parse(
        '/index.html?example=appearance-auto-visible&layout.maxVisibleDepth=2&unknown=ignored',
      ),
    );
    expect(mixed.config.text('data'), 'color-domain');
    expect(mixed.config.number('layout.maxVisibleDepth'), 2);
    expect(mixed.exampleKey, isNull);
    expect(mixed.uri.path, '/index.html');
    expect(mixed.uri.queryParameters['data'], 'color-domain');
    expect(mixed.uri.queryParameters.containsKey('unknown'), false);
    expect(mixed.uri.queryParameters.length, playgroundProperties.length);
    final malformed = PlaygroundLocationCodec.decode(
      Uri(
        queryParameters: {
          'example': 'missing',
          'data': 'categories',
          'layout.maxVisibleDepth': '0',
          'color.minimum': '10',
          'color.maximum': '5',
          'color.fallback': 'xyz',
          'color.palette': '["invalid"]',
          'preview.width': 'Infinity',
          'interaction.enabled': 'yes',
        },
      ),
    );
    expect(malformed.config.text('data'), 'categories');
    expect(malformed.config.optionalNumber('layout.maxVisibleDepth'), isNull);
    expect(malformed.config.number('color.minimum'), 10);
    expect(malformed.config.optionalNumber('color.maximum'), isNull);
    expect(malformed.notices.length, greaterThan(5));
    expect(PlaygroundLocationCodec.decode(malformed.uri).notices, isEmpty);
    final duplicate = PlaygroundLocationCodec.decode(
      Uri.parse('/?layout.innerSpacing=1&layout.innerSpacing=8'),
    );
    expect(duplicate.config.number('layout.innerSpacing'), 8);
  });
  test(
    'encoding handles colors, optional bounds, numeric extremes and nested rules',
    () {
      final config = PlaygroundConfig.fromOverrides({
        'color.minimum': -1e308,
        'color.maximum': 1e308,
        'tiles.normal.color': const Color(0x80FF0011),
        'layout.rules': [
          {
            'target': 'parent',
            'key': 'a & b/é',
            'algorithm': 'slice',
            'sort': 'sourceOrder',
          },
        ],
        'labels.fallbackTitle': 'Hello & 世界',
      });
      final uri = PlaygroundLocation(config: config).uri;
      expect(uri.queryParameters['color.maximum'], '1e+308');
      expect(uri.queryParameters['tiles.normal.color'], '80FF0011');
      expect(PlaygroundLocationCodec.decode(uri).config, config);
      expect(config.values.keys, isNot(contains('hover')));
      expect(config.values.keys, isNot(contains('snapshot')));
      expect(
        () => PlaygroundConfig.fromOverrides({
          'color.ranges': [
            {'minimum': 0, 'maximum': 20, 'color': 'FF000000'},
            {'minimum': 10, 'maximum': 30, 'color': 'FFFFFFFF'},
          ],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'drafts do not change URL, commits drop example and do not rematch presets',
    () {
      final store = PlaygroundStore();
      addTearDown(store.dispose);
      final initial = store.location.uri;
      store.draftRaw('layout.innerSpacing', '5');
      expect(store.preview.number('layout.innerSpacing'), 5);
      expect(store.location.uri, initial);
      store.commitField('layout.innerSpacing');
      expect(store.exampleKey, isNull);
      expect(store.historyIntent, HistoryIntent.push);
      expect(store.location.uri.queryParameters['data'], 'markets');
      store.change('layout.innerSpacing', 3);
      expect(store.exampleKey, isNull);
      store.selectPreset('appearance-auto-visible');
      expect(store.location.uri.queryParameters, {
        'example': 'appearance-auto-visible',
      });
      final generation = store.resetGeneration;
      store.restore(PlaygroundLocationCodec.decode(initial));
      expect(store.historyIntent, HistoryIntent.replace);
      expect(store.resetGeneration, greaterThan(generation));
    },
  );
  test('related bounds and invalid drafts are safe to edit and copy', () {
    final store = PlaygroundStore(
      initial: PlaygroundLocation(
        config: PlaygroundConfig.fromOverrides({
          'color.minimum': 0,
          'color.maximum': 10,
        }),
      ),
    );
    addTearDown(store.dispose);
    store.draftRaw('color.maximum', '20');
    store.draftRaw('color.minimum', '15');
    expect(store.preview.number('color.minimum'), 15);
    store.draftRaw('color.maximum', 'incomplete');
    expect(store.errors.keys, containsAll(['color.minimum', 'color.maximum']));
    store.draftRaw('labels.titleSize', '16');
    store.commitValidDrafts();
    expect(store.committed.number('labels.titleSize'), 16);
    expect(store.committed.number('color.minimum'), 0);
    expect(store.rawDraft('color.maximum'), 'incomplete');
    store.draftRaw('color.maximum', '20');
    store.commitField('color.minimum');
    expect(store.committed.number('color.minimum'), 15);
    expect(store.committed.number('color.maximum'), 20);
    expect(store.errors, isEmpty);
    store.draftRaw('color.palette', jsonEncode(['bad', 'FFFFFFFF']));
    store.commitValidDrafts();
    expect(store.errors, contains('color.palette'));
  });

  test('completed fields do not commit unrelated text or slider drafts', () {
    final store = PlaygroundStore();
    addTearDown(store.dispose);
    store.draftRaw('labels.titleSize', '16');
    store.draftRaw('layout.innerSpacing', '9');
    store.commitField('labels.titleSize');
    expect(store.committed.number('labels.titleSize'), 16);
    expect(store.committed.number('layout.innerSpacing'), 3);
    expect(store.preview.number('layout.innerSpacing'), 9);
    expect(store.rawDraft('layout.innerSpacing'), '9');
    store.commitField('layout.innerSpacing');
    expect(store.committed.number('layout.innerSpacing'), 9);
    expect(store.hasDrafts, false);
  });
}
