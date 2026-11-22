# Copyable presentation recipes

The core `any_treemap` package uses only design-neutral Flutter APIs. These are
application-owned examples, not exported package APIs:

- [material.dart](material.dart): Material breadcrumb buttons, legend typography,
  pointer colors and a themed tooltip shell. Add `material_ui: ^1.11.1` to your
  application's dependencies.
- [cupertino.dart](cupertino.dart): Cupertino buttons, dynamic colors, legend
  typography and a themed tooltip shell. Add `cupertino_ui: ^1.1.7` and
  `cupertino_icons: ^1.0.8` (for Cupertino's icon font) instead.
- [custom.dart](custom.dart): equivalent builders using only Flutter widgets,
  including explicit keyboard activation, focus indication and semantics.

All examples require Dart 3.13+ / Flutter 3.47+ and `any_treemap: ^5.0.0`.
Copy the chosen recipe file into your application's `lib/recipes/` directory.
You can customize any builder individually; no interface or global registration
is required. Supply the correct app/theme ancestors for the chosen design system.

## Shared chart

Create `lib/recipe_chart.dart` with the following complete chart. It uses only
core APIs and can be shared by any of the three entry points below.

```dart
import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/widgets.dart';

final tree = TreemapNormalizer.normalize(TreemapNode<String>(
  key: 'root', label: 'Root', children: [
    TreemapNode(key: 'group', label: 'Group', children: [
      TreemapNode(key: 'a', label: 'A', weight: 70),
      TreemapNode(key: 'b', label: 'B', weight: 30),
    ]),
    TreemapNode(key: 'c', label: 'C', weight: 25),
  ],
));
final scale = TreemapColorScale.interpolated(
  minimum: 0, maximum: 100,
  colors: const [Color(0xFF4466AA), Color(0xFFAACCEE)],
  fallback: const Color(0xFF808080),
);

Widget recipeChart({
  required TreemapBreadcrumbItemBuilder<String> breadcrumb,
  required TreemapLegendTitleBuilder title,
  required TreemapLegendLabelBuilder label,
  required TreemapLegendPointerBuilder pointer,
  required TreemapTooltipContainerBuilder tooltip,
}) => TreemapChart<String>(
  tree: tree,
  layout: const TreemapLayoutConfig(maxVisibleDepth: 1),
  tiles: TreemapTiles(appearance: TreemapAppearanceResolver(colorScale: scale)),
  labels: TreemapCanvasLabels(),
  surrounding: TreemapSurroundingGrid<String>(
    topCenter: TreemapBreadcrumbs(config: TreemapBreadcrumbsConfig(
      itemBuilder: breadcrumb,
    )),
    bottomCenter: TreemapLegend(scale: scale, config: TreemapLegendConfig.bar(
      titleBuilder: title, labelBuilder: label, pointerBuilder: pointer,
    )),
  ),
  tooltip: TreemapTooltip(
    config: TreemapTooltipConfig(containerBuilder: tooltip),
    builder: (context, details) => Text('${details.label}: ${details.weight}'),
  ),
);
```

For a discrete legend, replace `.bar(...)` with `.discrete(titleBuilder: title,
labelBuilder: label)`. Keep the builders even when hiding a title or labels;
`copyWith` retains them. A pointer builder may return `SizedBox.shrink()` if the
application does not want a marker.

## Material main.dart

```dart
import 'package:material_ui/material_ui.dart';
import 'recipe_chart.dart';
import 'recipes/material.dart';

void main() => runApp(MaterialApp(
  theme: ThemeData.light(), darkTheme: ThemeData.dark(),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SafeArea(child: recipeChart(
    breadcrumb: materialTreemapBreadcrumb,
    title: materialTreemapLegendTitle,
    label: materialTreemapLegendLabel,
    pointer: materialTreemapLegendPointer,
    tooltip: materialTreemapTooltip,
  ))),
));
```

`MaterialTreemapBreadcrumbItem` retains indicator duration, curve, colors,
typography and the optional `material_ui.ButtonStyle`. Current items cannot be
activated. Reduced motion disables indicator animation.

## Cupertino main.dart

```dart
import 'package:cupertino_ui/cupertino_ui.dart';
import 'recipe_chart.dart';
import 'recipes/cupertino.dart';

void main() => runApp(CupertinoApp(
  localizationsDelegates: GlobalCupertinoLocalizations.delegates,
  home: CupertinoPageScaffold(child: SafeArea(child: recipeChart(
    breadcrumb: cupertinoTreemapBreadcrumb,
    title: cupertinoTreemapLegendTitle,
    label: cupertinoTreemapLegendLabel,
    pointer: cupertinoTreemapLegendPointer,
    tooltip: cupertinoTreemapTooltip,
  ))),
));
```

`CupertinoTreemapBreadcrumbItem` exposes the same neutral indicator and label
settings, using `CupertinoButton` rather than a Material button style. Dynamic
colors resolve from the current context; theme changes do not reset navigation.

## Custom WidgetsApp main.dart

```dart
import 'package:flutter/widgets.dart';
import 'recipe_chart.dart';
import 'recipes/custom.dart';

void main() => runApp(WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, child) => FocusScope(
    autofocus: true,
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 14, color: Color(0xFF202020)),
      child: SafeArea(child: recipeChart(
        breadcrumb: customTreemapBreadcrumb,
        title: customTreemapLegendTitle,
        label: customTreemapLegendLabel,
        pointer: customTreemapLegendPointer,
        tooltip: customTreemapTooltip,
      )),
    ),
  ),
));
```

The focus scope is useful when using `WidgetsApp.builder` without a navigator.
The custom button supports Tab traversal, Enter/Space activation, pointer clicks,
visible keyboard focus and a single accessibility label. Customize its explicit
decoration and inherited text style to implement your own design language.

## Runnable catalog

Select `appearance-material-recipe`, `appearance-cupertino-recipe`, or
`appearance-custom-recipe` in the playground. The recipe selector is serialized
as `presentation.recipe`. Change legend kind, brightness, text scale, RTL and
reduced motion to compare behavior. Source files above are independent of the
playground; copy them rather than importing example-package internals.
