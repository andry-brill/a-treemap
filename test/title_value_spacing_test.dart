import 'dart:ui' as ui;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _title = TextStyle(
  fontFamily: 'Ahem',
  fontSize: 20,
  height: 1,
  color: Colors.red,
);
const _value = TextStyle(
  fontFamily: 'Ahem',
  fontSize: 10,
  height: 1,
  color: Colors.blue,
);
const _config = TreemapLabelConfig<String>(
  titleStyle: _title,
  valueStyle: _value,
);
const _padding = EdgeInsets.fromLTRB(4, 2, 4, 3);
final _paddedConfig = _config.copyWith(padding: _padding);
const _parent = TreemapKey.source('parent');
final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [
      TreemapNode(
        key: 'parent',
        label: 'Parent',
        children: [TreemapNode(key: 'child', label: 'Child', weight: 1)],
      ),
    ],
  ),
);

/// Record the real TextPainter output before host-specific glyph rasterization.
/// Ink can extend outside a paragraph's origin and be clipped at the canvas edge;
/// measuring its colored pixels would conflate those effects with label layout.
final class _ParagraphCanvas extends TestRecordingCanvas {
  final List<Rect> paragraphs = [];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    paragraphs.add(offset & Size(paragraph.longestLine, paragraph.height));
  }
}

List<Rect> _paint({
  TreemapLabelConfig<String> config = _config,
  TreemapParentLabelConfig? parent,
  Size size = const Size(100, 100),
}) {
  final bounds = TreemapBounds.fromLTWH(0, 0, size.width, size.height);
  final node = TreemapGeometryNode<String>(
    key: _parent,
    bounds: bounds,
    headerBounds: parent == null ? null : bounds,
    weight: 1,
    depth: 1,
    kind: TreemapGeometryKind.source,
    label: 'AA',
    parentKey: null,
    opacity: 1,
  );
  final canvas = _ParagraphCanvas();
  TreemapCanvasLabelPainter<String>(
    nodes: [node],
    details: {_parent: TreemapNodeDetails(geometry: node, path: [])},
    appearances: {_parent: const TreemapAppearance(color: Colors.black)},
    styles: {
      _parent: TreemapLabelStyle(
        titleStyle: config.titleStyle,
        valueStyle: config.valueStyle,
      ),
    },
    config: config,
    parentLabels: parent,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    locale: null,
    textCache: TreemapTextLayoutCache(),
  ).paint(canvas, size);
  return canvas.paragraphs;
}

final class _CaptureTiles implements TreemapTileLayer<String> {
  _CaptureTiles({TreemapAppearanceResolver<String>? appearance})
    : appearance = appearance ?? testTreemapAppearance<String>();
  @override
  final TreemapAppearanceResolver<String> appearance;
  late TreemapVisualContext<String> visual;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return const SizedBox.expand();
  }
}

Widget _emptyLabel(
  BuildContext context,
  TreemapNodeDetails<String> details,
  Set<TreemapVisualState> states,
) => const SizedBox.shrink();

