import 'dart:io';

import 'package:any_treemap/src/geometry.dart';
import 'package:any_treemap/src/layout.dart';
import 'package:any_treemap/src/model.dart';

final class _Result {
  const _Result(this.name, this.samples, this.memoryDeltaBytes);

  final String name;
  final List<int> samples;
  final int memoryDeltaBytes;

  int percentile(double fraction) {
    final ordered = [...samples]..sort();
    return ordered[((ordered.length - 1) * fraction).round()];
  }
}

TreemapNode<int> _flat(int count, {int revision = 0}) => TreemapNode(
  key: -1,
  children: [
    for (var index = 0; index < count; index++)
      TreemapNode(
        key: index,
        weight: ((index * 17 + revision) % 97 + 1).toDouble(),
      ),
  ],
);

TreemapNode<int> _grouped(int groupCount, int childrenPerGroup) => TreemapNode(
  key: -1,
  children: [
    for (var group = 0; group < groupCount; group++)
      TreemapNode(
        key: 100000 + group,
        children: [
          for (var child = 0; child < childrenPerGroup; child++)
            TreemapNode(
              key: group * childrenPerGroup + child,
              weight: (child % 13 + 1).toDouble(),
            ),
        ],
      ),
  ],
);

TreemapNode<int> _deep(int depth) {
  var node = TreemapNode(key: depth, weight: 1);
  for (var index = depth - 1; index >= 0; index--) {
    node = TreemapNode(key: index, children: [node]);
  }
  return node;
}

_Result _measure(String name, int runs, void Function(int run) body) {
  for (var index = 0; index < 2; index++) {
    body(index);
  }
  final before = ProcessInfo.currentRss;
  final samples = <int>[];
  for (var run = 0; run < runs; run++) {
    final stopwatch = Stopwatch()..start();
    body(run);
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }
  final memoryDelta = ProcessInfo.currentRss - before;
  return _Result(name, samples, memoryDelta < 0 ? 0 : memoryDelta);
}

void main(List<String> arguments) {
  final verify = arguments.contains('--verify');
  const viewport = TreemapBounds.fromLTWH(0, 0, 1600, 900);
  final results = <_Result>[];

  for (final size in [100, 1000, 10000]) {
    final root = _flat(size);
    results.add(
      _measure('layout-$size', size == 10000 ? 5 : 12, (_) {
        TreemapLayoutEngine<int>().layout(root: root, viewport: viewport);
      }),
    );
  }

  final resizeRoot = _flat(1000);
  final resizeEngine = TreemapLayoutEngine<int>();
  results.add(
    _measure('resize-1000', 12, (run) {
      resizeEngine.layout(
        root: resizeRoot,
        viewport: TreemapBounds.fromLTWH(
          0,
          0,
          800 + (run % 5) * 120,
          500 + (run % 3) * 90,
        ),
      );
    }),
  );

  final grouped = _grouped(50, 20);
  final zoomEngine = TreemapLayoutEngine<int>();
  results.add(
    _measure('zoom-1000', 12, (run) {
      zoomEngine.layout(
        root: grouped,
        viewport: viewport,
        focus: TreemapFocus.source(100000 + run % 50),
      );
    }),
  );

  results.add(
    _measure('depth-1000', 5, (_) {
      TreemapLayoutEngine<int>().layout(root: _deep(1000), viewport: viewport);
    }),
  );

  final transitionEngine = TreemapLayoutEngine<int>();
  final before = transitionEngine.layout(root: _flat(1000), viewport: viewport);
  final after = transitionEngine.layout(
    root: _flat(1000, revision: 1),
    viewport: viewport,
    previous: before,
  );
  results.add(
    _measure('animated-update-1000x30', 8, (_) {
      for (var frame = 0; frame < 30; frame++) {
        TreemapGeometryTransition.lerp(before, after, frame / 29);
      }
    }),
  );

  const p95BudgetsUs = <String, int>{
    'layout-100': 50000,
    'layout-1000': 250000,
    'layout-10000': 2500000,
    'resize-1000': 300000,
    'zoom-1000': 100000,
    'depth-1000': 500000,
    'animated-update-1000x30': 1500000,
  };
  const memoryBudget = 256 * 1024 * 1024;
  var failed = false;
  stdout.writeln('scenario,p50_us,p95_us,rss_delta_bytes,budget_us');
  for (final result in results) {
    final p50 = result.percentile(.5);
    final p95 = result.percentile(.95);
    final budget = p95BudgetsUs[result.name]!;
    stdout.writeln(
      '${result.name},$p50,$p95,${result.memoryDeltaBytes},$budget',
    );
    if (verify && (p95 > budget || result.memoryDeltaBytes > memoryBudget)) {
      failed = true;
      stderr.writeln('Budget exceeded by ${result.name}.');
    }
  }
  if (failed) exitCode = 1;
}
