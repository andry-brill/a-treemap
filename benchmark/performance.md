# Performance policy

`benchmark/layout_benchmark.dart` measures the pure engine independently of
Flutter frame scheduling. It reports p50, p95, and resident-memory delta for
flat 100/1,000/10,000-node layouts, a 1,000-node resize sequence, focused zoom,
a 1,000-level hierarchy, and 30-frame keyed animated updates.

Run locally from the repository root:

```console
dart run benchmark/layout_benchmark.dart
dart run benchmark/layout_benchmark.dart --verify
```

The verification budgets are deliberately portable release guards rather than
claims about a particular device:

| Scenario | p95 budget |
|---|---:|
| 100-node layout | 50 ms |
| 1,000-node layout | 250 ms |
| 10,000-node layout | 2,500 ms |
| 1,000-node resize | 300 ms |
| focused zoom | 100 ms |
| 1,000-level hierarchy | 500 ms |
| 30-frame 1,000-node transition | 1,500 ms |

Every scenario also has a 256 MiB resident-memory-delta ceiling. Track tighter
product-specific frame budgets on controlled hardware; shared CI runners are
used only to detect major algorithmic regressions.
