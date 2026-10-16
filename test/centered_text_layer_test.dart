import 'dart:ui' as ui;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/centered_text_painter.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _style = TextStyle(fontFamily: 'Ahem', height: 1, color: Colors.white);
const _leaf = TreemapKey.source('leaf');
final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [TreemapNode(key: 'leaf', label: 'I', weight: 1)],
  ),
);

String _text(
  BuildContext context,
  TreemapNodeDetails<String> details,
  Set<TreemapVisualState> states,
) => details.label ?? 'W';

TreemapCenteredTextLayer<String> _layer({String template = 'WW'}) =>
    TreemapCenteredTextLayer.fixed(
      template: template,
      textBuilder: _text,
      style: _style,
    );

Widget _chart(
  TreemapTileLayer<String> layer, {
  Size size = const Size(200, 100),
  TreemapNormalizedTree<String>? tree,
  TreemapLayoutConfig<String> layout = const TreemapLayoutConfig(),
  TreemapTransitionSpec? transition,
  TreemapController<String>? controller,
  TreemapLabelLayer<String>? labels,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: TreemapChart<String>(
      tree: tree ?? _tree,
      tiles: layer,
      layout: layout,
      transition: transition,
      controller: controller,
      labels: labels,
      interaction: const TreemapInteractionConfig(
        zoomOnNodeTap: false,
        selectOnNodeTap: true,
      ),
    ),
  ),
);

TreemapCenteredTextPainter<String> _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<TreemapCenteredTextPainter<String>>()
    .single;

