import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

TreemapNode<String> _tree() => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [TreemapNode(key: 'leaf', label: 'Leaf', weight: 1, color: 1)],
    ),
  ],
);

TreemapSurroundingContent<String> _box(
  String key, {
  double width = 20,
  double height = 10,
}) => TreemapSurroundingContent<String>.widget(
  child: SizedBox(key: ValueKey(key), width: width, height: height),
);

Widget _frame({
  required double width,
  required double height,
  required Widget child,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, height: height, child: child),
);

void main() {
  test('gaps require finite nonnegative values', () {
    expect(
      () => TreemapSurroundingGrid<String>(rowGap: -1),
      throwsAssertionError,
    );
    expect(
      () => TreemapSurroundingGrid<String>(columnGap: double.infinity),
      throwsAssertionError,
    );
  });

  testWidgets('places all eight slots with natural outer-row heights', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: TreemapSurroundingGrid<String>.fromMap(
            {
              TreemapOverlayPosition.topStart: _box('top-start', height: 20),
              TreemapOverlayPosition.topCenter: _box('top-center', height: 30),
              TreemapOverlayPosition.topEnd: _box('top-end'),
              TreemapOverlayPosition.middleStart: _box(
                'middle-start',
                width: 40,
              ),
              TreemapOverlayPosition.middleEnd: _box('middle-end', width: 50),
              TreemapOverlayPosition.bottomStart: _box('bottom-start'),
              TreemapOverlayPosition.bottomCenter: _box(
                'bottom-center',
                height: 20,
              ),
              TreemapOverlayPosition.bottomEnd: _box('bottom-end', height: 25),
            },
            padding: const EdgeInsets.all(10),
            rowGap: 4,
            columnGap: 5,
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(TreemapChart<String>));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-start'))),
      origin + const Offset(10, 10),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-center'))),
      origin + const Offset(140, 10),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-end'))),
      origin + const Offset(270, 10),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('middle-start'))),
      origin + const Offset(10, 97.5),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('middle-end'))),
      origin + const Offset(240, 97.5),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('bottom-start'))),
      origin + const Offset(10, 180),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('bottom-center'))),
      origin + const Offset(140, 170),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('bottom-end'))),
      origin + const Offset(270, 165),
    );
    expect(snapshot!.viewport.width, 180);
    expect(snapshot!.viewport.height, 117);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caller-sized content determines its outer-row height', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: TreemapSurroundingGrid<String>(
            topStart: const TreemapSurroundingContent<String>.widget(
              child: SizedBox(height: 56, child: Text('Header')),
            ),
            topEnd: _box('short-header', height: 20),
            rowGap: 8,
          ),
        ),
      ),
    );

    expect(snapshot!.viewport.width, 300);
    expect(snapshot!.viewport.height, 136);
  });

  testWidgets('lone top and bottom center cells span the full row width', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: const TreemapSurroundingGrid<String>(
            topCenter: TreemapSurroundingContent<String>.widget(
              child: SizedBox(
                key: ValueKey('full-top-center'),
                width: double.infinity,
                height: 20,
              ),
            ),
            bottomCenter: TreemapSurroundingContent<String>.widget(
              child: SizedBox(
                key: ValueKey('full-bottom-center'),
                width: double.infinity,
                height: 10,
              ),
            ),
            rowGap: 5,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('full-top-center'))).width,
      300,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('full-bottom-center'))).width,
      300,
    );
    expect(snapshot!.viewport.height, 160);
  });

  testWidgets('empty bands collapse and the treemap spans absent sides', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: const TreemapSurroundingGrid<String>(
            padding: EdgeInsets.all(10),
            rowGap: 20,
            columnGap: 20,
          ),
        ),
      ),
    );
    expect(snapshot!.viewport.width, 280);
    expect(snapshot!.viewport.height, 180);

    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 200,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: TreemapSurroundingGrid<String>(
            middleStart: _box('only-side', width: 40),
            padding: const EdgeInsets.all(10),
            columnGap: 5,
          ),
        ),
      ),
    );
    expect(snapshot!.viewport.width, 235);
    expect(snapshot!.viewport.height, 180);
  });

  testWidgets('start and end slots resolve through text direction', (
    tester,
  ) async {
    TreemapGeometrySnapshot<String>? snapshot;
    await tester.pumpTreemapApp(
      _frame(
        width: 300,
        height: 100,
        child: TreemapChart<String>(
          root: _tree(),
          tiles: testTreemapTiles(),
          onSnapshot: (value) => snapshot = value,
          surrounding: TreemapSurroundingGrid<String>(
            topStart: _box('start'),
            topEnd: _box('end'),
            middleStart: _box('middle-start-rtl', width: 40),
            middleEnd: _box('middle-end-rtl', width: 50),
          ),
        ),
      ),
      textDirection: TextDirection.rtl,
    );

    final origin = tester.getTopLeft(find.byType(TreemapChart<String>));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('start'))),
      origin + const Offset(280, 0),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('end'))), origin);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('middle-start-rtl'))).dx,
      origin.dx + 260,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('middle-end-rtl'))).dx,
      origin.dx,
    );
    expect(snapshot!.viewport.width, 210);
  });

  testWidgets('built-ins and content factories receive the active controller', (
    tester,
  ) async {
    final controller = TreemapController<String>();
    controller
      ..synchronize(_tree())
      ..zoomTo('group')
      ..setHovered(const TreemapKey.source('leaf'), color: 1);
    addTearDown(controller.dispose);
    final scale = TreemapColorScale.interpolated(
      minimum: 0,
      maximum: 2,
      colors: const [Colors.blue, Colors.red],
      fallback: Colors.grey,
    );

    await tester.pumpTreemapApp(
      _frame(
        width: 600,
        height: 300,
        child: TreemapChart<String>(
          root: _tree(),
          controller: controller,
          tiles: testTreemapTiles(colorScale: scale),
          surrounding: TreemapSurroundingGrid<String>(
            topStart: const TreemapBreadcrumbs<String>(),
            topEnd: TreemapLegend<String>(
              scale: scale,
              config: const TreemapLegendConfig.bar(showLabels: false),
            ),
            bottomStart: const TreemapSurroundingContent<String>.widget(
              child: Text('Static', key: ValueKey('static-content')),
            ),
            bottomEnd: TreemapSurroundingContent<String>.builder(
              builder: (context, activeController) => Text(
                '${activeController.currentPath.length}',
                key: const ValueKey('builder-content'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TreemapBreadcrumbsView<String>), findsOneWidget);
    expect(find.byType(TreemapLegendView<String>), findsOneWidget);
    expect(find.byType(TreemapLegendPointer), findsOneWidget);
    expect(find.byKey(const ValueKey('static-content')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Root'));
    await tester.pump();
    expect(controller.focusKey, const TreemapKey.source('root'));
  });

  testWidgets('clip behavior uses standard ClipRect composition', (
    tester,
  ) async {
    Widget chart(Clip clipBehavior) => _frame(
      width: 300,
      height: 200,
      child: TreemapChart<String>(
        root: _tree(),
        tiles: testTreemapTiles(),
        surrounding: TreemapSurroundingGrid<String>(
          topStart: _box('clipped-content'),
          clipBehavior: clipBehavior,
        ),
      ),
    );

    await tester.pumpTreemapApp(chart(Clip.none));
    final unclippedCount = find.byType(ClipRect).evaluate().length;

    await tester.pumpTreemapApp(chart(Clip.hardEdge));
    expect(find.byType(ClipRect), findsNWidgets(unclippedCount + 1));
  });
}
