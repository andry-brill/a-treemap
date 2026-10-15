import 'package:any_treemap/any_treemap.dart';
import 'package:any_treemap/src/painters/canvas_label_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const _title = TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1);
const _value = TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1);
const _base = TreemapLabelConfig<String>(
  titleStyle: _title,
  valueStyle: _value,
  padding: EdgeInsets.all(2),
  spacing: 1.5,
);
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
final _details = TreemapPresentationState.fromData(
  tree: _tree,
  targetSnapshot: TreemapLayoutEngine<String>().layout(
    tree: _tree,
    viewport: const TreemapBounds.fromLTWH(0, 0, 400, 300),
  ),
).details[_parent]!;

final class _Tiles implements TreemapTileLayer<String> {
  _Tiles({TreemapAppearanceResolver<String>? appearance})
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

void main() {
  test('defaults, equality, hashing and nullable override resets', () {
    const defaults = TreemapLabelConfig<String>();
    expect(
      defaults.titleStyle,
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
    expect(defaults.valueStyle, const TextStyle(fontSize: 11));
    expect(defaults.padding, EdgeInsets.zero);
    expect(defaults.spacing, 0);
    expect(defaults.hoverStyle, isNull);
    expect(defaults.selectedStyle, isNull);
    expect(defaults.focusedStyle, isNull);
    expect(defaults.nodeStyleResolver, isNull);
    const style = TreemapLabelStyle(titleStyle: _title, valueStyle: _value);
    expect(style.copyWith(), style);
    expect(style.copyWith().hashCode, style.hashCode);
    expect(
      style.copyWith(titleStyle: null),
      const TreemapLabelStyle(valueStyle: _value),
    );
    expect(
      style.copyWith(valueStyle: null),
      const TreemapLabelStyle(titleStyle: _title),
    );
    expect(
      style.copyWith(titleStyle: null, valueStyle: null),
      const TreemapLabelStyle(),
    );
    final changed = defaults.copyWith(
      hoverStyle: style,
      selectedStyle: style,
      focusedStyle: style,
      nodeStyleResolver: (_, _, _) => style,
    );
    expect(changed.copyWith(), changed);
    expect(changed.copyWith().hashCode, changed.hashCode);
    for (final cleared in [
      changed.copyWith(hoverStyle: null),
      changed.copyWith(selectedStyle: null),
      changed.copyWith(focusedStyle: null),
      changed.copyWith(nodeStyleResolver: null),
    ]) {
      expect(cleared, isNot(changed));
      expect(cleared.hashCode, isNot(changed.hashCode));
    }
    expect(
      changed.copyWith(
        hoverStyle: null,
        selectedStyle: null,
        focusedStyle: null,
        nodeStyleResolver: null,
      ),
      defaults,
    );
  });

  testWidgets(
    'combined state precedence, partial overrides and whole-style replacement',
    (tester) async {
      const hover = TextStyle(fontSize: 18);
      const selected = TextStyle(color: Colors.red);
      const focused = TextStyle(fontSize: 17);
      const finalValue = TextStyle(fontSize: 8);
      var calls = 0;
      await tester.pumpTreemapApp(
        Builder(
          builder: (context) {
            final config = _base.copyWith(
              hoverStyle: const TreemapLabelStyle(titleStyle: hover),
              selectedStyle: const TreemapLabelStyle(
                titleStyle: selected,
                valueStyle: selected,
              ),
              focusedStyle: const TreemapLabelStyle(titleStyle: focused),
              nodeStyleResolver: (receivedContext, details, states) {
                expect(receivedContext, same(context));
                expect(details, same(_details));
                calls++;
                return states.contains(TreemapVisualState.disabled)
                    ? const TreemapLabelStyle(valueStyle: finalValue)
                    : null;
              },
            );
            expect(
              config.resolveStyles(context, _details, {}),
              const TreemapLabelStyle(titleStyle: _title, valueStyle: _value),
            );
            expect(
              config.resolveStyles(context, _details, {
                TreemapVisualState.hovered,
              }),
              const TreemapLabelStyle(titleStyle: hover, valueStyle: _value),
            );
            final combined = {
              TreemapVisualState.hovered,
              TreemapVisualState.selected,
            };
            expect(
              config.resolveStyles(context, _details, combined),
              const TreemapLabelStyle(
                titleStyle: selected,
                valueStyle: selected,
              ),
            );
            combined.add(TreemapVisualState.focused);
            expect(
              config.resolveStyles(context, _details, combined),
              const TreemapLabelStyle(
                titleStyle: focused,
                valueStyle: selected,
              ),
            );
            combined.add(TreemapVisualState.disabled);
            final resolved = config.resolveStyles(context, _details, combined);
            expect(
              resolved,
              const TreemapLabelStyle(
                titleStyle: focused,
                valueStyle: finalValue,
              ),
            );
            expect(resolved.titleStyle!.fontFamily, isNull);
            expect(resolved.titleStyle!.height, isNull);
            expect(calls, 5);
            return const SizedBox();
          },
        ),
      );
    },
  );

  test(
    'standard colors preserve final explicit color and foreground paint',
    () {
      final foreground = Paint()..color = Colors.green;
      final styles = TreemapLabelStyle(
        titleStyle: _title.copyWith(color: Colors.red),
        valueStyle: _value.copyWith(foreground: foreground),
      );
      final lines = _base.resolveLines(
        _details,
        const TreemapAppearance(color: Colors.black),
        null,
        styles: styles,
      );
      expect(lines.first.style.color, Colors.red);
      expect(lines.last.style.foreground, same(foreground));
      final fallback = _base.resolveLines(
        _details,
        const TreemapAppearance(color: Colors.black),
        null,
        styles: const TreemapLabelStyle(titleStyle: _title, valueStyle: _value),
      );
      expect(
        fallback.first.style.color,
        treemapContrastingTextColor(Colors.black),
      );
      expect(
        fallback.last.style.color,
        fallback.first.style.color!.withValues(alpha: .82),
      );
    },
  );

  test('custom lines receive styles and keep control of color and output', () {
    const styles = TreemapLabelStyle(titleStyle: _title, valueStyle: _value);
    final config = _base.copyWith(
      colorResolver: (_) => throw StateError('Custom output bypasses fallback'),
      linesBuilder: (details, appearance, locale, receivedStyles) {
        expect(details, same(_details));
        expect(appearance.color, Colors.black);
        expect(locale, const Locale('de'));
        expect(receivedStyles, same(styles));
        return [
          TreemapCanvasLabelLine(
            text: 'Custom',
            style: receivedStyles.titleStyle!,
          ),
        ];
      },
    );
    final lines = config.resolveLines(
      _details,
      const TreemapAppearance(color: Colors.black),
      const Locale('de'),
      styles: styles,
    );
    expect(lines.single.style, _title);
    expect(lines.single.text, 'Custom');
  });

  for (final widgets in [false, true]) {
    testWidgets(
      '${widgets ? "widget" : "canvas"} overrides repaint without geometry or measurement feedback',
      (tester) async {
        final tiles = _Tiles();

        var resolvingMetrics = false;
        var resolverCalls = 0;
        var publications = 0;
        final seen = <TreemapKey<String>, TreemapLabelStyle>{};
        var config = _base.copyWith(
          hoverStyle: const TreemapLabelStyle(
            titleStyle: TextStyle(fontSize: 18),
          ),
          selectedStyle: const TreemapLabelStyle(
            valueStyle: TextStyle(fontSize: 9),
          ),
          focusedStyle: const TreemapLabelStyle(
            titleStyle: TextStyle(fontSize: 17),
          ),
          nodeStyleResolver: (context, details, states) {
            expect(resolvingMetrics, isFalse);
            resolverCalls++;
            if (details.key != _parent) return null;
            return TreemapLabelStyle(
              valueStyle: _value.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            );
          },
          titleFormatter: (details) {
            expect(resolvingMetrics, isFalse);
            return details.label!;
          },
        );
        var parents = const TreemapParentLabelConfig();
        var scale = TextScaler.noScaling;
        Future<void> show({Color color = Colors.red}) async {
          await tester.pumpTreemapApp(
            Builder(
              builder: (context) {
                final TreemapLabelLayer<String> labels = widgets
                    ? TreemapWidgetLabels<String>(
                        config: config,
                        parentLabels: parents,
                        builder: (context, details, states) {
                          expect(resolvingMetrics, isFalse);
                          final styles = config.resolveStyles(
                            context,
                            details,
                            states,
                          );
                          seen[details.key] = styles;
                          return Text(
                            details.label!,
                            style: styles.titleStyle,
                            maxLines: 1,
                          );
                        },
                      )
                    : TreemapCanvasLabels<String>(
                        config: config,
                        parentLabels: parents,
                      );
                final before = resolverCalls;
                resolvingMetrics = true;
                labels.resolveParentHeaderHeight(context);
                resolvingMetrics = false;
                expect(resolverCalls, before);
                return SizedBox(
                  width: 400,
                  height: 300,
                  child: TreemapChart<String>(
                    tree: _tree,
                    tiles: tiles,
                    labels: labels,
                    onPresentationChanged: (_) {
                      publications++;
                    },
                  ),
                );
              },
            ),
            theme: ThemeData(primaryColor: color),
            textScaler: scale,
            textDirection: TextDirection.rtl,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        TreemapLabelStyle rendered() {
          if (widgets) return seen[_parent]!;
          final painter = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.painter)
              .whereType<TreemapCanvasLabelPainter<String>>()
              .single;
          expect(() => painter.styles.clear(), throwsUnsupportedError);
          return painter.styles[_parent]!;
        }

        await show();
        final target = tiles.visual.presentation.targetSnapshot;
        expect(target!.index[_parent]!.headerBounds!.height, 35.5);
        tiles.visual.actions.hover(_parent);
        tiles.visual.actions.select(_parent);
        tiles.visual.actions.focus(_parent);
        await tester.pumpAndSettle();
        expect(tiles.visual.presentation.targetSnapshot, same(target));
        expect(rendered().titleStyle!.fontSize, 17);
        expect(rendered().valueStyle!.color, Colors.red);
        await show(color: Colors.green);
        expect(rendered().valueStyle!.color, Colors.green);
        expect(tiles.visual.presentation.targetSnapshot, same(target));
        config = config.copyWith(
          nodeStyleResolver: (_, _, _) =>
              const TreemapLabelStyle(titleStyle: TextStyle(fontSize: 90)),
        );
        await show();
        expect(rendered().titleStyle!.fontSize, 90);
        expect(tiles.visual.presentation.targetSnapshot, same(target));
        config = config.copyWith(
          nodeStyleResolver: null,
          titleStyle: _title.copyWith(fontSize: 24),
        );
        await show();
        expect(
          tiles
              .visual
              .presentation
              .targetSnapshot!
              .index[_parent]!
              .headerBounds!
              .height,
          39.5,
        );
        scale = TextScaler.linear(2);
        await show();
        expect(
          tiles
              .visual
              .presentation
              .targetSnapshot!
              .index[_parent]!
              .headerBounds!
              .height,
          73.5,
        );
        parents = const TreemapParentLabelConfig(height: 56);
        await show();
        final fixed = tiles.visual.presentation.targetSnapshot;
        config = config.copyWith(titleStyle: _title);
        scale = TextScaler.noScaling;
        await show();
        expect(tiles.visual.presentation.targetSnapshot, same(fixed));
        parents = const TreemapParentLabelConfig(
          showTitle: false,
          showValue: false,
        );
        await show();
        expect(
          tiles
              .visual
              .presentation
              .targetSnapshot!
              .index[_parent]!
              .headerBounds,
          isNull,
        );
        final settled = publications;
        await tester.pump(const Duration(seconds: 1));
        expect(publications, settled);
      },
    );
  }
}
