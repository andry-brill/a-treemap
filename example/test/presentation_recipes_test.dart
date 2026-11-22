import 'dart:ui' show Tristate;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap_example/playground/presets.dart';
import 'package:any_treemap_example/playground/preview.dart';
import 'package:any_treemap_example/recipes/cupertino.dart';
import 'package:any_treemap_example/recipes/custom.dart';
import 'package:any_treemap_example/recipes/material.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

enum _Design { material, cupertino, custom }

Widget _item(
  _Design design,
  String label,
  bool current,
  VoidCallback? action,
) => switch (design) {
  _Design.material => MaterialTreemapBreadcrumbItem(
    label: label,
    isCurrent: current,
    onPressed: action,
  ),
  _Design.cupertino => CupertinoTreemapBreadcrumbItem(
    label: label,
    isCurrent: current,
    onPressed: action,
  ),
  _Design.custom => CustomTreemapBreadcrumbItem(
    label: label,
    isCurrent: current,
    onPressed: action,
  ),
};

Widget _host(
  _Design design,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  final content = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(textDirection: direction, child: child),
    ),
  );
  return switch (design) {
    _Design.material => material.MaterialApp(
      theme: material.ThemeData(brightness: brightness),
      home: material.Material(child: content),
    ),
    _Design.cupertino => cupertino.CupertinoApp(
      theme: cupertino.CupertinoThemeData(brightness: brightness),
      home: cupertino.CupertinoPageScaffold(child: content),
    ),
    _Design.custom => WidgetsApp(
      color: const Color(0xFFFFFFFF),
      builder: (context, child) => DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          color: brightness == Brightness.dark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF202020),
        ),
        child: FocusScope(autofocus: true, child: content),
      ),
    ),
  };
}

TreemapLegendTitleBuilder _title(_Design design) => switch (design) {
  _Design.material => materialTreemapLegendTitle,
  _Design.cupertino => cupertinoTreemapLegendTitle,
  _Design.custom => customTreemapLegendTitle,
};
TreemapLegendLabelBuilder _label(_Design design) => switch (design) {
  _Design.material => materialTreemapLegendLabel,
  _Design.cupertino => cupertinoTreemapLegendLabel,
  _Design.custom => customTreemapLegendLabel,
};
TreemapLegendPointerBuilder _pointer(_Design design) => switch (design) {
  _Design.material => materialTreemapLegendPointer,
  _Design.cupertino => cupertinoTreemapLegendPointer,
  _Design.custom => customTreemapLegendPointer,
};
TreemapTooltipContainerBuilder _tooltip(_Design design) => switch (design) {
  _Design.material => materialTreemapTooltip,
  _Design.cupertino => cupertinoTreemapTooltip,
  _Design.custom => customTreemapTooltip,
};

