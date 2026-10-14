import '../scenario.dart';

final dataScenarios = <ExamplePreset>[
  ExamplePreset(
    id: 'data-single-child-promotion',
    title: 'Promote single-child branches',
    category: 'Data',
    description:
        'Preparation replaces B with its only child Sixty (60). A keeps Ten and Thirty. Switch Single-child branches to Preserve to restore B and its breadcrumb level.',
    dataKey: 'color-domain',
    overrides: {
      'data.singleChildPolicy': 'promote',
      'layout.maxVisibleDepth': 1,
      'breadcrumbs.enabled': true,
    },
  ),
  ExamplePreset(
    id: 'data-prepared-tree',
    title: 'One prepared tree, two charts',
    category: 'Data',
    description:
        'Both charts share the prepared 10/30/60 hierarchy. Drill into A in one chart: its domain becomes 10–30 while the other stays 40–60.',
    dataKey: 'color-domain',
    overrides: {
      'preview.mode': 'sharedTree',
      'color.scale': 'interpolated',
      'color.domainScope': 'visible',
      'layout.maxVisibleDepth': 1,
      'legend.enabled': true,
      'breadcrumbs.enabled': true,
    },
  ),
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
