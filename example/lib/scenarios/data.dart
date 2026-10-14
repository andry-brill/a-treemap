import '../scenario.dart';

final dataScenarios = <ExamplePreset>[
  ExamplePreset(
    id: "data-explicit-tree",
    title: "Explicit immutable tree",
    category: "Data",
    description:
        "Six weighted leaves form Consumer 100 and Business 80. Tile area follows weight.",
    dataKey: "markets",
    overrides: {},
  ),
  ExamplePreset(
    id: "data-from-records",
    title: "Flat records factory",
    category: "Data",
    description:
        "Four sales records use fromRecords to create North 85 and South 56.",
    dataKey: "sales-records",
    overrides: {"data.construction": "fromRecords"},
  ),
  ExamplePreset(
    id: "data-empty-state",
    title: "Empty and all-zero state",
    category: "Data",
    description:
        "A zero-weight leaf produces no tiles and no built-in empty message.",
    dataKey: "all-zero",
    overrides: {"tiles.renderer": "noop", "labels.renderer": "none"},
  ),
  ExamplePreset(
    id: "data-invalid-errors",
    title: "Actionable invalid-input errors",
    category: "Data",
    description: "NaN on key bad produces a typed validation error.",
    dataKey: "invalid-weight",
    overrides: {"preview.mode": "validation"},
  ),
  ExamplePreset(
    id: "performance-isolate-layout",
    title: "Optional isolate layout",
    category: "Performance",
    description: "Run layout for 10,000 leaves and inspect the result.",
    dataKey: "many-nodes",
    overrides: {
      "data.count": 10000,
      "preview.mode": "isolate",
      "labels.renderer": "none",
      "preview.width": 1600,
      "preview.height": 900,
    },
  ),
];
