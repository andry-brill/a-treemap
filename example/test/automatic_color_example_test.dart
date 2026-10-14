import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:any_treemap_example/scenarios/appearance.dart';

void main() {
  for (final scenario in appearanceScenarios.where(
    (scenario) =>
        scenario.id.startsWith('appearance-auto-') ||
        scenario.id == 'appearance-presentation-state',
  )) {
    testWidgets('${scenario.id} renders and updates its documented domain', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: scenario.builder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TreemapColorScale resolved() {
        final view = tester.widget<TreemapLegendView<String>>(
          find.byType(TreemapLegendView<String>),
        );
        final state =
            view.presentation ??
            TreemapPresentationScope.maybeOf<String>(
              tester.element(find.byType(TreemapLegendView<String>)),
            );
        return state?.resolveColorScale(view.scale) ?? view.scale;
      }

      if (scenario.id == 'appearance-auto-standalone') {
        expect(resolved().minimum, 15);
        expect(resolved().maximum, 55);
      } else {
        final visible =
            scenario.id == 'appearance-auto-visible' ||
            scenario.id == 'appearance-presentation-state';
        final mixed = scenario.id == 'appearance-auto-mixed-bounds';
        expect(
          resolved().minimum,
          visible
              ? 40
              : mixed
              ? 0
              : 10,
        );
        expect(resolved().maximum, 60);
        await tester.tap(find.text('Depth 2'));
        await tester.pumpAndSettle();
        expect(resolved().minimum, mixed ? 0 : 10);
        await tester.tap(find.text('Update data'));
        await tester.pumpAndSettle();
        expect(resolved().maximum, 100);
        if (mixed) {
          await tester.tap(find.text('Use fixed maximum 100'));
          await tester.pumpAndSettle();
          expect(resolved().minimum, 10);
          expect(resolved().maximum, 100);
        }
        await tester.tap(find.text('Restore data'));
        await tester.pumpAndSettle();
        expect(resolved().maximum, mixed ? 100 : 60);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
