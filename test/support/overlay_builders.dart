import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/widgets.dart';

const _style = TextStyle(fontSize: 14, color: Color(0xFF202020));

Widget testLegendTitle(BuildContext context, String title) =>
    Text(title, style: _style);

Widget testLegendLabel(BuildContext context, TreemapLegendEntry entry) =>
    Text(entry.label, style: _style);

Widget testLegendPointer(BuildContext context, Color color, double fraction) =>
    TreemapLegendPointer(color: color);

Widget testBreadcrumbItem(
  BuildContext context,
  TreemapPathEntry<Object?> entry,
  bool isCurrent,
  VoidCallback? onPressed,
) => GestureDetector(
  onTap: onPressed,
  child: Text(
    entry.label ?? entry.key.sourceKey?.toString() ?? 'Other',
    style: _style,
  ),
);
