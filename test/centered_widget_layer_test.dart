import 'dart:ui' show PointerDeviceKind;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/tile_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

final _singleTree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [TreemapNode(key: 'leaf', label: 'Leaf', weight: 1)],
  ),
);

Widget _content(
  BuildContext context,
  TreemapNodeDetails<String> details,
  Set<TreemapVisualState> states,
) => ColoredBox(key: ValueKey('content-${details.key}'), color: Colors.white);

Finder _contentFor(TreemapKey<String> key) =>
    find.byKey(ValueKey('content-$key'));
final _leafContent = _contentFor(const TreemapKey.source('leaf'));

final class _CaptureLayer implements TreemapTileLayer<String> {
  _CaptureLayer(this.layer);
  final TreemapTileLayer<String> layer;
  late TreemapVisualContext<String> visual;

  @override
  TreemapAppearanceResolver<String>? get appearance => layer.appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return layer.build(context, visual);
  }
}

Widget _chart(
  TreemapTileLayer<String> layer, {
  Size size = const Size(200, 100),
  TreemapNormalizedTree<String>? tree,
  TreemapLayoutConfig<String> layout = const TreemapLayoutConfig(),
  TreemapController<String>? controller,
  TreemapTransitionSpec? transition,
  TreemapLabelLayer<String>? labels,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: TreemapChart<String>(
      tree: tree ?? _singleTree,
      tiles: layer,
      layout: layout,
      controller: controller,
      transition: transition,
      labels: labels,
      interaction: const TreemapInteractionConfig(
        zoomOnNodeTap: false,
        selectOnNodeTap: true,
      ),
    ),
  ),
);

