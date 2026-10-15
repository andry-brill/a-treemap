import 'dart:ui' as ui;

import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

final _tree = TreemapNormalizer.normalize(
  TreemapNode<String>(
    key: 'root',
    children: [
      TreemapNode(
        key: 'parent',
        label: 'Parent',
        children: [
          TreemapNode(
            key: 'group',
            label: 'Group',
            children: [
              TreemapNode(key: 'a', label: 'Alpha', weight: 3),
              TreemapNode(key: 'b', label: 'Beta', weight: 1),
            ],
          ),
          TreemapNode(key: 'c', label: 'Gamma', weight: 2),
        ],
      ),
    ],
  ),
);
const _parent = TreemapKey.source('parent');
const _title = TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1);
const _value = TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1);
const _padding = EdgeInsets.fromLTRB(4, 2, 4, 3);

final class _CaptureTiles implements TreemapTileLayer<String> {
  _CaptureTiles({TreemapAppearanceResolver<String>? appearance})
    : appearance = appearance ?? testTreemapAppearance<String>();
  @override
  final TreemapAppearanceResolver<String> appearance;
  TreemapVisualContext<String>? visual;
  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    this.visual = visual;
    return const SizedBox.expand();
  }
}

final class _CustomLabels implements TreemapLabelLayer<String> {
  _CustomLabels([this.delegate]);

  final TreemapLabelLayer<String>? delegate;
  final List<String> phases = [];

  @override
  double? resolveParentHeaderHeight(BuildContext context) {
    phases.add('metrics');
    return delegate?.resolveParentHeaderHeight(context);
  }

  @override
  Widget build(BuildContext context, TreemapVisualContext<String> visual) {
    phases.add('render');
    return delegate?.build(context, visual) ?? const SizedBox.expand();
  }
}

Widget _label(
  BuildContext context,
  TreemapNodeDetails<String> details,
  Set<TreemapVisualState> states,
) => SizedBox.expand(
  key: ValueKey('label-${details.key.sourceKey}'),
  child: Text(details.label ?? '', maxLines: 1),
);

TreemapWidgetLabels<String> _widgets({
  TreemapParentLabelConfig? parents = const TreemapParentLabelConfig(),
  TreemapStatefulNodeWidgetBuilder<String>? parentBuilder,
  int? maximumNodes,
}) => TreemapWidgetLabels<String>(
  builder: _label,
  parentBuilder: parentBuilder,
  parentLabels: parents,
  config: const TreemapLabelConfig(
    titleStyle: _title,
    valueStyle: _value,
    padding: _padding,
  ),
  maximumNodes: maximumNodes,
);

Widget _chart(
  TreemapLabelLayer<String>? labels,
  _CaptureTiles tiles, {
  TreemapLayoutConfig<String> layout = const TreemapLayoutConfig(),
  ValueChanged<TreemapPresentationState<String>>? onChanged,
  TreemapTransitionSpec? transition,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: 400,
    height: 240,
    child: TreemapChart<String>(
      tree: _tree,
      tiles: tiles,
      labels: labels,
      layout: layout,
      onPresentationChanged: onChanged,
      transition: transition,
    ),
  ),
);

