import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/location.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapPresentationState<String> _state(WidgetTester tester) =>
    TreemapPresentationScope.of<String>(
      tester.element(
        find
            .descendant(
              of: find.byType(TreemapChart<String>),
              matching: find.byType(Listener),
            )
            .last,
      ),
    );

void main() {
  test('parent header controls round-trip automatic and fixed sizing', () {
    final fixed = presetsByKey['appearance-parent-header-widgets']!.config;
    expect(
      PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: fixed).uri,
      ).config,
      fixed,
    );
    final automatic = fixed.withValues({'labels.parents.height': null});
    expect(
      PlaygroundLocationCodec.decode(
        PlaygroundLocation(config: automatic).uri,
      ).config,
      automatic,
    );
    final disabled = automatic.withValues({'labels.parents.enabled': false});
    expect(
      propertiesByKey['labels.parents.height']!.enabled(disabled),
      isFalse,
    );
    expect(
      propertiesByKey['labels.parents.widgetBuilder']!.enabled(
        automatic.withValues({'labels.renderer': 'canvas'}),
      ),
      isFalse,
    );
    expect(
      () => automatic.withValues({'labels.parents.height': -1}),
      throwsFormatException,
    );
  });

  testWidgets(
    'category label contract sizes headers from visibility and typography',
    (tester) async {
      var config = presetsByKey['layout-category-card']!.config.withValues({
        'preview.showHierarchy': false,
      });
      Future<void> show() async {
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
          surfaceSize: const Size(600, 450),
        );
        await tester.pumpAndSettle();
        final chartFinder = find.byType(TreemapChart<String>);
        final chart = tester.widget<TreemapChart<String>>(chartFinder);
        expect(
          chart.labels!.resolveParentHeaderHeight(tester.element(chartFinder)),
          _state(
            tester,
          ).details[const TreemapKey.source('expenses')]!.headerBounds!.height,
        );
      }

      await show();
      for (final text in ['Expenses', 'Food', 'Other expenses', 'Groceries']) {
        expect(find.text(text), findsOneWidget);
      }
      final initial = _state(
        tester,
      ).details[const TreemapKey.source('expenses')]!.headerBounds!.height;
      config = config.withValues({'labels.parents.showValue': false});
      await show();
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('19'), findsNothing);
      expect(
        _state(
          tester,
        ).details[const TreemapKey.source('expenses')]!.headerBounds!.height,
        lessThan(initial),
      );
      config = config.withValues({
        'labels.parents.showTitle': false,
        'labels.parents.showValue': true,
      });
      await show();
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('19'), findsOneWidget);
      config = config.withValues({
        'labels.parents.showTitle': true,
        'labels.titleSize': 24,
      });
      await show();
      expect(
        _state(
          tester,
        ).details[const TreemapKey.source('expenses')]!.headerBounds!.height,
        greaterThan(initial),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'space exhaustion preserves parent and can reveal children again',
    (tester) async {
      var config = presetsByKey['layout-parent-header-space']!.config;
      Future<void> show() async {
        await tester.pumpTreemapApp(
          Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      final state = _state(tester);
      expect(
        state.targetSnapshot!.nodes.map((node) => node.key.sourceKey),
        unorderedEquals(['expenses', 'unassigned']),
      );
      expect(state.details[const TreemapKey.source('expenses')]!.weight, 19);
      config = config.withValues({'labels.parents.height': 10});
      await show();
      expect(
        _state(tester).targetSnapshot!.index,
        contains(const TreemapKey.source('groceries')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final id in [
    'layout-category-card',
    'layout-parent-headers',
    'layout-parent-header-space',
    'appearance-parent-header-widgets',
  ]) {
    testWidgets('$id visual contract', (tester) async {
      final config = presetsByKey[id]!.config.withValues({
        'preview.showHierarchy': false,
      });
      await tester.pumpTreemapApp(
        RepaintBoundary(
          key: const ValueKey('parent-header-golden'),
          child: Material(
            child: PlaygroundPreview(config: config, showToolbar: false),
          ),
        ),
        surfaceSize: const Size(600, 450),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('parent-header-golden')),
        matchesGoldenFile('goldens/$id.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