void main() {
  testWidgets('const defaults allocate the full rectangular tile', (
    tester,
  ) async {
    const layer = TreemapCenteredWidgetLayer<String>(builder: _content);
    expect(layer.minimumSize, isNull);
    expect(layer.aspect, isNull);
    expect(layer.appearance, isNull);
    expect(layer.widthFactor, 1);
    expect(layer.heightFactor, 1);
    expect(layer.ignorePointer, isTrue);
    expect(layer.clipBehavior, Clip.hardEdge);
    await tester.pumpTreemapApp(_chart(layer));
    expect(tester.getSize(_leafContent), const Size(200, 100));
    expect(
      tester.getRect(_leafContent),
      tester.getRect(find.byType(TreemapChart<String>)),
    );
  });

  testWidgets('independent factors center and clip the allocated box', (
    tester,
  ) async {
    for (final clip in [Clip.hardEdge, Clip.none]) {
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredWidgetLayer<String>(
            builder: _content,
            widthFactor: .5,
            heightFactor: .25,
            clipBehavior: clip,
          ),
        ),
      );
      expect(tester.getSize(_leafContent), const Size(100, 25));
      expect(tester.getCenter(_leafContent), const Offset(100, 50));
      final clips = find.ancestor(
        of: _leafContent,
        matching: find.byType(ClipRect),
      );
      if (clip == Clip.none) {
        expect(clips, findsNothing);
      } else {
        expect(tester.getSize(clips), const Size(100, 25));
        expect(tester.widget<ClipRect>(clips).clipBehavior, clip);
      }
    }
  });

  testWidgets('aspect fits inside both factor-resolved dimensions', (
    tester,
  ) async {
    for (final entry in <(double?, Size)>[
      (null, const Size(100, 25)),
      (1, const Size(25, 25)),
      (2, const Size(50, 25)),
      (.5, const Size(12.5, 25)),
      (8, const Size(100, 12.5)),
      (4, const Size(100, 25)),
    ]) {
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredWidgetLayer<String>(
            builder: _content,
            widthFactor: .5,
            heightFactor: .25,
            aspect: entry.$1,
          ),
        ),
      );
      expect(tester.getSize(_leafContent), entry.$2, reason: '${entry.$1}');
      expect(tester.getCenter(_leafContent), const Offset(100, 50));
      expect(
        tester.getSize(
          find.ancestor(of: _leafContent, matching: find.byType(ClipRect)),
        ),
        entry.$2,
      );
    }
  });

  testWidgets('minimum size checks the aspect-fitted dimensions', (
    tester,
  ) async {
    for (final entry in <(double, Size, bool)>[
      (1, const Size(75, 50), false),
      (4, const Size(100, 30), false),
      (1, const Size(50, 50), true),
      (4, const Size(100, 25), true),
    ]) {
      var calls = 0;
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredWidgetLayer<String>(
            widthFactor: .5,
            heightFactor: .5,
            aspect: entry.$1,
            minimumSize: entry.$2,
            builder: (context, details, states) {
              calls++;
              return _content(context, details, states);
            },
          ),
        ),
      );
      expect(calls, entry.$3 ? greaterThan(0) : 0);
      expect(_leafContent, entry.$3 ? findsOneWidget : findsNothing);
    }
  });

  test('invalid aspect ratios assert during construction', () {
    for (final value in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => TreemapCenteredWidgetLayer<String>(
          builder: _content,
          aspect: value,
        ),
        throwsAssertionError,
      );
    }
  });

  testWidgets('cutoff checks both allocated dimensions and accepts equality', (
    tester,
  ) async {
    for (final entry in <(Size?, bool)>[
      (null, true),
      (const Size(101, 25), false),
      (const Size(100, 26), false),
      (const Size(100, 25), true),
      (Size.zero, true),
    ]) {
      var calls = 0;
      final layer = _CaptureLayer(
        TreemapCenteredWidgetLayer<String>(
          widthFactor: .5,
          heightFactor: .25,
          minimumSize: entry.$1,
          builder: (context, details, states) {
            calls++;
            return _content(context, details, states);
          },
        ),
      );
      await tester.pumpTreemapApp(_chart(layer));
      expect(calls, entry.$2 ? greaterThan(0) : 0, reason: '${entry.$1}');
      expect(_leafContent, entry.$2 ? findsOneWidget : findsNothing);
      expect(layer.visual.presentation.visibleLeafNodes, hasLength(1));
      expect(
        layer.visual.presentation.visibleLeafNodes.single.bounds.width,
        200,
      );
    }
  });

  testWidgets('zero factors and empty geometry never invoke the builder', (
    tester,
  ) async {
    var calls = 0;
    Widget builder(
      BuildContext context,
      TreemapNodeDetails<String> details,
      Set<TreemapVisualState> states,
    ) {
      calls++;
      return _content(context, details, states);
    }

    for (final factors in [(0.0, 1.0), (1.0, 0.0)]) {
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredWidgetLayer<String>(
            builder: builder,
            widthFactor: factors.$1,
            heightFactor: factors.$2,
            aspect: 1,
          ),
        ),
      );
    }
    await tester.pumpTreemapApp(
      _chart(
        TreemapCenteredWidgetLayer<String>(builder: builder),
        tree: TreemapNormalizer.normalize(
          TreemapNode<String>(
            key: 'root',
            children: [TreemapNode(key: 'zero', weight: 0)],
          ),
        ),
      ),
    );
    expect(calls, 0);
  });

  test('invalid factors assert during construction', () {
    for (final value in [-.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => TreemapCenteredWidgetLayer<String>(
          builder: _content,
          widthFactor: value,
        ),
        throwsAssertionError,
      );
      expect(
        () => TreemapCenteredWidgetLayer<String>(
          builder: _content,
          heightFactor: value,
        ),
        throwsAssertionError,
      );
    }
  });

  testWidgets('invalid minimum dimensions assert when building', (
    tester,
  ) async {
    await tester.pumpTreemapApp(
      _chart(const TreemapCenteredWidgetLayer<String>(builder: _content)),
    );
    final context = tester.element(find.byType(TreemapChart<String>));
    final capture = _CaptureLayer(
      const TreemapCenteredWidgetLayer<String>(builder: _content),
    );
    await tester.pumpTreemapApp(_chart(capture));
    for (final value in [-1.0, double.nan, double.infinity]) {
      for (final size in [Size(value, 0), Size(0, value)]) {
        expect(
          () => TreemapCenteredWidgetLayer<String>(
            builder: _content,
            minimumSize: size,
          ).build(context, capture.visual),
          throwsAssertionError,
        );
      }
    }
  });

  testWidgets('resize updates centering and cutoff without changing geometry', (
    tester,
  ) async {
    final layer = _CaptureLayer(
      const TreemapCenteredWidgetLayer<String>(
        builder: _content,
        widthFactor: .5,
        heightFactor: .5,
        minimumSize: Size(75, 40),
      ),
    );
    for (final size in [const Size(200, 100), const Size(100, 100)]) {
      await tester.pumpTreemapApp(_chart(layer, size: size));
      expect(layer.visual.presentation.visibleLeafNodes, hasLength(1));
      expect(_leafContent, size.width == 200 ? findsOneWidget : findsNothing);
      if (size.width == 200) {
        expect(tester.getSize(_leafContent), const Size(100, 50));
        expect(tester.getCenter(_leafContent), const Offset(100, 50));
      }
    }
  });

  testWidgets('transitions use displayed bounds for allocation and cutoff', (
    tester,
  ) async {
    final layer = _CaptureLayer(
      const TreemapCenteredWidgetLayer<String>(
        builder: _content,
        widthFactor: .5,
        heightFactor: .5,
        minimumSize: Size(60, 0),
      ),
    );
    TreemapNormalizedTree<String> tree(double weight) =>
        TreemapNormalizer.normalize(
          TreemapNode<String>(
            key: 'root',
            children: [
              TreemapNode(key: 'leaf', weight: weight),
              TreemapNode(key: 'other', weight: 10 - weight),
            ],
          ),
        );
    Widget chart(double weight) => _chart(
      layer,
      tree: tree(weight),
      layout: const TreemapLayoutConfig(
        policy: TreemapLayoutPolicy(
          rootRule: TreemapLayoutRule(
            algorithm: TreemapLayoutAlgorithm.dice,
            sort: TreemapSortPolicy.sourceOrder,
          ),
        ),
      ),
      transition: const TreemapTransitionSpec(
        duration: Duration(seconds: 1),
        curve: Curves.linear,
      ),
    );
    await tester.pumpTreemapApp(chart(2));
    await tester.pumpAndSettle();
    expect(_leafContent, findsNothing);
    await tester.pumpTreemapApp(chart(8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(layer.visual.presentation.isAnimating, isTrue);
    expect(_leafContent, findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    final bounds = layer
        .visual
        .presentation
        .details[const TreemapKey.source('leaf')]!
        .bounds;
    expect(bounds.width, closeTo(136, .01));
    expect(tester.getSize(_leafContent).width, closeTo(bounds.width * .5, .01));
    expect(
      tester.getCenter(_leafContent),
      Offset(bounds.centerX, bounds.centerY),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_leafContent), const Size(80, 50));
  });

  testWidgets(
    'composes with canvas layers and delivers pointer visual states',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final appearance = testTreemapAppearance<String>();
      var childTaps = 0;
      var states = <TreemapVisualState>{};
      final layer = _CaptureLayer(
        TreemapCompositeTileLayer<String>([
          TreemapTiles(appearance: appearance),
          TreemapCenteredWidgetLayer<String>(
            builder: (context, details, visualStates) {
              states = visualStates;
              return GestureDetector(
                onTap: () => childTaps++,
                child: _content(context, details, visualStates),
              );
            },
          ),
        ], appearance: appearance),
      );
      await tester.pumpTreemapApp(
        _chart(layer, controller: controller, labels: TreemapCanvasLabels()),
      );
      final snapshot = layer.visual.presentation.targetSnapshot;
      final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      expect(
        painters.map((w) => w.painter).whereType<TreemapTilePainter<String>>(),
        hasLength(1),
      );
      expect(
        painters
            .map((w) => w.painter)
            .whereType<TreemapCanvasLabelPainter<String>>(),
        hasLength(1),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 400));
      await mouse.moveTo(tester.getCenter(_leafContent));
      await tester.pump();
      expect(states, contains(TreemapVisualState.hovered));
      await tester.tapAt(tester.getCenter(_leafContent));
      await tester.pump();
      expect(childTaps, 0);
      expect(controller.selectedKeys, {'leaf'});
      expect(states, contains(TreemapVisualState.selected));
      layer.visual.actions.focus(const TreemapKey.source('leaf'));
      await tester.pump();
      expect(states, contains(TreemapVisualState.focused));
      expect(layer.visual.presentation.targetSnapshot, same(snapshot));
      await mouse.removePointer();
    },
  );

  testWidgets('ignorePointer false allows interactive content', (tester) async {
    var childTaps = 0;
    await tester.pumpTreemapApp(
      _chart(
        TreemapCenteredWidgetLayer<String>(
          ignorePointer: false,
          builder: (context, details, states) => GestureDetector(
            onTap: () => childTaps++,
            child: _content(context, details, states),
          ),
        ),
      ),
    );
    await tester.tap(_leafContent);
    expect(childTaps, 1);
  });

  testWidgets('targets collapsed parents and aggregates, excluding ancestors', (
    tester,
  ) async {
    final tree = TreemapNormalizer.normalize(
      TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(
            key: 'branch',
            children: [
              TreemapNode(key: 'large', weight: 98),
              TreemapNode(key: 'tiny-a', weight: 1),
              TreemapNode(key: 'tiny-b', weight: 1),
            ],
          ),
        ],
      ),
    );
    final layer = _CaptureLayer(
      const TreemapCenteredWidgetLayer<String>(builder: _content),
    );
    await tester.pumpTreemapApp(
      _chart(
        layer,
        tree: tree,
        layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
      ),
    );
    expect(_contentFor(const TreemapKey.source('branch')), findsOneWidget);
    expect(_contentFor(const TreemapKey.source('large')), findsNothing);
    await tester.pumpTreemapApp(
      _chart(
        layer,
        tree: tree,
        layout: const TreemapLayoutConfig(
          minimumWidth: 40,
          minimumHeight: 30,
          minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
        ),
      ),
    );
    final leaves = layer.visual.presentation.visibleLeafNodes;
    expect(leaves.any((node) => node.isAggregate), isTrue);
    for (final node in leaves) {
      expect(_contentFor(node.key), findsOneWidget);
    }
    expect(_contentFor(const TreemapKey.source('branch')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
