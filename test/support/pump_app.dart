import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final testTreemapColorScale = TreemapColorScale.categorical(const [
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFF7B1FA2),
  Color(0xFFF57C00),
  Color(0xFF0288D1),
  Color(0xFFC2185B),
], fallback: const Color(0xFF757575));

const _testPalette = <Color>[
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFF7B1FA2),
  Color(0xFFF57C00),
  Color(0xFF0288D1),
  Color(0xFFC2185B),
];

TreemapAppearance _stableKeyAppearance<K>(
  BuildContext context,
  TreemapNodeDetails<K> details,
  Set<TreemapVisualState> states,
) {
  final value = details.key.isSource
      ? details.key.sourceKey.toString()
      : details.key.aggregateParent.toString();
  var stableHash = 0;
  for (final rune in value.runes) {
    stableHash = ((stableHash * 31) + rune) & 0x7fffffff;
  }
  return TreemapAppearance(
    color: _testPalette[stableHash % _testPalette.length],
  );
}

TreemapNodeStyleResolver<K> _testStyleResolver<K>(
  TreemapNodeStyleResolver<K>? resolver,
) =>
    (context, details, states) => _stableKeyAppearance(
      context,
      details,
      states,
    ).merge(resolver?.call(context, details, states));

TreemapAppearanceResolver<K> testTreemapAppearance<K>({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<K>? nodeStyleResolver,
}) => TreemapAppearanceResolver<K>(
  colorScale: colorScale ?? testTreemapColorScale,
  style: style,
  nodeStyleResolver: colorScale == null
      ? _testStyleResolver(nodeStyleResolver)
      : nodeStyleResolver,
);

TreemapTiles<K> testTreemapTiles<K>({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<K>? nodeStyleResolver,
}) => TreemapTiles(
  appearance: testTreemapAppearance(
    colorScale: colorScale,
    style: style,
    nodeStyleResolver: nodeStyleResolver,
  ),
);

TreemapCanvasLabels<K> testTreemapLabels<K>({
  TreemapColorScale? colorScale,
  TreemapStyle? style,
  TreemapNodeStyleResolver<K>? nodeStyleResolver,
  TreemapLabelConfig<K> config = const TreemapLabelConfig(),
}) => TreemapCanvasLabels(
  appearance: testTreemapAppearance(
    colorScale: colorScale,
    style: style,
    nodeStyleResolver: nodeStyleResolver,
  ),
  config: config,
);

extension TreemapWidgetTester on WidgetTester {
  Future<void> pumpTreemapApp(
    Widget child, {
    Size surfaceSize = const Size(800, 600),
    ThemeData? theme,
    ThemeData? darkTheme,
    Locale locale = const Locale('en'),
    TextDirection textDirection = TextDirection.ltr,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await binding.setSurfaceSize(surfaceSize);
    addTearDown(() => binding.setSurfaceSize(null));
    await pumpWidget(
      MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        locale: locale,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Directionality(textDirection: textDirection, child: child),
        ),
      ),
    );
  }
}