void main() {
  for (final delegate in [false, true]) {
    testWidgets(
      'custom label contract resolves ${delegate ? 'delegated' : 'null'} sizing before rendering',
      (tester) async {
        final tiles = _CaptureTiles();
        final labels = _CustomLabels(delegate ? _widgets() : null);
        for (final scale in [1.0, 2.0]) {
          labels.phases.clear();
          await tester.pumpTreemapApp(
            _chart(labels, tiles),
            textScaler: TextScaler.linear(scale),
          );
          await tester.pumpAndSettle();
          expect(labels.phases.first, 'metrics');
          expect(labels.phases, contains('render'));
          final header = tiles
              .visual!
              .presentation
              .targetSnapshot!
              .index[_parent]!
              .headerBounds;
          expect(header?.height, delegate ? 30 * scale + 5 : isNull);
          expect(
            find.byKey(const ValueKey('label-parent')),
            delegate ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'automatic metrics reserve one line per enabled part and padding',
    (tester) async {
      final tiles = _CaptureTiles();
      for (final entry in [
        (const TreemapParentLabelConfig(), 35.0),
        (const TreemapParentLabelConfig(showValue: false), 25.0),
        (const TreemapParentLabelConfig(showTitle: false), 15.0),
      ]) {
        await tester.pumpTreemapApp(_chart(_widgets(parents: entry.$1), tiles));
        await tester.pumpAndSettle();
        final state = tiles.visual!.presentation;
        expect(
          state.targetSnapshot!.index[_parent]!.headerBounds!.height,
          entry.$2,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('label-parent'))).height,
          entry.$2,
        );
        expect(
          state.visibleLeafNodes.map((node) => node.key.sourceKey),
          unorderedEquals(['a', 'b', 'c']),
        );
        expect(find.byKey(const ValueKey('label-parent')), findsOneWidget);
        expect(find.byKey(const ValueKey('label-group')), findsOneWidget);
      }
      await tester.pumpTreemapApp(
        _chart(_widgets(), tiles),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      expect(
        tiles
            .visual!
            .presentation
            .targetSnapshot!
            .index[_parent]!
            .headerBounds!
            .height,
        65,
      );
    },
  );

  testWidgets(
    'disabled headers preserve defaults and depth boundaries use leaf labels',
    (tester) async {
      final tiles = _CaptureTiles();
      for (final parents in [
        null,
        const TreemapParentLabelConfig(
          showTitle: false,
          showValue: false,
          height: 80,
        ),
      ]) {
        await tester.pumpTreemapApp(_chart(_widgets(parents: parents), tiles));
        await tester.pumpAndSettle();
        expect(
          tiles
              .visual!
              .presentation
              .targetSnapshot!
              .index[_parent]!
              .headerBounds,
          isNull,
        );
        expect(find.byKey(const ValueKey('label-parent')), findsNothing);
      }
      await tester.pumpTreemapApp(
        _chart(
          _widgets(),
          tiles,
          layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('label-parent')), findsOneWidget);
      expect(tiles.visual!.presentation.details[_parent]!.headerBounds, isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('label-parent'))).height,
        240,
      );
    },
  );

  testWidgets(
    'fixed custom headers use a separate builder and retain clipping',
    (tester) async {
      final tiles = _CaptureTiles();
      await tester.pumpTreemapApp(
        _chart(
          _widgets(
            parents: const TreemapParentLabelConfig(height: 56),
            parentBuilder: (context, details, states) => SizedBox.expand(
              key: ValueKey('header-${details.key.sourceKey}'),
              child: const Icon(Icons.folder),
            ),
          ),
          tiles,
        ),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('header-parent'))).height,
        56,
      );
      expect(find.byKey(const ValueKey('label-parent')), findsNothing);
      expect(find.byKey(const ValueKey('label-a')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('header-parent')),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
      expect(tiles.visual!.presentation.details[_parent]!.bounds.height, 240);
    },
  );

  testWidgets(
    'space exhaustion renders the parent once and preserves activation',
    (tester) async {
      final tiles = _CaptureTiles();
      await tester.pumpTreemapApp(
        _chart(
          _widgets(parents: const TreemapParentLabelConfig(height: 500)),
          tiles,
        ),
      );
      await tester.pumpAndSettle();
      final state = tiles.visual!.presentation;
      expect(state.targetSnapshot!.nodes, hasLength(1));
      expect(state.visibleLeafNodes.single.key, _parent);
      expect(find.byKey(const ValueKey('label-parent')), findsOneWidget);
      expect(find.byKey(const ValueKey('label-a')), findsNothing);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('label-parent'))),
      );
      await tester.pumpAndSettle();
      expect(tiles.visual!.presentation.focusKey, _parent);
      expect(
        tiles.visual!.presentation.targetSnapshot!.index,
        contains(const TreemapKey.source('group')),
      );
      expect(
        tiles.visual!.presentation.targetSnapshot!.index,
        isNot(contains(_parent)),
      );
    },
  );

  testWidgets(
    'header hit testing, culling and zero height use reserved regions',
    (tester) async {
      final tiles = _CaptureTiles();
      await tester.pumpTreemapApp(_chart(_widgets(maximumNodes: 2), tiles));
      await tester.pumpAndSettle();
      final snapshot = tiles.visual!.presentation.targetSnapshot!;
      expect(snapshot.hitTest(10, 5)!.key, _parent);
      expect(find.byType(ClipRect), findsNWidgets(2));
      expect(snapshot.index[_parent]!.headerBounds!.height, 35);
      await tester.pumpTreemapApp(
        _chart(
          _widgets(parents: const TreemapParentLabelConfig(height: 0)),
          tiles,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('label-parent')), findsNothing);
      expect(find.byKey(const ValueKey('label-a')), findsOneWidget);
      expect(
        tiles.visual!.presentation.details[_parent]!.headerBounds!.height,
        0,
      );
    },
  );

  testWidgets(
    'normal style metrics are input-only and state changes keep geometry stable',
    (tester) async {
      var nodeStyles = 0;
      var formatters = 0;
      final appearance = testTreemapAppearance<String>(
        nodeStyleResolver: (context, details, states) {
          nodeStyles++;
          return null;
        },
      );
      final tiles = _CaptureTiles(appearance: appearance);
      final labels = TreemapCanvasLabels<String>(
        parentLabels: const TreemapParentLabelConfig(),
        config: TreemapLabelConfig(
          titleStyle: _title,
          valueStyle: _value,
          hoverStyle: const TreemapLabelStyle(
            titleStyle: TextStyle(fontSize: 90),
          ),
          selectedStyle: const TreemapLabelStyle(
            valueStyle: TextStyle(fontSize: 80),
          ),
          nodeStyleResolver: (context, details, states) {
            nodeStyles++;
            return null;
          },
          padding: _padding,
          spacing: 6,
          maxLines: 4,
          titleFormatter: (details) {
            formatters++;
            return details.label ?? '';
          },
        ),
      );
      await tester.pumpTreemapApp(
        Builder(
          builder: (context) {
            expect(labels.resolveParentHeaderHeight(context), 41);
            expect(nodeStyles, 0);
            expect(formatters, 0);
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpTreemapApp(_chart(labels, tiles));
      await tester.pumpAndSettle();
      final target = tiles.visual!.presentation.targetSnapshot;
      tiles.visual!.actions.hover(_parent);
      tiles.visual!.actions.select(_parent);
      tiles.visual!.actions.focus(_parent);
      await tester.pumpAndSettle();
      expect(tiles.visual!.presentation.targetSnapshot, same(target));
      expect(target!.index[_parent]!.headerBounds!.height, 41);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RTL/localized labels and input updates settle without feedback',
    (tester) async {
      final tiles = _CaptureTiles();
      var publications = 0;
      await tester.pumpTreemapApp(
        StatefulBuilder(
          builder: (context, setState) {
            return _chart(
              TreemapCanvasLabels<String>(
                parentLabels: const TreemapParentLabelConfig(),
                config: TreemapLabelConfig(
                  padding: _padding,
                  titleStyle: _title,
                  valueStyle: _value,
                  localizedValueFormatter: (details, locale) =>
                      '${locale.languageCode}:${details.weight}',
                ),
              ),
              tiles,
              onChanged: (_) => setState(() => publications++),
            );
          },
        ),
        locale: const Locale('en'),
        textDirection: TextDirection.rtl,
      );
      await tester.pumpAndSettle();
      expect(publications, 1);
      final first = tiles.visual!.presentation.targetSnapshot!;
      expect(first.index[_parent]!.headerBounds!.top, 0);
      await tester.pumpTreemapApp(
        _chart(
          TreemapCanvasLabels<String>(
            parentLabels: const TreemapParentLabelConfig(),
            config: const TreemapLabelConfig(
              padding: _padding,
              titleStyle: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 30,
                height: 1,
              ),
              valueStyle: _value,
            ),
          ),
          tiles,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tiles
            .visual!
            .presentation
            .targetSnapshot!
            .index[_parent]!
            .headerBounds!
            .height,
        45,
      );
    },
  );

  testWidgets('hiding descendants reconciles transient targets', (
    tester,
  ) async {
    final tiles = _CaptureTiles();
    await tester.pumpTreemapApp(_chart(_widgets(), tiles));
    await tester.pumpAndSettle();
    const child = TreemapKey.source('a');
    tiles.visual!.actions.hover(child);
    tiles.visual!.actions.focus(child);
    await tester.pumpAndSettle();
    await tester.pumpTreemapApp(
      _chart(
        _widgets(parents: const TreemapParentLabelConfig(height: 500)),
        tiles,
      ),
    );
    await tester.pumpAndSettle();
    expect(tiles.visual!.presentation.hoveredKey, isNull);
    expect(tiles.visual!.presentation.keyboardFocusedKey, isNull);
  });

  testWidgets('header geometry animates once and respects reduced motion', (
    tester,
  ) async {
    final tiles = _CaptureTiles();
    Widget host(double height, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: _chart(
        _widgets(parents: TreemapParentLabelConfig(height: height)),
        tiles,
        transition: const TreemapTransitionSpec(
          duration: Duration(milliseconds: 300),
          curve: Curves.linear,
        ),
      ),
    );
    await tester.pumpTreemapApp(host(20));
    await tester.pumpAndSettle();
    await tester.pumpTreemapApp(host(80));
    await tester.pump(const Duration(milliseconds: 150));
    final frame = tiles.visual!.presentation;
    expect(frame.isAnimating, isTrue);
    expect(frame.targetSnapshot!.index[_parent]!.headerBounds!.height, 80);
    expect(
      frame.displayedSnapshot!.index[_parent]!.headerBounds!.height,
      closeTo(50, .1),
    );
    expect(find.byKey(const ValueKey('label-parent')), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpTreemapApp(host(30, reduced: true));
    await tester.pump();
    expect(tiles.visual!.presentation.isAnimating, isFalse);
    expect(
      tiles
          .visual!
          .presentation
          .displayedSnapshot!
          .index[_parent]!
          .headerBounds!
          .height,
      30,
    );
  });

  testWidgets(
    'resolved height updates the cache and disabling headers reclaims space',
    (tester) async {
      final tiles = _CaptureTiles();
      const layout = TreemapLayoutConfig<String>(
        levelPadding: TreemapInsets.all(4),
      );
      Future<TreemapGeometrySnapshot<String>> show(
        TreemapParentLabelConfig? parents,
      ) async {
        await tester.pumpTreemapApp(
          _chart(_widgets(parents: parents), tiles, layout: layout),
        );
        await tester.pumpAndSettle();
        return tiles.visual!.presentation.targetSnapshot!;
      }

      final ordinary = await show(null);
      TreemapGeometrySnapshot<String> previous = ordinary;
      for (final parents in [
        const TreemapParentLabelConfig(height: 80),
        const TreemapParentLabelConfig(height: 56),
        const TreemapParentLabelConfig(),
      ]) {
        final snapshot = await show(parents);
        expect(snapshot, isNot(same(previous)));
        expect(
          snapshot.index[_parent]!.headerBounds!.height,
          parents.height ?? 35,
        );
        expect(
          snapshot.index[_parent]!.bounds,
          ordinary.index[_parent]!.bounds,
        );
        expect(await show(parents), same(snapshot));
        previous = snapshot;
      }

      for (final parents in [
        null,
        const TreemapParentLabelConfig(
          showTitle: false,
          showValue: false,
          height: 80,
        ),
      ]) {
        await show(const TreemapParentLabelConfig(height: 56));
        final disabled = await show(parents);
        expect(disabled.index.keys, orderedEquals(ordinary.index.keys));
        for (final node in disabled.nodes) {
          expect(node.headerBounds, isNull);
          expect(node.bounds, ordinary.index[node.key]!.bounds);
        }
        expect(find.byKey(const ValueKey('label-parent')), findsNothing);
      }
      expect(
        layout,
        const TreemapLayoutConfig<String>(levelPadding: TreemapInsets.all(4)),
      );
    },
  );

  testWidgets('canvas omits a whole header block when vertically constrained', (
    tester,
  ) async {
    Future<bool> hasPixels({
      required double height,
      required bool showTitle,
      required bool showValue,
      int maxLines = 1,
      double? explicitHeight,
      double top = 0,
    }) async {
      final geometry = TreemapGeometryNode<String>(
        key: _parent,
        bounds: TreemapBounds.fromLTWH(0, top, 100, 100),
        headerBounds: TreemapBounds.fromLTWH(0, top, 100, height),
        weight: 6,
        depth: 1,
        kind: TreemapGeometryKind.source,
        label: 'A long parent title',
        parentKey: null,
        opacity: 1,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(0, -top);
      TreemapCanvasLabelPainter<String>(
        nodes: [geometry],
        details: {_parent: TreemapNodeDetails(geometry: geometry, path: [])},
        appearances: {_parent: const TreemapAppearance(color: Colors.black)},
        styles: {
          _parent: TreemapLabelStyle(
            titleStyle: _title.copyWith(color: Colors.white),
            valueStyle: _value.copyWith(color: Colors.white),
          ),
        },
        config: TreemapLabelConfig(
          titleStyle: _title.copyWith(color: Colors.white),
          valueStyle: _value.copyWith(color: Colors.white),
          maxLines: maxLines,
        ),
        parentLabels: TreemapParentLabelConfig(
          showTitle: showTitle,
          showValue: showValue,
          height: explicitHeight,
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        locale: null,
        textCache: TreemapTextLayoutCache(),
      ).paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      final result = await tester.runAsync(() async {
        final image = await picture.toImage(100, 100);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        final visible = bytes.any((value) => value != 0);
        image.dispose();
        return visible;
      });
      picture.dispose();
      return result!;
    }

    expect(
      await hasPixels(height: 29, showTitle: true, showValue: true),
      isFalse,
    );
    expect(
      await hasPixels(
        height: 30,
        showTitle: true,
        showValue: true,
        maxLines: 4,
      ),
      isTrue,
    );
    expect(
      await hasPixels(height: 20, showTitle: true, showValue: false),
      isTrue,
    );
    expect(
      await hasPixels(height: 10, showTitle: false, showValue: true),
      isTrue,
    );
    expect(
      await hasPixels(
        height: 30,
        showTitle: true,
        showValue: true,
        top: 44 / 17,
      ),
      isTrue,
      reason: 'Fractional placement must not hide an exactly fitting header.',
    );
    expect(
      await hasPixels(
        height: 30,
        showTitle: true,
        showValue: true,
        maxLines: 4,
        explicitHeight: 30,
      ),
      isFalse,
    );
  });
}
