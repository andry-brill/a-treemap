import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'opacity preset uses configurable surrounding cells and paired bars',
    (tester) async {
      final preset = presetsByKey['appearance-screenshot']!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlaygroundPreview(config: preset.config)),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<TreemapChart<String>>(
        find.byType(TreemapChart<String>),
      );
      final grid = chart.surrounding! as TreemapSurroundingGrid<String>;
      expect(grid.topStart, isNotNull);
      expect(grid.topEnd, isNotNull);
      expect(grid.columnGap, 16);
      expect(grid.middleStart, isNull);
      expect(grid.middleEnd, isNull);
      expect(find.byType(TreemapLegendView<String>), findsNWidgets(2));
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Pink'), findsOneWidget);
    },
  );
}