void main() {
  for (final design in _Design.values) {
    testWidgets('${design.name} pointer, keyboard and accessible breadcrumbs', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var activations = 0;
        await tester.pumpWidget(
          _host(
            design,
            Column(
              children: [
                _item(design, 'Ancestor', false, () => activations++),
                _item(design, 'Current', true, () => activations++),
                _item(design, 'Disabled', false, null),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Ancestor'), findsOneWidget);
        expect(find.bySemanticsLabel('Current'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.text('Current'))
              .getSemanticsData().flagsCollection.isSelected,
          Tristate.isTrue,
        );
        for (final label in ['Current', 'Disabled']) {
          expect(
            tester
                .getSemantics(find.text(label))
                .getSemanticsData().flagsCollection.isEnabled,
            Tristate.isFalse,
          );
        }
        await tester.tap(find.text('Ancestor'));
        await tester.pumpAndSettle();
        expect(activations, 1);
        await tester.tap(find.text('Current'));
        await tester.tap(find.text('Disabled'));
        await tester.pumpAndSettle();
        expect(activations, 1);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(activations, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(activations, 3);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      '${design.name} updates theme and supports RTL, text scaling and reduced motion',
      (tester) async {
        Widget content() => Builder(
          builder: (context) => Column(
            children: [
              _item(design, 'Current', true, null),
              _title(design)(context, 'Scale'),
              _label(design)(
                context,
                const TreemapLegendEntry(
                  label: 'Value',
                  color: Color(0xFF123456),
                ),
              ),
              _pointer(design)(context, const Color(0xFF123456), .5),
              _tooltip(design)(context, const Text('Details')),
            ],
          ),
        );
        await tester.pumpWidget(_host(design, content()));
        await tester.pumpAndSettle();
        final light = tester
            .widget<TreemapLegendPointer>(find.byType(TreemapLegendPointer))
            .color;
        await tester.pumpWidget(
          _host(
            design,
            content(),
            brightness: Brightness.dark,
            reducedMotion: true,
            direction: TextDirection.rtl,
            textScale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        final dark = tester
            .widget<TreemapLegendPointer>(find.byType(TreemapLegendPointer))
            .color;
        expect(dark, isNot(light));
        expect(
          Directionality.of(tester.element(find.text('Scale'))),
          TextDirection.rtl,
        );
        expect(
          MediaQuery.textScalerOf(tester.element(find.text('Value'))).scale(10),
          18,
        );
        for (final indicator in tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        )) {
          expect(indicator.duration, Duration.zero);
        }
        final details = tester.element(find.text('Details'));
        expect(DefaultTextStyle.of(details).style.color, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${design.name} catalog recipe navigates and switches legend kinds',
      (tester) async {
        final preset = presetsByKey['appearance-${design.name}-recipe']!;
        for (final kind in ['bar', 'discrete']) {
          await tester.pumpWidget(
            material.MaterialApp(
              home: material.Material(
                child: PlaygroundPreview(
                  key: ValueKey(kind),
                  config: preset.config.withValues({'legend.kind': kind}),
                  showToolbar: false,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final chart = tester.widget<TreemapChart<String>>(
            find.byType(TreemapChart<String>),
          );
          final branch = chart.tree.root.children.firstWhere(
            (node) => node.children.isNotEmpty,
          );
          chart.controller!.zoomTo(branch.key);
          await tester.pumpAndSettle();
          expect(chart.controller!.focusKey, TreemapKey.source(branch.key));
          await tester.tap(
            find.text(chart.tree.root.label ?? chart.tree.root.key),
          );
          await tester.pumpAndSettle();
          expect(
            chart.controller!.focusKey,
            TreemapKey.source(chart.tree.root.key),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    for (final brightness in Brightness.values) {
      testWidgets('${design.name} ${brightness.name} recipe visual contract', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(600, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _host(
            design,
            RepaintBoundary(
              key: const ValueKey('recipe-golden'),
              child: ColoredBox(
                color: brightness == Brightness.light
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF202020),
                child: Builder(
                  builder: (context) => Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _item(design, 'Root', false, () {}),
                          const TreemapBreadcrumbSeparator(),
                          _item(design, 'Current', true, null),
                        ],
                      ),
                      _title(design)(context, 'Weight'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TreemapLegendItem(
                            color: const Color(0xFF4466AA),
                            label: _label(design)(
                              context,
                              const TreemapLegendEntry(
                                label: 'A',
                                color: Color(0xFF4466AA),
                              ),
                            ),
                          ),
                          _pointer(design)(
                            context,
                            const Color(0xFF4466AA),
                            .5,
                          ),
                          SizedBox(
                            width: 160,
                            height: 16,
                            child: TreemapLegendBar(
                              direction: Axis.horizontal,
                              colors: const [
                                Color(0xFF4466AA),
                                Color(0xFFAACCEE),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _tooltip(design)(context, const Text('Details')),
                    ],
                  ),
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('recipe-golden')),
          matchesGoldenFile(
            'goldens/recipe-${design.name}-${brightness.name}.png',
          ),
        );
      });
    }
  }
}
