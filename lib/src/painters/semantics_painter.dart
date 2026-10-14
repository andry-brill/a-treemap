import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../presentation/context.dart';
import '../presentation/state.dart';

/// Builds positioned accessibility nodes without adding visible canvas output.
///
/// This bridges canvas-rendered treemap geometry into Flutter's semantics tree
/// so screen readers and other assistive technologies can discover and
/// interact with individual nodes.
final class TreemapSemanticsPainter<K> extends CustomPainter {
  const TreemapSemanticsPainter({
    required this.visual,
    required this.labelResolver,
    required this.valueResolver,
    required this.hintResolver,
  });

  final TreemapVisualContext<K> visual;
  final String Function(TreemapNodeDetails<K> details)? labelResolver;
  final String Function(TreemapNodeDetails<K> details)? valueResolver;
  final String Function(TreemapNodeDetails<K> details)? hintResolver;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (Size size) => [
        for (final node in visual.presentation.displayedSnapshot!.visibleNodes)
          CustomPainterSemantics(
            rect: Rect.fromLTWH(
              node.bounds.left,
              node.bounds.top,
              node.bounds.width,
              node.bounds.height,
            ),
            properties: _properties(visual.presentation.details[node.key]!),
          ),
      ];

  SemanticsProperties _properties(TreemapNodeDetails<K> details) {
    final fallbackLabel = details.key.sourceKey?.toString() ?? 'Other';
    return SemanticsProperties(
      label:
          labelResolver?.call(details) ??
          details.node?.semanticLabel ??
          details.label ??
          fallbackLabel,
      value: valueResolver?.call(details) ?? details.weight.toString(),
      textDirection: visual.textDirection,
      hint:
          hintResolver?.call(details) ??
          (details.hasChildren
              ? 'Level ${details.depth + 1}. Activate to drill down.'
              : 'Level ${details.depth + 1}.'),
      button: true,
      selected: visual.presentation.selectedEntries.contains(details.key),
      focused: visual.presentation
          .statesFor(details.key)
          .contains(TreemapVisualState.focused),
      headingLevel: details.hasChildren
          ? (details.depth + 1).clamp(1, 6)
          : null,
      expanded: details.hasChildren ? false : null,
      onTap: () => visual.actions.activate(details.key),
      onFocus: () => visual.actions.focus(details.key),
      onExpand: details.hasChildren
          ? () => visual.actions.activate(details.key)
          : null,
    );
  }

  @override
  bool shouldRepaint(covariant TreemapSemanticsPainter<K> oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(
    covariant TreemapSemanticsPainter<K> oldDelegate,
  ) =>
      visual.presentation.displayedSnapshot!.nodes !=
          oldDelegate.visual.presentation.displayedSnapshot!.nodes ||
      visual.presentation.details != oldDelegate.visual.presentation.details ||
      !setEquals(
        visual.presentation.selectedEntries,
        oldDelegate.visual.presentation.selectedEntries,
      ) ||
      visual.presentation.states != oldDelegate.visual.presentation.states ||
      labelResolver != oldDelegate.labelResolver ||
      valueResolver != oldDelegate.valueResolver ||
      hintResolver != oldDelegate.hintResolver;
}
