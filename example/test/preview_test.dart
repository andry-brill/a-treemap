import 'dart:async';

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('isolate execution runs on demand and renders its result', (
    tester,
  ) async {
    Future<TreemapGeometrySnapshot<String>>? execution;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaygroundPreview(
            config: presetsByKey['performance-isolate-layout']!.config
                .withValues({'data.count': 120}),
            layoutRunner: (root, viewport, config) =>
                execution = TreemapLayoutEngine<String>().layoutAsync(
                  root: root,
                  viewport: viewport,
                  config: config,
                  fallbackToSynchronous: false,
                ),
          ),
        ),
      ),
    );
    expect(execution, isNull);
    final snapshot = await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('run-isolate')));
      return execution!;
    });
    await tester.pumpAndSettle();
    expect(snapshot!.nodes.length, 120);
    expect(find.text('Computed 120 geometry nodes.'), findsOneWidget);
    expect(find.byType(ComputedSnapshotView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuration edits discard results from an older execution', (
    tester,
  ) async {
    final pending = Completer<TreemapGeometrySnapshot<String>>();
    TreemapGeometrySnapshot<String>? result;
    var config = presetsByKey['performance-isolate-layout']!.config.withValues({
      'data.count': 30,
    });
    Widget preview() => MaterialApp(
      home: Scaffold(
        body: PlaygroundPreview(
          config: config,
          layoutRunner: (root, viewport, layout) {
            result = TreemapLayoutEngine<String>().layout(
              root: root,
              viewport: viewport,
              config: layout,
            );
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpWidget(preview());
    await tester.tap(find.byKey(const ValueKey('run-isolate')));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    config = config.withValues({'data.count': 40});
    await tester.pumpWidget(preview());
    pending.complete(result!);
    await tester.pumpAndSettle();
    expect(find.textContaining('Computed'), findsNothing);
    expect(find.byType(ComputedSnapshotView), findsNothing);
    expect(find.text('Run layout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final preset in allPresets) {
    testWidgets('preset ${preset.id} renders through the shared preview', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundPreview(
              config: preset.config.withValues({
                'environment.reducedMotion': true,
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (preset.dataKey == 'invalid-weight') {
        expect(find.text('Invalid data'), findsOneWidget);
      } else if (preset.id == 'performance-isolate-layout') {
        expect(find.byKey(const ValueKey('run-isolate')), findsOneWidget);
      } else {
        expect(find.byType(TreemapChart<String>), findsWidgets);
      }
    });
  }
}
