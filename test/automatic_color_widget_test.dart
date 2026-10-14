import 'dart:ui' show PointerDeviceKind;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  children: [
    TreemapNode(
      key: 'a',
      label: 'A',
      children: [
        TreemapNode(key: 'ten', label: 'Ten', weight: 10),
        TreemapNode(key: 'thirty', label: 'Thirty', weight: 30),
      ],
    ),
    TreemapNode(
      key: 'b',
      label: 'B',
      children: [TreemapNode(key: 'sixty', label: 'Sixty', weight: 60)],
    ),
  ],
);

TreemapColorScale _scale([
  TreemapColorDomainScope scope = TreemapColorDomainScope.global,
]) => TreemapColorScale.interpolated(
  colors: const [Colors.black, Colors.white],
  fallback: Colors.pink,
  domainScope: scope,
  labelFormatter: (value) => '${value.round()}',
);

TreemapTilePainter<String> _tiles(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<TreemapTilePainter<String>>()
    .single;

Widget _chart({
  required TreemapController<String> controller,
  required TreemapColorScale scale,
  required TreemapNode<String> root,
  int? depth,
  bool animate = false,
  TreemapLegendConfig? legendConfig,
}) {
  final appearance = TreemapAppearanceResolver<String>(colorScale: scale);
  return TreemapChart<String>(
    root: root,
    controller: controller,
    layout: TreemapLayoutConfig(maxVisibleDepth: depth),
    tiles: TreemapTiles(appearance: appearance),
    labels: TreemapCanvasLabels(appearance: appearance),
    transition: animate ? TreemapTransitions.standard : null,
    surrounding: TreemapLegend(
      scale: scale,
      config: legendConfig ?? const TreemapLegendConfig.bar(),
    ),
  );
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
);

TreemapPresentationState<String> _presentation(WidgetTester tester) => tester
    .widget<TreemapPresentationScope<String>>(
      find.byType(TreemapPresentationScope<String>),
    )
    .notifier!
    .value;

void main() {
  testWidgets(
    'visible bounds track depth and zoom and stay fixed during transitions',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final root = _tree();
      final scale = _scale(TreemapColorDomainScope.visible);
      Future<void> show(int? depth) async {
        await tester.pumpWidget(
          _app(
            _chart(
              controller: controller,
              scale: scale,
              root: root,
              depth: depth,
              animate: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(1);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(
        _tiles(tester).appearances[const TreemapKey.source('a')]!.color,
        Colors.black,
      );
      await show(2);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('40'), findsNothing);
      await show(1);
      controller.zoomTo('a');
      await tester.pump();
      expect(_presentation(tester).resolveColorScale(scale).minimum, 10);
      expect(_presentation(tester).resolveColorScale(scale).maximum, 30);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_presentation(tester).resolveColorScale(scale).maximum, 30);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        _tiles(tester).appearances[const TreemapKey.source('ten')]!.color,
        Colors.black,
      );
      expect(
        _tiles(tester).appearances[const TreemapKey.source('thirty')]!.color,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global colors stay stable on zoom and update with data', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final scale = _scale();
    final root = _tree();
    await tester.pumpWidget(
      _app(_chart(controller: controller, scale: scale, root: root)),
    );
    await tester.pumpAndSettle();
    final thirty = _tiles(
      tester,
    ).appearances[const TreemapKey.source('thirty')]!.color;
    controller.zoomTo('a');
    await tester.pumpAndSettle();
    expect(
      _tiles(tester).appearances[const TreemapKey.source('thirty')]!.color,
      thirty,
    );
    expect(find.text('60'), findsOneWidget);
    final updated = root.copyWith(
      children: [
        root.children.first,
        TreemapNode(
          key: 'b',
          children: [TreemapNode(key: 'sixty', weight: 120)],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(_chart(controller: controller, scale: scale, root: updated)),
    );
    await tester.pumpAndSettle();
    expect(_presentation(tester).resolveColorScale(scale).maximum, 120);
    expect(find.text('120'), findsOneWidget);
    expect(
      _tiles(tester).appearances[const TreemapKey.source('thirty')]!.color,
      isNot(thirty),
    );
  });

  testWidgets(
    'color-only updates refresh tiles, label contrast and hovered legend input',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final scale = _scale();
      TreemapNode<String> root(double middle) => TreemapNode(
        key: 'root',
        children: [
          TreemapNode(key: 'x', weight: 1, color: 10),
          TreemapNode(key: 'y', weight: 1, color: middle),
          TreemapNode(key: 'z', weight: 1, color: 60),
        ],
      );
      double? pointer;
      Color? pointerColor;
      final legend = TreemapLegendConfig.bar(
        pointerBuilder: (_, color, fraction) {
          pointer = fraction;
          pointerColor = color;
          return const SizedBox(width: 8, height: 8);
        },
      );
      await tester.pumpWidget(
        _app(
          _chart(
            controller: controller,
            scale: scale,
            root: root(30),
            legendConfig: legend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = _tiles(tester);
      final node = before.snapshot.index[const TreemapKey.source('y')]!;
      final paint = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is TreemapTilePainter<String>,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getTopLeft(paint) +
            Offset(node.bounds.centerX, node.bounds.centerY),
      );
      await tester.pumpAndSettle();
      expect(pointer, .4);
      await tester.pumpWidget(
        _app(
          _chart(
            controller: controller,
            scale: scale,
            root: root(50),
            legendConfig: legend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final after = _tiles(tester);
      expect(
        after.snapshot.index[const TreemapKey.source('y')]!.bounds,
        node.bounds,
      );
      final expected = Color.lerp(Colors.black, Colors.white, .8);
      expect(after.appearances[const TreemapKey.source('y')]!.color, expected);
      final labels = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<TreemapCanvasLabelPainter<String>>()
          .single;
      expect(labels.appearances[const TreemapKey.source('y')]!.color, expected);
      expect(controller.hoveredColor, 50);
      expect(pointer, .8);
      expect(pointerColor, expected);
    },
  );

  testWidgets(
    'weight fallback drives hover pointer and nonnumeric inputs hide it',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final scale = _scale();
      final root = TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(key: 'low', weight: 10),
          TreemapNode(key: 'high', weight: 30),
          TreemapNode(key: 'direct', weight: 20, color: Colors.blue),
          TreemapNode(key: 'category', weight: 20, color: 'x'),
          TreemapNode(key: 'nan', weight: 20, color: double.nan),
        ],
      );
      final legend = TreemapLegendConfig.bar(
        pointerBuilder: (_, color, fraction) =>
            Text('pointer $fraction', key: const ValueKey('pointer')),
      );
      await tester.pumpWidget(
        _app(
          _chart(
            controller: controller,
            scale: scale,
            root: root,
            legendConfig: legend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final paint = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is TreemapTilePainter<String>,
      );
      for (final key in ['low', 'direct', 'category', 'nan']) {
        final node = _tiles(tester).snapshot.index[TreemapKey.source(key)]!;
        await mouse.moveTo(
          tester.getTopLeft(paint) +
              Offset(node.bounds.centerX, node.bounds.centerY),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pointer')),
          key == 'low' ? findsOneWidget : findsNothing,
        );
      }
      expect(
        _tiles(tester).appearances[const TreemapKey.source('direct')]!.color,
        Colors.blue,
      );
      expect(
        _tiles(tester).appearances[const TreemapKey.source('category')]!.color,
        Colors.pink,
      );
    },
  );

  testWidgets(
    'standalone legends accept presentation data and constant segmented domains',
    (tester) async {
      final scale = _scale();
      await tester.pumpWidget(
        _app(
          TreemapLegendView(
            scale: scale,
            presentation: TreemapPresentationState.fromData(root: _tree()),
            config: const TreemapLegendConfig.bar(segmented: true),
          ),
        ),
      );
      expect(find.text('10'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          TreemapLegendView(
            scale: scale,
            presentation: TreemapPresentationState.fromData(
              root: TreemapNode(
                key: 'root',
                children: [TreemapNode(key: 'x', weight: 7)],
              ),
            ),
            config: const TreemapLegendConfig.bar(segmented: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('10'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _app(
          TreemapLegendView(
            scale: scale.resolveDomain([2, 8]),
            config: const TreemapLegendConfig.bar(),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    },
  );

  testWidgets('equivalent trees rebuilt by controller listeners settle', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final scale = _scale(TreemapColorDomainScope.visible);
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => _chart(
            controller: controller,
            scale: scale,
            root: _tree(),
            depth: 1,
          ),
        ),
      ),
    );
    expect(await tester.pumpAndSettle(), lessThan(10));
    controller.zoomTo('a');
    expect(await tester.pumpAndSettle(), lessThan(10));
    expect(_presentation(tester).resolveColorScale(scale).maximum, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible domains clear when the viewport becomes empty', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    addTearDown(controller.dispose);
    final scale = _scale(TreemapColorDomainScope.visible);
    final root = _tree();
    Widget app(double height) => MaterialApp(
      home: Align(
        child: SizedBox(
          width: 600,
          height: height,
          child: TreemapChart<String>(
            root: root,
            controller: controller,
            tiles: TreemapTiles(
              appearance: TreemapAppearanceResolver(colorScale: scale),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(400));
    await tester.pumpAndSettle();
    expect(_presentation(tester).resolveColorScale(scale).maximum, 60);
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(_presentation(tester).resolveColorScale(scale).minimum, isNull);
    expect(tester.takeException(), isNull);
  });
}
