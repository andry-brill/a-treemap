import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:any_treemap/src/painters/centered_text_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _leaf = TreemapKey.source('leaf');
const _title = TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1);
const _value = TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1);
const _config = TreemapLabelConfig<String>(
  titleStyle: _title,
  valueStyle: _value,
  spacing: 4,
  padding: EdgeInsets.fromLTRB(3, 2, 3, 4),
);
final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [TreemapNode(key: 'leaf', label: 'Leaf', weight: 1)],
  ),
);

final class _Capture implements TreemapTileLayer<String> {
  _Capture({
    this.region = TreemapContentRegion.available,
    this.factor = 1,
    this.aspect,
    this.minimum,
  });
  final TreemapContentRegion region;
  final double factor;
  final double? aspect;
  final Size? minimum;
  int widgetCalls = 0;
  int textCalls = 0;
  late TreemapVisualContext<String> visual;
  @override
  final TreemapAppearanceResolver<String> appearance =
      testTreemapAppearance<String>();
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return TreemapCompositeTileLayer<String>([
      TreemapTiles(appearance: appearance),
      TreemapCenteredWidgetLayer(
        region: region,
        widthFactor: factor,
        heightFactor: factor,
        aspect: aspect,
        minimumSize: minimum,
        builder: (_, details, states) {
          widgetCalls++;
          return ColoredBox(
            key: ValueKey('body-${details.key}'),
            color: Colors.orange,
          );
        },
      ),
      TreemapCenteredTextLayer.fixed(
        template: 'WW',
        style: _title,
        region: region,
        widthFactor: factor,
        heightFactor: factor,
        aspect: aspect,
        minimumSize: minimum,
        textBuilder: (_, details, states) {
          textCalls++;
          return 'I';
        },
      ),
    ], appearance: appearance).build(context, visual);
  }
}

Widget _chart(
  _Capture tiles,
  TreemapLabelLayer<String>? labels, {
  Size size = const Size(200, 100),
  TreemapNormalizedTree<String>? tree,
  TreemapLayoutConfig<String> layout = const TreemapLayoutConfig(),
  TreemapTransitionSpec? transition,
  TreemapController<String>? controller,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: TreemapChart<String>(
      tree: tree ?? _tree,
      tiles: tiles,
      labels: labels,
      layout: layout,
      transition: transition,
      controller: controller,
      interaction: const TreemapInteractionConfig(
        zoomOnNodeTap: false,
        selectOnNodeTap: true,
      ),
    ),
  ),
);

TreemapCenteredTextPainter<String> _textPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapCenteredTextPainter<String>>()
    .single;
TreemapCanvasLabelPainter<String> _labelsPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TreemapCanvasLabelPainter<String>>()
    .single;

void _expectBoth(
  WidgetTester tester,
  Rect rect, [
  TreemapKey<String> key = _leaf,
]) {
  expect(tester.getRect(find.byKey(ValueKey('body-$key'))), rect);
  expect(
    _textPainter(tester).entries.singleWhere((e) => e.key == key).bounds,
    rect,
  );
}

final class _Overlay implements TreemapLabelLayer<String> {
  @override
  double? resolveParentHeaderHeight(BuildContext context) => null;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) =>
      const SizedBox.expand();
}

final class _CustomPlacement
    implements
        TreemapLabelLayer<String>,
        TreemapLabelPlacementProvider<String> {
  int prepares = 0;
  @override
  double? resolveParentHeaderHeight(BuildContext context) => null;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) =>
      throw StateError('Prepared output should be used directly.');
  @override
  TreemapLabelPlacement<String> preparePlacement(
    BuildContext context,
    TreemapVisualContext<String> visual,
  ) {
    prepares++;
    return TreemapLabelPlacement(
      child: const SizedBox.expand(),
      contentBounds: {_leaf: const Rect.fromLTWH(10, 30, 180, 60)},
    );
  }
}

