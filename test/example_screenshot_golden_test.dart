import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';
import 'support/pump_app.dart';

double _minimumSiblingGap(List<TreemapGeometryNode<String>> nodes) {
  var minimum = double.infinity;
  for (var firstIndex = 0; firstIndex < nodes.length; firstIndex++) {
    final first = nodes[firstIndex].bounds;
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < nodes.length;
      secondIndex++
    ) {
      final second = nodes[secondIndex].bounds;
      final verticalOverlap =
          first.bottom > second.top && second.bottom > first.top;
      if (verticalOverlap) {
        final gap = first.right <= second.left
            ? second.left - first.right
            : second.right <= first.left
            ? first.left - second.right
            : -1.0;
        if (gap >= 0 && gap < minimum) minimum = gap;
      }
      final horizontalOverlap =
          first.right > second.left && second.right > first.left;
      if (horizontalOverlap) {
        final gap = first.bottom <= second.top
            ? second.top - first.bottom
            : second.bottom <= first.top
            ? first.top - second.bottom
            : -1.0;
        if (gap >= 0 && gap < minimum) minimum = gap;
      }
    }
  }
  return minimum;
}

void _expectTrailingTilesAligned(
  TreemapGeometrySnapshot<String> snapshot,
  String groupKey,
) {
  final lastLeaf = snapshot.index[TreemapKey.source('$groupKey-item-7')]!;
  final aggregate = snapshot.nodes.singleWhere(
    (node) => node.isAggregate && node.parentKey?.sourceKey == groupKey,
  );
  expect(
    aggregate.bounds.left,
    closeTo(lastLeaf.bounds.left, .001),
    reason: '$groupKey Other must align with the tile directly above it',
  );
  expect(
    aggregate.bounds.right,
    closeTo(lastLeaf.bounds.right, .001),
    reason: '$groupKey Other must align with the tile directly above it',
  );
  expect(aggregate.bounds.width, greaterThan(32));
}

void _expectGroupTilesAligned(TreemapGeometrySnapshot<String> snapshot) {
  final blueGroup = snapshot.index[TreemapKey.source('screenshot-blue')]!;
  final pinkGroup = snapshot.index[TreemapKey.source('screenshot-pink')]!;

  void expectSameLocalBounds(
    TreemapGeometryNode<String> blue,
    TreemapGeometryNode<String> pink,
  ) {
    expect(
      blue.bounds.left - blueGroup.bounds.left,
      closeTo(pink.bounds.left - pinkGroup.bounds.left, .001),
    );
    expect(
      blue.bounds.top - blueGroup.bounds.top,
      closeTo(pink.bounds.top - pinkGroup.bounds.top, .001),
    );
    expect(
      blue.bounds.right - blueGroup.bounds.left,
      closeTo(pink.bounds.right - pinkGroup.bounds.left, .001),
    );
    expect(
      blue.bounds.bottom - blueGroup.bounds.top,
      closeTo(pink.bounds.bottom - pinkGroup.bounds.top, .001),
    );
  }

  for (var index = 0; index < 8; index++) {
    expectSameLocalBounds(
      snapshot.index[TreemapKey.source('screenshot-blue-item-$index')]!,
      snapshot.index[TreemapKey.source('screenshot-pink-item-$index')]!,
    );
  }
  expectSameLocalBounds(
    snapshot.nodes.singleWhere(
      (node) =>
          node.isAggregate && node.parentKey?.sourceKey == 'screenshot-blue',
    ),
    snapshot.nodes.singleWhere(
      (node) =>
          node.isAggregate && node.parentKey?.sourceKey == 'screenshot-pink',
    ),
  );
}