final class _Canvas extends TestRecordingCanvas {
  final clips = <Rect>[];
  final translations = <Offset>[];
  final scales = <double>[];
  final paragraphs = <Offset>[];
  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => clips.add(rect);
  @override
  void translate(double dx, double dy) => translations.add(Offset(dx, dy));
  @override
  void scale(double sx, [double? sy]) {
    scales.add(sx);
    expect(sy, isNull);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      paragraphs.add(offset);
}

void main() {
  testWidgets(
    'template defines shared dimensions, alignment and canvas transform',
    (tester) async {
      await tester.pumpTreemapApp(_chart(_layer()));
      final painter = _painter(tester);
      expect(painter.referenceSize, const Size(128, 64));
      expect(painter.paintOffset, const Offset(-64, -32));
      final entry = painter.entries.single;
      expect(entry.bounds, const Rect.fromLTWH(0, 0, 200, 100));
      expect(entry.scale, 1.5625);
      expect(entry.painter.width, 128);
      expect(entry.painter.height, 64);
      expect(entry.painter.textAlign, TextAlign.center);
      expect(entry.painter.maxLines, 1);
      expect(entry.painter.strutStyle!.forceStrutHeight, isTrue);
      final glyph = entry.painter
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .single;
      expect(glyph.left, 32);
      expect(glyph.right, 96);
      final canvas = _Canvas();
      painter.paint(canvas, const Size(200, 100));
      expect(canvas.clips, [entry.bounds]);
      expect(canvas.translations, [const Offset(100, 50)]);
      expect(canvas.scales, [1.5625]);
      expect(canvas.paragraphs, [painter.paintOffset]);
    },
  );

  testWidgets('geometry and layer recreation reuse painters and fixed offset', (
    tester,
  ) async {
    await tester.pumpTreemapApp(_chart(_layer()));
    final before = _painter(tester);
    final text = before.entries.single.painter;
    await tester.pumpTreemapApp(_chart(_layer(), size: const Size(400, 300)));
    final after = _painter(tester);
    expect(after.entries.single.painter, same(text));
    expect(after.referenceSize, before.referenceSize);
    expect(after.paintOffset, before.paintOffset);
    expect(after.entries.single.bounds, const Rect.fromLTWH(0, 0, 400, 300));
    expect(after.entries.single.scale, 3.125);
    expect(text.debugDisposed, isFalse);
    await tester.pumpTreemapApp(const SizedBox());
    expect(text.debugDisposed, isTrue);
  });

  testWidgets(
    'font size and inherited text scaling do not determine fitted size',
    (tester) async {
      for (final fontSize in [8.0, 500.0]) {
        await tester.pumpTreemapApp(
          _chart(
            TreemapCenteredTextLayer<String>.fixed(
              template: 'WW',
              textBuilder: _text,
              style: _style.copyWith(fontSize: fontSize),
            ),
          ),
          textScaler: const TextScaler.linear(2),
        );
        expect(_painter(tester).referenceSize, const Size(128, 64));
        expect(_painter(tester).entries.single.scale, 1.5625);
      }
    },
  );

  testWidgets('factors, aspect and both cutoff dimensions precede callbacks', (
    tester,
  ) async {
    for (final config in <(double?, Size?, bool)>[
      (null, null, true),
      (null, const Size(100, 25), true),
      (null, const Size(101, 25), false),
      (null, const Size(100, 26), false),
      (1, const Size(26, 0), false),
      (1, const Size(25, 25), true),
      (4, const Size(100, 25), true),
    ]) {
      var calls = 0;
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredTextLayer<String>.fixed(
            template: 'W',
            style: _style,
            widthFactor: .5,
            heightFactor: .25,
            aspect: config.$1,
            minimumSize: config.$2,
            textBuilder: (context, details, states) {
              calls++;
              return 'I';
            },
          ),
        ),
      );
      final entries = _painter(tester).entries;
      expect(calls, config.$3 ? greaterThan(0) : 0);
      expect(entries.length, config.$3 ? 1 : 0);
      if (entries.isNotEmpty) {
        expect(entries.single.bounds.center, const Offset(100, 50));
        expect(
          entries.single.bounds.size,
          config.$1 == 1 ? const Size(25, 25) : const Size(100, 25),
        );
      }
    }
  });

  testWidgets('empty boxes and empty text omit content', (tester) async {
    var calls = 0;
    for (final factors in [(0.0, 1.0), (1.0, 0.0)]) {
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredTextLayer<String>.fixed(
            template: 'W',
            widthFactor: factors.$1,
            heightFactor: factors.$2,
            textBuilder: (context, details, states) {
              calls++;
              return 'I';
            },
          ),
        ),
      );
      expect(_painter(tester).entries, isEmpty);
      expect(calls, 0);
    }
    await tester.pumpTreemapApp(
      _chart(
        TreemapCenteredTextLayer<String>.fixed(
          template: 'W',
          textBuilder: (context, details, states) => '',
        ),
      ),
    );
    expect(_painter(tester).entries, isEmpty);
  });

  testWidgets(
    'typography, template, direction and locale invalidate cached text',
    (tester) async {
      TextPainter? previous;
      for (final config in <(String, TextStyle, TextDirection, Locale)>[
        ('WW', _style, TextDirection.ltr, const Locale('en')),
        ('WWW', _style, TextDirection.ltr, const Locale('en')),
        (
          'WWW',
          _style.copyWith(fontWeight: FontWeight.bold),
          TextDirection.ltr,
          const Locale('en'),
        ),
        ('WWW', _style, TextDirection.rtl, const Locale('en')),
        ('WWW', _style, TextDirection.rtl, const Locale('ar')),
      ]) {
        await tester.pumpTreemapApp(
          Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: config.$4,
              child: Directionality(
                textDirection: config.$3,
                child: _chart(
                  TreemapCenteredTextLayer<String>.fixed(
                    template: config.$1,
                    style: config.$2,
                    textBuilder: _text,
                  ),
                ),
              ),
            ),
          ),
          textDirection: config.$3,
        );
        final current = _painter(tester).entries.single.painter;
        if (previous != null) {
          expect(previous.debugDisposed, isTrue);
          expect(current, isNot(same(previous)));
        }
        expect(current.textDirection, config.$3);
        expect(current.locale, config.$4);
        previous = current;
      }
    },
  );

  testWidgets(
    'duplicate strings share layout and unused painters are disposed',
    (tester) async {
      var letter = 'I';
      final tree = TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [
            TreemapNode(key: 'a', weight: 1),
            TreemapNode(key: 'b', weight: 1),
          ],
        ),
      );
      final layer = TreemapCenteredTextLayer<String>.fixed(
        template: 'W',
        style: _style,
        textBuilder: (context, details, states) => letter,
      );
      await tester.pumpTreemapApp(_chart(layer, tree: tree));
      final entries = _painter(tester).entries;
      expect(entries[0].painter, same(entries[1].painter));
      final previous = entries[0].painter;
      letter = 'A';
      await tester.pumpTreemapApp(_chart(layer, tree: tree));
      expect(previous.debugDisposed, isTrue);
      expect(_painter(tester).entries[0].painter.plainText, 'A');
    },
  );

  testWidgets('displayed transition geometry scales retained painters', (
    tester,
  ) async {
    TreemapNormalizedTree<String> tree(double weight) =>
        TreemapNormalizer.normalize(
          TreemapNode<String>(
            key: 'root',
            children: [
              TreemapNode(key: 'leaf', label: 'I', weight: weight),
              TreemapNode(key: 'other', label: 'W', weight: 10 - weight),
            ],
          ),
        );
    Widget chart(double weight) => _chart(
      _layer(),
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
    final before = _painter(
      tester,
    ).entries.firstWhere((e) => e.key == _leaf).painter;
    await tester.pumpTreemapApp(chart(8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final during = _painter(tester).entries.firstWhere((e) => e.key == _leaf);
    expect(during.painter, same(before));
    expect(during.bounds.width, closeTo(88, .01));
    expect(during.scale, closeTo(88 / 128, .001));
    await tester.pumpAndSettle();
    expect(
      _painter(tester).entries.firstWhere((e) => e.key == _leaf).bounds.width,
      160,
    );
  });

  testWidgets(
    'composition preserves selection, hover, focus and canvas labels',
    (tester) async {
      final controller = TreemapController<String>();
      addTearDown(controller.dispose);
      final appearance = testTreemapAppearance<String>();
      var states = <TreemapVisualState>{};
      final layer = TreemapCenteredTextLayer<String>.fixed(
        template: 'W',
        style: _style,
        textBuilder: (context, details, visualStates) {
          states = visualStates;
          return 'I';
        },
      );
      await tester.pumpTreemapApp(
        _chart(
          TreemapCompositeTileLayer([
            TreemapTiles(appearance: appearance),
            layer,
          ], appearance: appearance),
          controller: controller,
          labels: TreemapCanvasLabels(),
        ),
      );
      final prepared = _painter(tester).entries.single.painter;
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(500, 400));
      await mouse.moveTo(const Offset(100, 50));
      await tester.pump();
      expect(states, contains(TreemapVisualState.hovered));
      await tester.tapAt(const Offset(100, 50));
      await tester.pump();
      expect(controller.selectedKeys, {'leaf'});
      expect(states, contains(TreemapVisualState.selected));
      final paintElement = tester.element(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is TreemapCenteredTextPainter<String>,
        ),
      );
      TreemapPresentationScope.maybeActionsOf<String>(
        paintElement,
      )!.focus(_leaf);
      await tester.pump();
      expect(states, contains(TreemapVisualState.focused));
      final chart = tester.widget<TreemapChart<String>>(
        find.byType(TreemapChart<String>),
      );
      expect(chart.labels, isA<TreemapCanvasLabels<String>>());
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<TreemapCanvasLabelPainter<String>>(),
        hasLength(1),
      );
      expect(_painter(tester).entries.single.painter, same(prepared));
      await mouse.removePointer();
    },
  );

  testWidgets(
    'collapsed parents and aggregates get text; expanded ancestors do not',
    (tester) async {
      final tree = TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [
            TreemapNode(
              key: 'branch',
              children: [
                TreemapNode(key: 'big', weight: 98),
                TreemapNode(key: 'tiny-a', weight: 1),
                TreemapNode(key: 'tiny-b', weight: 1),
              ],
            ),
          ],
        ),
      );
      await tester.pumpTreemapApp(
        _chart(
          _layer(),
          tree: tree,
          layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
        ),
      );
      expect(
        _painter(tester).entries.single.key,
        const TreemapKey.source('branch'),
      );
      await tester.pumpTreemapApp(
        _chart(
          _layer(),
          tree: tree,
          layout: const TreemapLayoutConfig(
            minimumWidth: 40,
            minimumHeight: 30,
            minimumNodePolicy: TreemapMinimumNodePolicy.aggregate,
          ),
        ),
      );
      final keys = _painter(tester).entries.map((e) => e.key);
      expect(keys.any((k) => k.isAggregate), isTrue);
      expect(keys, isNot(contains(const TreemapKey.source('branch'))));
    },
  );

  testWidgets('large visible sets retain every distinct painter on resize', (
    tester,
  ) async {
    final tree = TreemapNormalizer.normalize(
      TreemapNode<String>(
        key: 'root',
        children: [
          for (var i = 0; i < 600; i++)
            TreemapNode(key: '$i', label: '$i', weight: 1),
        ],
      ),
    );
    await tester.pumpTreemapApp(
      _chart(
        _layer(template: 'WWW'),
        tree: tree,
        size: const Size(700, 500),
      ),
    );
    final before = {for (final e in _painter(tester).entries) e.key: e.painter};
    expect(before, hasLength(600));
    await tester.pumpTreemapApp(
      _chart(
        _layer(template: 'WWW'),
        tree: tree,
        size: const Size(600, 400),
      ),
    );
    for (final entry in _painter(tester).entries) {
      expect(entry.painter, same(before[entry.key]));
    }
  });

  testWidgets('font loading invalidates metrics and disposes cached painters', (
    tester,
  ) async {
    await tester.pumpTreemapApp(_chart(_layer()));
    final before = _painter(tester).entries.single.painter;
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(before.debugDisposed, isTrue);
    expect(_painter(tester).entries.single.painter, isNot(same(before)));
  });

  test('invalid constructor inputs assert', () {
    expect(() => _layer(template: ''), throwsAssertionError);
    for (final value in [-1.0, 1.1, double.nan, double.infinity]) {
      expect(
        () => TreemapCenteredTextLayer<String>.fixed(
          template: 'W',
          textBuilder: _text,
          widthFactor: value,
        ),
        throwsAssertionError,
      );
      expect(
        () => TreemapCenteredTextLayer<String>.fixed(
          template: 'W',
          textBuilder: _text,
          heightFactor: value,
        ),
        throwsAssertionError,
      );
    }
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => TreemapCenteredTextLayer<String>.fixed(
          template: 'W',
          textBuilder: _text,
          aspect: value,
        ),
        throwsAssertionError,
      );
    }
  });

  testWidgets('invalid minimums and multiline templates or content assert', (
    tester,
  ) async {
    for (final size in [
      const Size(-1, 0),
      const Size(0, -1),
      const Size(double.infinity, 0),
      const Size(0, double.nan),
    ]) {
      await tester.pumpTreemapApp(
        _chart(
          TreemapCenteredTextLayer<String>.fixed(
            template: 'W',
            textBuilder: _text,
            minimumSize: size,
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
      await tester.pumpTreemapApp(const SizedBox());
    }
    for (final template in ['W\nW', 'W\rW', 'W\u2028W']) {
      await tester.pumpTreemapApp(_chart(_layer(template: template)));
      expect(tester.takeException(), isAssertionError);
      await tester.pumpTreemapApp(const SizedBox());
    }
    await tester.pumpTreemapApp(
      _chart(
        TreemapCenteredTextLayer<String>.fixed(
          template: 'WW',
          textBuilder: (context, details, states) => 'I\nI',
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