void main() {
  for (final alignment in [
    Alignment.topLeft,
    Alignment.bottomRight,
    Alignment.center,
  ]) {
    testWidgets('both layers share $alignment label placement', (tester) async {
      final capture = _Capture();
      await tester.pumpTreemapApp(
        _chart(
          capture,
          TreemapCanvasLabels(config: _config.copyWith(alignment: alignment)),
        ),
      );
      final expected = alignment == Alignment.center
          ? const Rect.fromLTWH(0, 0, 200, 100)
          : Rect.fromLTWH(0, alignment.y == -1 ? 40 : 0, 200, 60);
      _expectBoth(tester, expected);
      final plan = _labelsPainter(tester).prepare();
      expect(plan.entries, hasLength(2));
      if (alignment != Alignment.center) {
        for (final entry in plan.entries) {
          expect(
            (entry.offset & entry.painter.size).overlaps(expected),
            isFalse,
          );
        }
      }
      expect(capture.visual.presentation.details[_leaf]!.bounds.height, 100);
    });
  }

  testWidgets(
    'custom line gaps reserve measured space for both centered layers',
    (tester) async {
      for (final alignment in [Alignment.topLeft, Alignment.bottomRight]) {
        for (final scale in [1.0, 2.0]) {
          final capture = _Capture();
          final labels = TreemapCanvasLabels<String>(
            config: _config.copyWith(
              alignment: alignment,
              spacing: 6.5,
              linesBuilder: (_, _, _, _) => const [
                TreemapCanvasLabelLine(text: 'Title', style: _title),
                TreemapCanvasLabelLine(text: 'Second', style: _value),
                TreemapCanvasLabelLine(text: '1', style: _value),
              ],
            ),
          );
          for (final height in [200.0, 150.0]) {
            await tester.pumpTreemapApp(
              _chart(capture, labels, size: Size(200, height)),
              textScaler: TextScaler.linear(scale),
            );
            final reservedHeight = 40 * scale + 2 * 6.5 + 6;
            final body = Rect.fromLTWH(
              0,
              alignment.y == -1 ? reservedHeight : 0,
              200,
              height - reservedHeight,
            );
            _expectBoth(tester, body);
            final plan = _labelsPainter(tester).prepare();
            expect(plan.contentBounds[_leaf], body);
            expect(plan.entries, hasLength(3));
            for (var i = 1; i < plan.entries.length; i++) {
              final before = plan.entries[i - 1];
              final after = plan.entries[i];
              expect(
                after.offset.dy - before.offset.dy - before.painter.height,
                6.5,
              );
            }
            expect(
              capture.visual.presentation.details[_leaf]!.bounds.height,
              height,
            );
          }
          // No phantom reservation when the complete block, including both gaps,
          // cannot fit. The centered layers can use the full tile again.
          final height = 40 * scale + 2 * 6.5 + 6 - .5;
          await tester.pumpTreemapApp(
            _chart(capture, labels, size: Size(200, height)),
            textScaler: TextScaler.linear(scale),
          );
          expect(_labelsPainter(tester).prepare().entries, isEmpty);
          _expectBoth(tester, Rect.fromLTWH(0, 0, 200, height));
        }
      }
    },
  );

  testWidgets('zero or one custom line reserves no gaps', (tester) async {
    for (final count in [0, 1]) {
      final capture = _Capture();
      await tester.pumpTreemapApp(
        _chart(
          capture,
          TreemapCanvasLabels(
            config: _config.copyWith(
              spacing: 80,
              linesBuilder: (_, _, _, _) => const [
                TreemapCanvasLabelLine(text: 'Title', style: _title),
              ].take(count),
            ),
          ),
        ),
      );
      final reserved = count == 0 ? 0.0 : 26.0;
      _expectBoth(tester, Rect.fromLTWH(0, reserved, 200, 100 - reserved));
      expect(_labelsPainter(tester).prepare().entries, hasLength(count));
    }
  });

  testWidgets('full tile and disabled reservation restore original bounds', (
    tester,
  ) async {
    for (final ignore in [true, false]) {
      await tester.pumpTreemapApp(
        _chart(
          _Capture(
            region: ignore
                ? TreemapContentRegion.tile
                : TreemapContentRegion.available,
          ),
          TreemapCanvasLabels(
            config: _config,
            reservation: ignore
                ? const TreemapLabelReservation.automatic()
                : const TreemapLabelReservation.none(),
          ),
        ),
      );
      _expectBoth(tester, const Rect.fromLTWH(0, 0, 200, 100));
    }
  });

  testWidgets('factors, aspect and cutoff operate on the remaining body', (
    tester,
  ) async {
    for (final minimum in [
      const Size(30, 30),
      const Size(31, 30),
      const Size(30, 31),
    ]) {
      final capture = _Capture(factor: .5, aspect: 1, minimum: minimum);
      await tester.pumpTreemapApp(
        _chart(capture, TreemapCanvasLabels(config: _config)),
      );
      if (minimum == const Size(30, 30)) {
        _expectBoth(tester, const Rect.fromLTWH(85, 55, 30, 30));
      } else {
        expect(capture.textCalls, 0);
        expect(capture.widgetCalls, 0);
        expect(_textPainter(tester).entries, isEmpty);
      }
      expect(capture.visual.presentation.visibleLeafNodes, hasLength(1));
    }
  });

  testWidgets('omitted and empty automatic labels reserve nothing', (
    tester,
  ) async {
    for (final config in [
      _config.copyWith(showTitle: false, showValue: false),
      _config.copyWith(titleFormatter: (_) => '', valueFormatter: (_) => ''),
      _config.copyWith(titleStyle: _title.copyWith(fontSize: 120)),
      _config.copyWith(padding: const EdgeInsets.all(100)),
    ]) {
      await tester.pumpTreemapApp(
        _chart(_Capture(), TreemapCanvasLabels(config: config)),
      );
      _expectBoth(tester, const Rect.fromLTWH(0, 0, 200, 100));
      expect(_labelsPainter(tester).prepare().entries, isEmpty);
    }
  });

  testWidgets(
    'fixed strip stays reserved for omitted text and can consume the body',
    (tester) async {
      for (final height in [0.0, 30.0, 100.0, 200.0]) {
        final capture = _Capture();
        await tester.pumpTreemapApp(
          _chart(
            capture,
            TreemapCanvasLabels(
              config: _config.copyWith(showTitle: false, showValue: false),
              reservation: TreemapLabelReservation.top(height: height),
            ),
          ),
        );
        if (height < 100) {
          _expectBoth(tester, Rect.fromLTWH(0, height, 200, 100 - height));
        } else {
          expect(capture.textCalls, 0);
          expect(capture.widgetCalls, 0);
          expect(_textPainter(tester).entries, isEmpty);
        }
      }
    },
  );

  testWidgets(
    'widget labels occupy their declared strip, including virtualization',
    (tester) async {
      final tree = TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [
            TreemapNode(key: 'leaf', weight: 3),
            TreemapNode(key: 'other', weight: 1),
          ],
        ),
      );
      final capture = _Capture();
      await tester.pumpTreemapApp(
        _chart(
          capture,
          TreemapWidgetLabels(
            maximumNodes: 1,
            reservation: const TreemapLabelReservation.bottom(height: 24),
            builder: (_, details, _) => ColoredBox(
              key: ValueKey('label-${details.key}'),
              color: Colors.blue,
            ),
          ),
          tree: tree,
        ),
      );
      for (final node in capture.visual.presentation.visibleLeafNodes) {
        final tile = capture.visual.contentBoundsFor(
          node.key,
          region: TreemapContentRegion.tile,
        );
        final reserved = node.key == _leaf;
        _expectBoth(
          tester,
          Rect.fromLTRB(
            tile.left,
            tile.top,
            tile.right,
            tile.bottom - (reserved ? 24 : 0),
          ),
          node.key,
        );
        final label = find.byKey(ValueKey('label-${node.key}'));
        expect(label, reserved ? findsOneWidget : findsNothing);
        if (reserved) {
          expect(
            tester.getRect(label),
            Rect.fromLTWH(tile.left, tile.bottom - 24, tile.width, 24),
          );
        }
      }
    },
  );

  testWidgets('preparation is shared and painting never reruns formatters', (
    tester,
  ) async {
    var calls = 0;
    final labels = TreemapCanvasLabels<String>(
      config: _config.copyWith(
        linesBuilder: (_, _, _, _) {
          calls++;
          return const [
            TreemapCanvasLabelLine(text: 'One', style: _title),
            TreemapCanvasLabelLine(text: 'Two', style: _value),
          ];
        },
      ),
    );
    await tester.pumpTreemapApp(_chart(_Capture(), labels));
    expect(calls, 1);
    _expectBoth(tester, const Rect.fromLTWH(0, 40, 200, 60));
    final painter = _labelsPainter(tester);
    final plan = painter.prepare();
    expect(painter.prepare(), same(plan));
    painter.paint(TestRecordingCanvas(), const Size(200, 100));
    expect(calls, 1);
    final paragraph = plan.entries.first.painter;
    await tester.pumpTreemapApp(_chart(_Capture(), labels));
    expect(
      _labelsPainter(tester).prepare().entries.first.painter,
      same(paragraph),
    );
  });

  testWidgets(
    'text scaling, RTL, wrapping and resizing update the shared allocation',
    (tester) async {
      final capture = _Capture();
      final labels = TreemapCanvasLabels<String>(
        config: _config.copyWith(
          showValue: false,
          titleFormatter: (_) => 'AAAA AAAA AAAA',
          maxLines: 4,
          padding: EdgeInsets.zero,
        ),
      );
      await tester.pumpTreemapApp(
        _chart(capture, labels, size: const Size(300, 200)),
      );
      final first = _textPainter(tester).entries.single.painter;
      _expectBoth(tester, const Rect.fromLTWH(0, 20, 300, 180));
      await tester.pumpTreemapApp(
        _chart(capture, labels, size: const Size(100, 200)),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.linear(1.2),
      );
      final height = _labelsPainter(
        tester,
      ).prepare().entries.single.painter.height;
      expect(height, greaterThan(20));
      _expectBoth(tester, Rect.fromLTWH(0, height, 100, 200 - height));
      final rtl = _textPainter(tester).entries.single.painter;
      expect(rtl, isNot(same(first)));
      await tester.pumpTreemapApp(
        _chart(capture, labels, size: const Size(100, 250)),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.linear(1.2),
      );
      expect(_textPainter(tester).entries.single.painter, same(rtl));
      _expectBoth(tester, Rect.fromLTWH(0, height, 100, 250 - height));
    },
  );

  testWidgets(
    'selection updates label reservation without changing tile geometry',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final capture = _Capture();
      await tester.pumpTreemapApp(
        _chart(
          capture,
          TreemapCanvasLabels(
            config: _config.copyWith(
              selectedStyle: const TreemapLabelStyle(
                titleStyle: TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 30,
                  height: 1,
                ),
              ),
            ),
          ),
          controller: controller,
        ),
      );
      final snapshot = capture.visual.presentation.targetSnapshot;
      await tester.tapAt(const Offset(100, 70));
      await tester.pump();
      expect(controller.selectedKeys, {'leaf'});
      expect(capture.visual.presentation.targetSnapshot, same(snapshot));
      _expectBoth(tester, const Rect.fromLTWH(0, 50, 200, 50));
    },
  );

  testWidgets(
    'existing custom overlays and optional placement providers compose',
    (tester) async {
      await tester.pumpTreemapApp(_chart(_Capture(), _Overlay()));
      _expectBoth(tester, const Rect.fromLTWH(0, 0, 200, 100));
      final provider = _CustomPlacement();
      await tester.pumpTreemapApp(_chart(_Capture(), provider));
      expect(provider.prepares, 1);
      _expectBoth(tester, const Rect.fromLTWH(10, 30, 180, 60));
    },
  );

  final nested = TreemapNormalizer.normalize(
    TreemapNode<String>(
      key: 'root',
      children: [
        TreemapNode(
          key: 'parent',
          label: 'Parent',
          children: [TreemapNode(key: 'leaf', label: 'Leaf', weight: 1)],
        ),
      ],
    ),
  );

  testWidgets(
    'own headers are excluded without subtracting ancestor headers twice',
    (tester) async {
      final capture = _Capture();
      final labels = TreemapCanvasLabels<String>(
        config: _config,
        parentLabels: const TreemapParentLabelConfig(height: 20),
      );
      await tester.pumpTreemapApp(_chart(capture, labels, tree: nested));
      _expectBoth(tester, const Rect.fromLTWH(0, 60, 200, 40));
      await tester.pumpTreemapApp(
        _chart(
          capture,
          labels,
          tree: TreemapNormalizer.normalize(
            TreemapNode<String>(
              key: 'root',
              children: [
                TreemapNode(
                  key: 'parent',
                  label: 'Parent',
                  children: [
                    TreemapNode(key: 'leaf', label: 'Leaf', weight: 1),
                    TreemapNode(key: 'other', label: 'Other', weight: 1),
                  ],
                ),
              ],
            ),
          ),
          layout: const TreemapLayoutConfig(
            minimumHeight: 90,
            minimumNodePolicy: TreemapMinimumNodePolicy.hide,
          ),
        ),
      );
      expect(
        capture.visual.presentation.visibleLeafNodes.single.key,
        const TreemapKey.source('parent'),
      );
      _expectBoth(
        tester,
        const Rect.fromLTWH(0, 20, 200, 80),
        const TreemapKey.source('parent'),
      );
      await tester.pumpTreemapApp(
        _chart(
          capture,
          labels,
          tree: nested,
          layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
        ),
      );
      _expectBoth(
        tester,
        const Rect.fromLTWH(0, 40, 200, 60),
        const TreemapKey.source('parent'),
      );
    },
  );

  testWidgets(
    'displayed header transitions update cutoff and preserve cached fixed text',
    (tester) async {
      final capture = _Capture(minimum: const Size(0, 50));
      Widget chart(double height) => _chart(
        capture,
        TreemapCanvasLabels(
          config: _config.copyWith(showTitle: false, showValue: false),
          parentLabels: TreemapParentLabelConfig(height: height),
        ),
        tree: nested,
        transition: const TreemapTransitionSpec(
          duration: Duration(seconds: 1),
          curve: Curves.linear,
        ),
      );
      await tester.pumpTreemapApp(chart(20));
      await tester.pumpAndSettle();
      final paragraph = _textPainter(tester).entries.single.painter;
      _expectBoth(tester, const Rect.fromLTWH(0, 20, 200, 80));
      await tester.pumpTreemapApp(chart(80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      _expectBoth(tester, const Rect.fromLTWH(0, 50, 200, 50));
      expect(_textPainter(tester).entries.single.painter, same(paragraph));
      capture.widgetCalls = capture.textCalls = 0;
      await tester.pump(const Duration(milliseconds: 100));
      expect(_textPainter(tester).entries, isEmpty);
      expect(capture.widgetCalls, 0);
      expect(capture.textCalls, 0);
    },
  );

  test('invalid fixed reservation heights assert', () {
    for (final height in [-1.0, double.nan, double.infinity]) {
      expect(
        () => TreemapLabelReservation.top(height: height),
        throwsAssertionError,
      );
      expect(
        () => TreemapLabelReservation.bottom(height: height),
        throwsAssertionError,
      );
    }
  });

  testWidgets('explicit docking overrides middle label alignment', (
    tester,
  ) async {
    for (final top in [true, false]) {
      await tester.pumpTreemapApp(
        _chart(
          _Capture(),
          TreemapCanvasLabels(
            config: _config.copyWith(alignment: Alignment.center),
            reservation: top
                ? const TreemapLabelReservation.top()
                : const TreemapLabelReservation.bottom(),
          ),
        ),
      );
      _expectBoth(tester, Rect.fromLTWH(0, top ? 40 : 0, 200, 60));
      final text = _labelsPainter(tester).prepare().entries.first;
      expect(text.offset.dy, top ? 2 : 62);
    }
  });

  testWidgets('aggregate blocks reserve their own terminal labels', (
    tester,
  ) async {
    final capture = _Capture();
    final tree = TreemapNormalizer.normalize(
      TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(key: 'big', label: 'Big', weight: 8),
          TreemapNode(key: 'small-a', weight: 1),
          TreemapNode(key: 'small-b', weight: 1),
        ],
      ),
    );
    await tester.pumpTreemapApp(
      _chart(
        capture,
        TreemapCanvasLabels(
          config: _config.copyWith(
            titleStyle: _value,
            showValue: false,
            padding: EdgeInsets.zero,
          ),
        ),
        tree: tree,
        layout: const TreemapLayoutConfig(
          policy: TreemapLayoutPolicy(
            rootRule: TreemapLayoutRule(algorithm: TreemapLayoutAlgorithm.dice),
          ),
          minimumWidth: 30,
          minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
        ),
      ),
    );
    final leaves = capture.visual.presentation.visibleLeafNodes;
    expect(leaves, hasLength(2));
    expect(leaves.where((node) => node.isAggregate), hasLength(1));
    for (final node in leaves) {
      _expectBoth(
        tester,
        Rect.fromLTWH(
          node.bounds.left,
          node.bounds.top + 10,
          node.bounds.width,
          node.bounds.height - 10,
        ),
        node.key,
      );
    }
  });

  testWidgets(
    'a full structural header skips content unless full tile is requested',
    (tester) async {
      for (final region in TreemapContentRegion.values) {
        final capture = _Capture(region: region);
        await tester.pumpTreemapApp(
          _chart(
            capture,
            TreemapCanvasLabels(
              config: _config,
              parentLabels: const TreemapParentLabelConfig(height: 200),
            ),
            tree: nested,
          ),
        );
        expect(
          capture.visual.presentation.visibleLeafNodes.single.key,
          const TreemapKey.source('parent'),
        );
        if (region == TreemapContentRegion.available) {
          expect(capture.widgetCalls, 0);
          expect(capture.textCalls, 0);
        } else {
          _expectBoth(
            tester,
            const Rect.fromLTWH(0, 0, 200, 100),
            const TreemapKey.source('parent'),
          );
        }
      }
    },
  );

  testWidgets('widget reservations require an explicit height', (tester) async {
    await tester.pumpTreemapApp(
      _chart(
        _Capture(),
        TreemapWidgetLabels(
          reservation: const TreemapLabelReservation.top(),
          builder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