void main() {
  test(
    'label padding defaults to zero and participates in value semantics',
    () {
      expect(_config.padding, EdgeInsets.zero);
      const insets = EdgeInsets.fromLTRB(2.5, 3.5, 4.5, 5.5);
      final padded = _config.copyWith(padding: insets);
      expect(padded.padding, insets);
      expect(padded, isNot(_config));
      expect(padded.copyWith(), padded);
      expect(padded.copyWith().hashCode, padded.hashCode);
      expect(padded.copyWith(padding: EdgeInsets.zero), _config);
    },
  );

  testWidgets(
    'padding insets standard and custom canvas children and headers',
    (tester) async {
      const insets = EdgeInsets.fromLTRB(4, 2, 8, 3);
      for (final parent in [null, const TreemapParentLabelConfig()]) {
        for (final custom in [false, true]) {
          for (final alignment in [Alignment.topLeft, Alignment.bottomRight]) {
            final config = _config.copyWith(
              alignment: alignment,
              linesBuilder: custom
                  ? (_, _, _, _) => const [
                      TreemapCanvasLabelLine(text: 'AA', style: _title),
                      TreemapCanvasLabelLine(text: 'B', style: _value),
                    ]
                  : null,
            );
            final plain = _paint(config: config, parent: parent);
            expect(plain, hasLength(2));
            for (final padding in [
              insets,
              const EdgeInsets.fromLTRB(4.5, 2.5, 8.5, 3.5),
            ]) {
              final padded = _paint(
                config: config.copyWith(padding: padding),
                parent: parent,
              );
              final offset = alignment == Alignment.topLeft
                  ? Offset(padding.left, padding.top)
                  : Offset(-padding.right, -padding.bottom);
              expect(padded, hasLength(2));
              expect(padded.first, plain.first.shift(offset));
              expect(padded.last, plain.last.shift(offset));
            }
          }
          final config = _config.copyWith(
            linesBuilder: custom
                ? (_, _, _, _) => const [
                    TreemapCanvasLabelLine(text: 'AA', style: _title),
                    TreemapCanvasLabelLine(text: 'B', style: _value),
                  ]
                : null,
          );
          final plain = _paint(
            config: config,
            parent: parent,
            size: const Size(100, 32),
          );
          expect(plain, hasLength(2));
          final omitted = _paint(
            config: config.copyWith(padding: insets),
            parent: parent,
            size: const Size(100, 32),
          );
          expect(omitted, isEmpty);
        }
      }
    },
  );

  testWidgets('only vertical padding changes automatic header geometry', (
    tester,
  ) async {
    for (final widgets in [false, true]) {
      // Start a fresh chart when switching renderer so snapshot identity checks
      // describe updates within one renderer.
      await tester.pumpTreemapApp(const SizedBox.shrink());
      final tiles = _CaptureTiles();

      Future<TreemapGeometrySnapshot<String>> show(
        EdgeInsets padding, {
        TreemapParentLabelConfig? parent = const TreemapParentLabelConfig(),
        double scale = 1,
      }) async {
        final config = _config.copyWith(padding: padding, spacing: 6.5);
        await tester.pumpTreemapApp(
          SizedBox(
            width: 400,
            height: 240,
            child: TreemapChart<String>(
              tree: _tree,
              tiles: tiles,
              labels: widgets
                  ? TreemapWidgetLabels<String>(
                      builder: _emptyLabel,
                      config: config,
                      parentLabels: parent,
                    )
                  : TreemapCanvasLabels<String>(
                      config: config,
                      parentLabels: parent,
                    ),
            ),
          ),
          textScaler: TextScaler.linear(scale),
        );
        await tester.pumpAndSettle();
        return tiles.visual.presentation.targetSnapshot!;
      }

      final plain = await show(EdgeInsets.zero);
      expect(plain.index[_parent]!.headerBounds!.height, 36.5);
      final padded = await show(_padding);
      expect(padded.index[_parent]!.headerBounds!.height, 41.5);
      expect(padded.index[_parent]!.bounds, plain.index[_parent]!.bounds);
      expect(await show(const EdgeInsets.fromLTRB(10, 2, 20, 3)), same(padded));
      expect(
        (await show(_padding, scale: 2)).index[_parent]!.headerBounds!.height,
        71.5,
      );
      const fixed = TreemapParentLabelConfig(height: 56);
      final fixedTarget = await show(EdgeInsets.zero, parent: fixed);
      expect(await show(_padding, parent: fixed), same(fixedTarget));
      final disabled = await show(EdgeInsets.zero, parent: null);
      expect(await show(_padding, parent: null), same(disabled));
      const hidden = TreemapParentLabelConfig(
        showTitle: false,
        showValue: false,
      );
      expect(await show(_padding, parent: hidden), same(disabled));
      expect(await show(EdgeInsets.zero), isNot(same(padded)));
    }
  });

  test(
    'spacing defaults, copies, equality and finite nonnegative contract',
    () {
      expect(_config.spacing, 0);
      final spaced = _config.copyWith(spacing: 6.5);
      expect(spaced.spacing, 6.5);
      expect(spaced.copyWith(), spaced);
      expect(spaced.copyWith().hashCode, spaced.hashCode);
      expect(spaced, isNot(_config));
      expect(spaced.copyWith(spacing: 0), _config);
      const widgets = TreemapWidgetLabels<String>(builder: _emptyLabel);
      expect(widgets.config, const TreemapLabelConfig<String>());
      expect(widgets.config.spacing, 0);
      expect(widgets.config.titleStyle.fontSize, 12);
      expect(widgets.config.titleStyle.fontWeight, FontWeight.w600);
      expect(widgets.config.valueStyle.fontSize, 11);
      expect(widgets.config.padding, EdgeInsets.zero);
      for (final invalid in [
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => _config.copyWith(spacing: invalid), throwsAssertionError);
      }
    },
  );

  testWidgets('both label layers consume one shared spacing configuration', (
    tester,
  ) async {
    final shared = _paddedConfig.copyWith(spacing: 6.5);
    var customCalls = 0;
    final custom = shared.copyWith(
      linesBuilder: (_, _, _, _) {
        customCalls++;
        return const [];
      },
    );
    await tester.pumpTreemapApp(
      Builder(
        builder: (context) {
          for (final config in [shared, custom]) {
            final widgets = TreemapWidgetLabels<String>(
              builder: _emptyLabel,
              config: config,
              parentLabels: const TreemapParentLabelConfig(),
            );
            final canvas = TreemapCanvasLabels<String>(
              config: config,
              parentLabels: const TreemapParentLabelConfig(),
            );
            expect(widgets.config, same(config));
            expect(canvas.config, same(config));
            expect(widgets.resolveParentHeaderHeight(context), 41.5);
            expect(
              canvas.resolveParentHeaderHeight(context),
              config.linesBuilder == null ? 41.5 : 35,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
    expect(customCalls, 0);
  });

  testWidgets('widget metrics use shared direction without invoking callbacks', (
    tester,
  ) async {
    var callbacks = 0;
    final config = _paddedConfig.copyWith(
      spacing: 6.5,
      showTitle: false,
      showValue: false,
      titleFormatter: (_) {
        callbacks++;
        return '';
      },
      localizedValueFormatter: (_, _) {
        callbacks++;
        return '';
      },
      linesBuilder: (_, _, _, _) {
        callbacks++;
        return const [];
      },
    );
    Widget measure(TreemapLabelConfig<String> config) => Builder(
      builder: (context) {
        final widgets = TreemapWidgetLabels<String>(
          config: config,
          parentLabels: const TreemapParentLabelConfig(),
          builder: (_, _, _) {
            callbacks++;
            return const SizedBox.shrink();
          },
        );
        // Parent visibility is independent of the disabled child text flags.
        expect(widgets.resolveParentHeaderHeight(context), 41.5);
        return const SizedBox.shrink();
      },
    );
    for (final direction in TextDirection.values) {
      // No Directionality ancestor: an explicit config direction is sufficient.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: measure(config.copyWith(textDirection: direction)),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpTreemapApp(measure(config), textDirection: direction);
    }
    expect(callbacks, 0);
  });

  testWidgets('shared widget typography invalidates only automatic geometry', (
    tester,
  ) async {
    final tiles = _CaptureTiles();
    var publications = 0;
    Future<TreemapGeometrySnapshot<String>> show(
      TreemapLabelConfig<String> config, {
      TreemapParentLabelConfig? parent = const TreemapParentLabelConfig(),
      double scale = 1,
    }) async {
      await tester.pumpTreemapApp(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 400,
            height: 240,
            child: TreemapChart<String>(
              tree: _tree,
              tiles: tiles,
              labels: TreemapWidgetLabels<String>(
                builder: _emptyLabel,
                config: config,
                parentLabels: parent,
              ),
              onPresentationChanged: (_) => setState(() => publications++),
            ),
          ),
        ),
        textScaler: TextScaler.linear(scale),
      );
      await tester.pumpAndSettle();
      return tiles.visual.presentation.targetSnapshot!;
    }

    final initial = await show(_paddedConfig);
    expect(initial.index[_parent]!.headerBounds!.height, 35);
    expect(publications, 1);
    final larger = _paddedConfig.copyWith(
      titleStyle: _title.copyWith(fontSize: 24, height: 1.5),
      valueStyle: _value.copyWith(fontSize: 12, height: 1.5),
      spacing: 6.5,
    );
    final resized = await show(larger);
    expect(resized, isNot(same(initial)));
    expect(resized.index[_parent]!.headerBounds!.height, 65.5);
    expect(publications, 2);
    final recolored = larger.copyWith(
      titleStyle: larger.titleStyle.copyWith(color: Colors.green),
      valueStyle: larger.valueStyle.copyWith(color: Colors.yellow),
    );
    expect(await show(recolored), same(resized));
    expect(publications, 2);
    tiles.visual.actions.hover(_parent);
    tiles.visual.actions.select(_parent);
    tiles.visual.actions.focus(_parent);
    await tester.pumpAndSettle();
    expect(tiles.visual.presentation.targetSnapshot, same(resized));
    expect(
      (await show(larger, scale: 2)).index[_parent]!.headerBounds!.height,
      119.5,
    );
    const fixed = TreemapParentLabelConfig(height: 56);
    final fixedTarget = await show(_paddedConfig, parent: fixed);
    expect(await show(larger, parent: fixed, scale: 2), same(fixedTarget));
    final disabled = await show(_paddedConfig, parent: null);
    expect(await show(larger, parent: null), same(disabled));
    expect(disabled.nodes.every((node) => node.headerBounds == null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canvas positions one gap for children and parent headers', (
    tester,
  ) async {
    for (final parent in [null, const TreemapParentLabelConfig()]) {
      for (final alignment in [
        Alignment.topLeft,
        Alignment.center,
        Alignment.bottomRight,
      ]) {
        final config = _config.copyWith(alignment: alignment);
        final ordinary = _paint(config: config, parent: parent);
        expect(ordinary, hasLength(2));
        for (final spacing in [.5, 6.0, 6.5]) {
          final spaced = _paint(
            config: config.copyWith(spacing: spacing),
            parent: parent,
          );
          final topShift = -spacing / 2 * (alignment.y + 1);
          expect(spaced, hasLength(2));
          expect(spaced.first.top - ordinary.first.top, topShift);
          expect(spaced.last.top - ordinary.last.top, topShift + spacing);
          expect(spaced.last.top - spaced.first.bottom, spacing);
          expect(spaced.first.left, ordinary.first.left);
          expect(spaced.last.left, ordinary.last.left);
        }
      }
    }
  });

  testWidgets('one visible or nonempty part never receives a gap', (
    tester,
  ) async {
    for (final config in [
      _config.copyWith(showTitle: false),
      _config.copyWith(showValue: false),
      _config.copyWith(titleFormatter: (_) => ''),
      _config.copyWith(valueFormatter: (_) => ''),
    ]) {
      final ordinary = _paint(config: config);
      final spaced = _paint(config: config.copyWith(spacing: 80));
      expect(ordinary, hasLength(1));
      expect(spaced, orderedEquals(ordinary));
    }
    for (final parent in [
      const TreemapParentLabelConfig(showTitle: false),
      const TreemapParentLabelConfig(showValue: false),
    ]) {
      final ordinary = _paint(parent: parent);
      final spaced = _paint(
        config: _config.copyWith(spacing: 80),
        parent: parent,
      );
      expect(ordinary, hasLength(1));
      expect(spaced, orderedEquals(ordinary));
    }
  });

  testWidgets(
    'spacing follows a wrapped title and counts toward vertical fit',
    (tester) async {
      final wrapped = _config.copyWith(
        maxLines: 3,
        titleFormatter: (_) => 'AA AA',
      );
      for (final parent in [
        null,
        const TreemapParentLabelConfig(height: 100),
      ]) {
        final ordinary = _paint(
          config: wrapped,
          parent: parent,
          size: const Size(60, 100),
        );
        final spaced = _paint(
          config: wrapped.copyWith(spacing: 6),
          parent: parent,
          size: const Size(60, 100),
        );
        expect(ordinary, hasLength(2));
        expect(spaced, hasLength(2));
        expect(ordinary.first.height, greaterThan(20));
        expect(spaced.first, ordinary.first);
        expect(spaced.last.top - ordinary.last.top, 6);
      }
      for (final parent in [null, const TreemapParentLabelConfig(height: 30)]) {
        final fits = _paint(parent: parent, size: const Size(100, 30));
        expect(fits, hasLength(2));
        final omitted = _paint(
          parent: parent,
          config: _config.copyWith(spacing: .5),
          size: const Size(100, 30),
        );
        expect(omitted, isEmpty);
        final exact = _paint(
          parent: parent,
          config: _config.copyWith(spacing: 6),
          size: const Size(100, 36),
        );
        expect(exact, hasLength(2));
      }
    },
  );

  testWidgets('custom canvas blocks ignore spacing', (tester) async {
    final custom = _config.copyWith(
      linesBuilder: (_, _, _, _) => const [
        TreemapCanvasLabelLine(text: 'AA', style: _title),
        TreemapCanvasLabelLine(text: '1', style: _value),
        TreemapCanvasLabelLine(text: '2', style: _value),
      ],
    );
    for (final parent in [null, const TreemapParentLabelConfig()]) {
      final ordinary = _paint(config: custom, parent: parent);
      final spaced = _paint(
        config: custom.copyWith(spacing: 80),
        parent: parent,
      );
      expect(ordinary, hasLength(3));
      expect(spaced, orderedEquals(ordinary));
    }
  });

  testWidgets(
    'automatic metrics add one unscaled gap without calling builders',
    (tester) async {
      var callbacks = 0;
      final config = _paddedConfig.copyWith(
        spacing: 6.5,
        titleFormatter: (_) {
          callbacks++;
          return '';
        },
      );

      Future<double?> measure(
        TreemapParentLabelConfig? parent, {
        double scale = 1,
        bool custom = false,
      }) async {
        double? height;
        await tester.pumpTreemapApp(
          Builder(
            builder: (context) {
              height = TreemapCanvasLabels<String>(
                parentLabels: parent,
                config: custom
                    ? config.copyWith(
                        linesBuilder: (_, _, _, _) {
                          callbacks++;
                          return const [];
                        },
                      )
                    : config,
              ).resolveParentHeaderHeight(context);
              return const SizedBox.shrink();
            },
          ),
          textScaler: TextScaler.linear(scale),
        );
        return height;
      }

      expect(await measure(const TreemapParentLabelConfig()), 41.5);
      expect(await measure(const TreemapParentLabelConfig(), scale: 2), 71.5);
      expect(
        await measure(const TreemapParentLabelConfig(showValue: false)),
        25,
      );
      expect(
        await measure(const TreemapParentLabelConfig(showTitle: false)),
        15,
      );
      expect(
        await measure(
          const TreemapParentLabelConfig(showTitle: false, showValue: false),
        ),
        isNull,
      );
      expect(await measure(null), isNull);
      expect(
        await measure(const TreemapParentLabelConfig(height: 40), scale: 2),
        40,
      );
      expect(await measure(const TreemapParentLabelConfig(), custom: true), 35);
      expect(callbacks, 0);
    },
  );

  testWidgets('spacing invalidates only automatic header geometry', (
    tester,
  ) async {
    final tiles = _CaptureTiles();

    Future<TreemapGeometrySnapshot<String>> show(
      double spacing,
      TreemapParentLabelConfig? parent,
    ) async {
      await tester.pumpTreemapApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 240,
            child: TreemapChart<String>(
              tree: _tree,
              tiles: tiles,
              labels: TreemapCanvasLabels<String>(
                parentLabels: parent,
                config: _paddedConfig.copyWith(spacing: spacing),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tiles.visual.presentation.targetSnapshot!;
    }

    const automatic = TreemapParentLabelConfig();
    final initial = await show(0, automatic);
    final spaced = await show(6, automatic);
    expect(spaced, isNot(same(initial)));
    expect(spaced.index[_parent]!.headerBounds!.height, 41);
    expect(spaced.index[_parent]!.bounds, initial.index[_parent]!.bounds);
    expect(await show(6, automatic), same(spaced));
    expect(
      (await show(6.5, automatic)).index[_parent]!.headerBounds!.height,
      41.5,
    );
    const fixed = TreemapParentLabelConfig(height: 50);
    final fixedTarget = await show(0, fixed);
    expect(await show(6, fixed), same(fixedTarget));
    final disabled = await show(0, null);
    expect(await show(6, null), same(disabled));
    expect(disabled.nodes.every((node) => node.headerBounds == null), isTrue);
  });

  testWidgets('widget spacers match their declared automatic header budget', (
    tester,
  ) async {
    final tiles = _CaptureTiles();
    for (final (scale, fixed, spacing, padding, expectedHeight) in [
      (1.0, null, 6.0, EdgeInsets.zero, 36.0),
      (1.0, null, 6.0, _padding, 41.0),
      (1.0, null, 6.5, _padding, 41.5),
      (2.0, null, 6.5, _padding, 71.5),
      (1.0, 56.0, 6.5, _padding, 56.0),
    ]) {
      final labelConfig = _config.copyWith(spacing: spacing, padding: padding);
      await tester.pumpTreemapApp(
        SizedBox(
          width: 400,
          height: 240,
          child: TreemapChart<String>(
            tree: _tree,
            tiles: tiles,
            labels: TreemapWidgetLabels<String>(
              config: labelConfig,
              parentLabels: TreemapParentLabelConfig(height: fixed),
              builder: (context, details, states) => Padding(
                padding: labelConfig.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title',
                      key: ValueKey('${details.key.sourceKey}-title'),
                      style: labelConfig.titleStyle,
                    ),
                    SizedBox(height: labelConfig.spacing),
                    Text(
                      'Value',
                      key: ValueKey('${details.key.sourceKey}-value'),
                      style: labelConfig.valueStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        textScaler: TextScaler.linear(scale),
      );
      await tester.pumpAndSettle();
      expect(
        tiles.visual.presentation.details[_parent]!.headerBounds!.height,
        expectedHeight,
      );
      for (final key in ['parent', 'child']) {
        final title = find.byKey(ValueKey('$key-title'));
        final value = find.byKey(ValueKey('$key-value'));
        final details =
            tiles.visual.presentation.details[TreemapKey.source(key)]!;
        final bounds = details.headerBounds ?? details.bounds;
        expect(tester.getTopLeft(title).dx - bounds.left, padding.left);
        expect(tester.getTopLeft(title).dy - bounds.top, padding.top);
        expect(
          tester.getTopLeft(value).dy - tester.getBottomLeft(title).dy,
          labelConfig.spacing,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