void main() {
  testWidgets('Screenshot appearance visual contract', (tester) async {
    final scenario = allScenarios.singleWhere(
      (item) => item.id == 'appearance-screenshot',
    );
    await tester.pumpTreemapApp(
      Material(child: Builder(builder: scenario.builder)),
      surfaceSize: const Size(900, 600),
    );
    await tester.pump();

    final chartFinder = find.byType(TreemapChart<String>);
    final chart = tester.widget<TreemapChart<String>>(chartFinder);
    final chartSize = tester.getSize(chartFinder);
    expect(chartSize, const Size.square(600));
    expect(chart.root.children, hasLength(2));
    for (final group in chart.root.children) {
      expect(group.children, hasLength(16));
      expect(group.color, Colors.transparent);
      expect(group.children.map((node) => node.color).toSet(), hasLength(8));
      final opacities = group.children
          .take(8)
          .map((node) => (node.color! as Color).a)
          .toList(growable: false);
      expect(opacities.first, 1);
      expect(opacities.last, closeTo(.2, .001));
      for (var index = 1; index < opacities.length; index++) {
        expect(opacities[index], lessThan(opacities[index - 1]));
      }
    }
    expect(chart.layout.minimumHeight, 24);

    final snapshot = TreemapLayoutEngine<String>().layout(
      root: chart.root,
      viewport: TreemapBounds.fromLTWH(0, 0, chartSize.width, chartSize.height),
      config: chart.layout,
    );
    final aggregates = snapshot.nodes
        .where((node) => node.isAggregate)
        .toList(growable: false);
    final groupGeometry = snapshot.nodes
        .where((node) => node.node?.children.isNotEmpty ?? false)
        .toList(growable: false);
    expect(aggregates, hasLength(2));
    expect(groupGeometry, hasLength(2));
    expect(aggregates.map((node) => node.parentKey?.sourceKey).toSet(), {
      'screenshot-blue',
      'screenshot-pink',
    });

    final blueNodes = snapshot.visibleNodes
        .where((node) => node.parentKey?.sourceKey == 'screenshot-blue')
        .toList(growable: false);
    final pinkNodes = snapshot.visibleNodes
        .where((node) => node.parentKey?.sourceKey == 'screenshot-pink')
        .toList(growable: false);
    final blueRight = blueNodes
        .map((node) => node.bounds.right)
        .reduce((a, b) => a > b ? a : b);
    final pinkLeft = pinkNodes
        .map((node) => node.bounds.left)
        .reduce((a, b) => a < b ? a : b);
    expect(pinkLeft - blueRight, closeTo(32, .001));
    expect(_minimumSiblingGap(blueNodes), closeTo(16, .001));
    expect(_minimumSiblingGap(pinkNodes), closeTo(16, .001));

    final responsiveSnapshots = [
      for (final viewport in const [
        TreemapBounds.fromLTWH(0, 0, 600, 600),
        TreemapBounds.fromLTWH(0, 0, 900, 600),
        // Reproduces the logical browser size at 1.2× display scale.
        TreemapBounds.fromLTWH(0, 0, 880, 520),
        TreemapBounds.fromLTWH(0, 0, 1042, 617),
      ])
        TreemapLayoutEngine<String>().layout(
          root: chart.root,
          viewport: viewport,
          config: chart.layout,
        ),
    ];
    for (final responsiveSnapshot in responsiveSnapshots) {
      _expectGroupTilesAligned(responsiveSnapshot);
    }
    for (final responsiveSnapshot in responsiveSnapshots.skip(1)) {
      _expectTrailingTilesAligned(responsiveSnapshot, 'screenshot-blue');
      _expectTrailingTilesAligned(responsiveSnapshot, 'screenshot-pink');
    }

    final labels = chart.labels! as TreemapCanvasLabels<String>;
    expect(
      labels.appearance.style.labelPadding,
      const EdgeInsets.only(left: 16, top: 12),
    );
    final chartContext = tester.element(chartFinder);
    for (final responsiveSnapshot in responsiveSnapshots) {
      for (final aggregate in responsiveSnapshot.nodes.where(
        (node) => node.isAggregate,
      )) {
        expect(aggregate.aggregateMembers, hasLength(8));
        final siblings = responsiveSnapshot.visibleNodes.where(
          (node) => node.parentKey == aggregate.parentKey && !node.isAggregate,
        );
        for (final sibling in siblings) {
          expect(aggregate.bounds.area, lessThan(sibling.bounds.area));
        }

        final details = TreemapNodeDetails<String>(
          geometry: aggregate,
          path: const [],
        );
        final appearance = labels.appearance.resolve(
          chartContext,
          details,
          const {},
        );
        final line = labels.config
            .resolveLines(details, appearance, const Locale('en'))
            .single;
        final padding = labels.appearance.style.labelPadding;
        final availableWidth = aggregate.bounds.width - padding.horizontal;
        final availableHeight = aggregate.bounds.height - padding.vertical;
        expect(availableWidth, greaterThan(0));
        final painter = TextPainter(
          text: TextSpan(text: line.text, style: line.style),
          textDirection: TextDirection.ltr,
          maxLines: labels.config.maxLines,
          ellipsis: labels.config.ellipsis,
        )..layout(maxWidth: availableWidth);
        expect(painter.height, 12);
        expect(painter.height, lessThanOrEqualTo(availableHeight));
        expect(
          painter.didExceedMaxLines,
          isFalse,
          reason:
              'Other... must fit ${aggregate.bounds} after padding leaves '
              '${availableWidth}x$availableHeight',
        );
        painter.dispose();
      }
    }
    for (final group in groupGeometry) {
      final details = TreemapNodeDetails<String>(
        geometry: group,
        path: const [],
      );
      expect(
        labels.appearance.resolve(chartContext, details, const {}).opacity,
        0,
      );
    }
    for (final aggregate in aggregates) {
      expect(aggregate.aggregateMembers, hasLength(8));
      expect(aggregate.bounds.width, greaterThan(90));
      expect(aggregate.bounds.height, greaterThanOrEqualTo(24));
      final details = TreemapNodeDetails<String>(
        geometry: aggregate,
        path: const [],
      );
      final appearance = labels.appearance.resolve(
        chartContext,
        details,
        const {},
      );
      expect(appearance.opacity, closeTo(.2, .001));
      expect(
        labels.config
            .resolveLines(details, appearance, const Locale('en'))
            .single
            .text,
        'Other...',
      );
    }
    for (final node in [...blueNodes, ...pinkNodes]) {
      final details = TreemapNodeDetails<String>(
        geometry: node,
        path: const [],
      );
      final resolved = labels.appearance.resolve(
        chartContext,
        details,
        const {},
      );
      expect(resolved.border, BorderSide.none);
      expect(
        resolved.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(resolved.opacity, inInclusiveRange(.2, 1));
      expect(labels.config.colorResolver(resolved), const Color(0xCC000000));
    }

    await tester.pumpTreemapApp(
      Center(
        child: RepaintBoundary(
          key: const ValueKey('screenshot-golden'),
          child: SizedBox.square(
            dimension: 600,
            child: TreemapChart<String>(
              root: chart.root,
              tiles: chart.tiles,
              layout: chart.layout,
              clipBehavior: chart.clipBehavior,
            ),
          ),
        ),
      ),
      surfaceSize: const Size(900, 600),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('screenshot-golden')),
      matchesGoldenFile('goldens/example_screenshot.png'),
    );
  });
}
