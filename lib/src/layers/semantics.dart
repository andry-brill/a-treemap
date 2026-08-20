import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../painters/semantics_painter.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Adds an accessibility representation for canvas-rendered treemap nodes.
///
/// Each visible node is exposed to assistive technologies with a label, value,
/// hierarchy hint, interaction state, and activation actions. The resolvers
/// allow applications to customize or localize the spoken text.
final class TreemapSemantics<K> implements TreemapSemanticsLayer<K> {
  const TreemapSemantics({
    this.labelResolver,
    this.valueResolver,
    this.hintResolver,
  });

  final String Function(TreemapNodeDetails<K> details)? labelResolver;
  final String Function(TreemapNodeDetails<K> details)? valueResolver;
  final String Function(TreemapNodeDetails<K> details)? hintResolver;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      CustomPaint(
        painter: TreemapSemanticsPainter<K>(
          visual: visual,
          labelResolver: labelResolver,
          valueResolver: valueResolver,
          hintResolver: hintResolver,
        ),
      );
}
