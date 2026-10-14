part of 'config.dart';

const datasetKeys = [
  'markets',
  'sales-records',
  'color-domain',
  'categories',
  'many-nodes',
  'dense-tail',
  'direct-colors',
  'opacity-groups',
  'standalone-values',
  'all-zero',
  'invalid-weight',
];
const algorithms = [
  'squarified',
  'resquarified',
  'slice',
  'dice',
  'alternatingSliceDice',
  'strip',
  'binaryByWeight',
  'binaryByCount',
];
const origins = ['topLeft', 'topRight', 'bottomLeft', 'bottomRight'];
const axes = ['horizontalFirst', 'verticalFirst'];
const overlayPositions = [
  'topStart',
  'topCenter',
  'topEnd',
  'middleStart',
  'middleEnd',
  'bottomStart',
  'bottomCenter',
  'bottomEnd',
];
const alignments = [
  'topLeft',
  'topCenter',
  'topRight',
  'centerLeft',
  'center',
  'centerRight',
  'bottomLeft',
  'bottomCenter',
  'bottomRight',
];
const clips = ['none', 'hardEdge', 'antiAlias', 'antiAliasWithSaveLayer'];
const fontWeights = [
  'w100',
  'w200',
  'w300',
  'w400',
  'w500',
  'w600',
  'w700',
  'w800',
  'w900',
];

List<PlaygroundProperty> propertyDefinitions() {
  final fields = <PlaygroundProperty>[];
  void c(
    String key,
    String label,
    String group,
    String help,
    String value,
    List<String> options, {
    Map<String, String> labels = const {},
    bool Function(PlaygroundConfig)? available,
    String? reason,
  }) => fields.add(
    choice(
      key,
      label,
      group,
      help,
      value,
      options,
      labels: labels,
      available: available,
      reason: reason,
    ),
  );
  void b(
    String key,
    String label,
    String group,
    String help,
    bool value, {
    bool Function(PlaygroundConfig)? available,
    String? reason,
  }) => fields.add(
    toggle(
      key,
      label,
      group,
      help,
      value,
      available: available,
      reason: reason,
    ),
  );
  void n(
    String key,
    String label,
    String group,
    String help,
    double? value, {
    double? min = 0,
    double? max,
    bool integer = false,
    ({String key, String label})? padding,
    String? nullLabel,
    bool Function(PlaygroundConfig)? available,
    String? reason,
  }) => fields.add(
    numeric(
      key,
      label,
      group,
      help,
      value,
      min: min,
      max: max,
      integer: integer,
      padding: padding,
      nullLabel: nullLabel,
      available: available,
      reason: reason,
    ),
  );
  void s(
    String key,
    String label,
    String group,
    String help,
    String value, {
    bool nonempty = false,
  }) => fields.add(
    stringField(key, label, group, help, value, nonempty: nonempty),
  );
  void col(
    String key,
    String label,
    String group,
    String help,
    Color? value, {
    bool optional = false,
  }) => fields.add(
    colorField(key, label, group, help, value, optional: optional),
  );
  void inset(
    String prefix,
    String label,
    String group,
    String help,
    double value,
  ) {
    for (final side in paddingSides) {
      n(
        '$prefix.$side',
        '$label · $side',
        group,
        '$help Enter one whole number for all sides; two for horizontal, vertical; or four for left, top, right, bottom. Use commas. The slider adjusts equal sides together.',
        value,
        max: 256,
        padding: (key: prefix, label: label),
      );
    }
  }

  c(
    'data',
    'Data',
    'Data',
    'Shared source dataset. Presets may reuse the same data; changing data resets navigation and selection.',
    'markets',
    datasetKeys,
  );
  c(
    'data.construction',
    'Construction',
    'Data',
    'Sales records can be grouped through TreemapNode.fromRecords or built as the equivalent explicit tree.',
    'explicit',
    ['explicit', 'fromRecords'],
    available: (config) => config.text('data') == 'sales-records',
    reason: 'The sales-records dataset demonstrates both constructors.',
  );
  n(
    'data.count',
    'Node count',
    'Data',
    'Number of generated leaves in many-nodes and dense-tail datasets.',
    40,
    min: 1,
    max: 10000,
    integer: true,
    available: (config) =>
        ['many-nodes', 'dense-tail'].contains(config.text('data')),
    reason: 'Choose a generated dataset to change its node count.',
  );
  c(
    'data.grouping',
    'Grouping',
    'Data',
    'Hierarchy keeps source branches; level2 promotes their children; flat promotes all leaves.',
    'hierarchy',
    ['hierarchy', 'level2', 'flat'],
  );
  c(
    'data.singleChildPolicy',
    'Single-child branches',
    'Data',
    'Promote replaces single-child branches before the tree is used. Children keep their metadata; removed parents lose theirs. The root is preserved; paths and depths reflect the resulting hierarchy.',
    'preserve',
    ['preserve', 'promote'],
    labels: {'preserve': 'Preserve', 'promote': 'Promote'},
  );
  n(
    'data.revision',
    'Data revision',
    'Data',
    'A deterministic update: markets changes Mobile by 20 per revision; color-domain changes Thirty to Ninety on odd revisions.',
    0,
    max: 100,
    integer: true,
  );

  c(
    'layout.algorithm',
    'Algorithm',
    'Layout',
    'Partitions sibling weights into rectangles. Resquarified reuses previous topology when data changes.',
    'squarified',
    algorithms,
  );
  c(
    'layout.sort',
    'Sort',
    'Layout',
    'Sibling order. Custom sort uses the named comparator below.',
    'descending',
    ['sourceOrder', 'ascending', 'descending', 'custom'],
  );
  c(
    'layout.comparator',
    'Custom comparator',
    'Layout',
    'A registered comparator for custom sorting: label order or stable reverse source key.',
    'label',
    ['label', 'reverseKey'],
    available: (config) => config.text('layout.sort') == 'custom',
    reason: 'Select Custom sort to use this comparator.',
  );
  c(
    'layout.origin',
    'Origin',
    'Layout',
    'Corner from which layout places nodes. This is independent of interface text direction.',
    'topLeft',
    origins,
  );
  c(
    'layout.axisOrder',
    'Axis order',
    'Layout',
    'Preferred flow axis. A square viewport makes the binary-layout difference easiest to see.',
    'horizontalFirst',
    axes,
  );
  c(
    'layout.strategy',
    'Custom strategy',
    'Layout',
    'Equal columns replaces weighted partitioning with the registered ITreemapLayoutStrategy implementation.',
    'builtin',
    ['builtin', 'equalColumns'],
  );
  b(
    'layout.inherit',
    'Inherit resolved rules',
    'Layout',
    'When enabled, descendant rules inherit their parent rule; otherwise resolution begins with the root rule.',
    true,
  );
  c(
    'layout.resolver',
    'Rule resolver',
    'Layout',
    'Registered callback that can override a resolved rule by depth, parent key or viewport shape.',
    'none',
    ['none', 'alternateDepth', 'consumerDice', 'responsive'],
  );
  fields.add(
    rowField(
      'layout.rules',
      'Depth and parent rules',
      'Layout',
      'Per-depth and per-parent rules. Callback resolution runs after these entries. Inherit leaves a property unchanged.',
      PropertyEditor.rules,
      const [],
    ),
  );
  n(
    'layout.maxVisibleDepth',
    'Visible depth',
    'Layout',
    'Levels below the current focus: 1 shows children, 2 also shows grandchildren. Unlimited shows every level; branch totals remain complete.',
    null,
    min: 1,
    max: 16,
    integer: true,
    nullLabel: 'Unlimited',
  );
  inset(
    'layout.outerPadding',
    'Outer padding',
    'Layout',
    'Inset between the viewport and root children, in logical pixels.',
    0,
  );
  inset(
    'layout.levelPadding',
    'Level padding',
    'Layout',
    'Inset inside every branch before laying out its children.',
    0,
  );
  n(
    'layout.innerSpacing',
    'Inner spacing',
    'Layout',
    'Logical-pixel gap between siblings. Spacing affects available tile geometry.',
    3,
    max: 64,
  );
  for (final entry in [
    ('Width', 'minimumWidth'),
    ('Height', 'minimumHeight'),
    ('Area', 'minimumArea'),
  ]) {
    n(
      'layout.${entry.$2}',
      'Minimum ${entry.$1.toLowerCase()}',
      'Layout',
      'Minimum tile ${entry.$1.toLowerCase()} before hiding or aggregating small siblings.',
      0,
      max: entry.$2 == 'minimumArea' ? 1000000 : 512,
    );
  }
  c(
    'layout.minimumNodePolicy',
    'Small node policy',
    'Layout',
    'Show keeps small source tiles; Hide culls them; Aggregate combines them into a revealable Other tile.',
    'show',
    ['show', 'hide', 'aggregate'],
  );
  c(
    'layout.insufficientSpacePolicy',
    'Insufficient space',
    'Layout',
    'Behavior when every sibling is below its minimum: retain the chosen policy, hide the set, or report an error.',
    'show',
    ['show', 'hide', 'error'],
  );

  c(
    'color.input',
    'Color input',
    'Colors',
    'Source preserves the fixture; weight leaves node.color absent; numeric uses normalized totals; category uses stable category keys; direct uses Flutter colors.',
    'source',
    ['source', 'weight', 'numeric', 'category', 'direct'],
  );
  c(
    'color.scale',
    'Color scale',
    'Colors',
    'Dataset uses its suggested exact palette. Other choices use the explicit controls below; direct Flutter colors bypass every scale.',
    'dataset',
    [
      'dataset',
      'exact',
      'categorical',
      'numericRange',
      'interpolated',
      'saturation',
    ],
  );
  col(
    'color.fallback',
    'Fallback color',
    'Colors',
    'Used for unmatched categories, invalid numeric inputs and empty automatic domains.',
    const Color(0xFF607D8B),
  );
  fields.add(
    paletteField(
      'color.palette',
      'Palette',
      'Colors',
      'Ordered colors for categorical and interpolated scales. Interpolation blends between consecutive stops.',
      const [Colors.blue, Colors.red],
    ),
  );
  fields.add(
    rowField(
      'color.mappings',
      'Exact mappings',
      'Colors',
      'Typed exact values, colors and optional legend labels. Text and numeric keys are distinct.',
      PropertyEditor.mappings,
      const [
        {'value': 10, 'color': 'FF2196F3', 'label': 'Ten'},
        {'value': 60, 'color': 'FFF44336', 'label': 'Sixty'},
      ],
    ),
  );
  fields.add(
    rowField(
      'color.ranges',
      'Numeric ranges',
      'Colors',
      'Each range has a minimum, maximum, color and label; values outside all ranges use fallback.',
      PropertyEditor.ranges,
      const [
        {'minimum': 0, 'maximum': 25, 'color': 'FF2196F3', 'label': 'Low'},
        {'minimum': 25, 'maximum': 100, 'color': 'FFF44336', 'label': 'High'},
      ],
    ),
  );
  s(
    'color.labels',
    'Category labels',
    'Colors',
    'Comma-separated optional labels, corresponding to palette entries.',
    'Consumer,Business',
  );
  bool continuous(PlaygroundConfig config) =>
      ['interpolated', 'saturation'].contains(config.text('color.scale'));
  for (final bound in ['minimum', 'maximum']) {
    n(
      'color.$bound',
      'Color $bound',
      'Colors',
      'Auto independently infers this bound. Both fixed bounds must be increasing. Constant inferred domains use the midpoint.',
      null,
      min: null,
      nullLabel: 'Auto',
      available: continuous,
      reason: 'Continuous scales use numeric bounds.',
    );
  }
  c(
    'color.domainScope',
    'Domain scope',
    'Colors',
    'Global uses all source branches and leaves except the root. Visible uses destination tiles after depth, culling and aggregation.',
    'global',
    ['global', 'visible'],
    available: continuous,
    reason: 'Automatic continuous scales use domain scope.',
  );
  col(
    'color.saturationHue',
    'Saturation hue',
    'Colors',
    'Base hue and lightness for the saturation scale.',
    Colors.indigo,
  );
  n(
    'color.minimumSaturation',
    'Minimum saturation',
    'Colors',
    'Saturation at the lower numeric endpoint.',
    .15,
    max: 1,
  );
  n(
    'color.maximumSaturation',
    'Maximum saturation',
    'Colors',
    'Saturation at the upper numeric endpoint; must be at least the minimum saturation.',
    1,
    max: 1,
  );
  c(
    'color.formatter',
    'Domain label format',
    'Colors',
    'Registered formatter for continuous legend stops: plain numbers, one decimal, units or opacity.',
    'plain',
    ['plain', 'oneDecimal', 'units', 'opacity'],
  );

  c(
    'tiles.renderer',
    'Tile renderer',
    'Tile Appearance',
    'Canvas paints all tiles at once; widgets builds a widget per tile; composite stacks canvas and widget borders; noop draws no tiles.',
    'canvas',
    ['canvas', 'widgets', 'composite', 'noop'],
  );
  c(
    'tiles.nodeStyle',
    'Node style resolver',
    'Tile Appearance',
    'Registered per-node style callback: depth, gradient states, or transparent branches with opacity-colored leaves.',
    'none',
    ['none', 'depth', 'gradientStates', 'opacityGroups'],
  );
  n(
    'tiles.maximumNodes',
    'Maximum widget nodes',
    'Tile Appearance',
    'Limit for widget/composite tiles. Unlimited retains all visible nodes.',
    null,
    min: 1,
    max: 10000,
    integer: true,
    nullLabel: 'Unlimited',
  );
  b(
    'tiles.ignorePointer',
    'Ignore widget pointer input',
    'Tile Appearance',
    'Keep widget tiles from handling pointer gestures; chart-level hit testing remains available.',
    false,
  );
  col(
    'tiles.background',
    'Chart background',
    'Tile Appearance',
    'Canvas tile surface background; transparent allows the preview surface to show through.',
    Colors.transparent,
  );
  for (final state in ['normal', 'hover', 'selected', 'focused']) {
    final prefix = 'tiles.$state';
    final title = state == 'normal' ? 'Base' : _humanize(state);
    col(
      '$prefix.color',
      '$title fill override',
      'Tile Appearance',
      'Optional fill applied by this visual state. Inherit keeps the resolved color scale.',
      null,
      optional: true,
    );
    c(
      '$prefix.gradient',
      '$title gradient',
      'Tile Appearance',
      'Registered gradient paint using the palette endpoints; None keeps solid fill.',
      'none',
      ['none', 'linear', 'radial'],
    );
    col(
      '$prefix.borderColor',
      '$title border color',
      'Tile Appearance',
      'Stroke color applied for this visual state.',
      state == 'selected' ? Colors.amber : Colors.white,
    );
    n(
      '$prefix.borderWidth',
      '$title border width',
      'Tile Appearance',
      'Stroke thickness. Zero removes this state border.',
      state == 'hover'
          ? 2
          : state == 'selected'
          ? 3
          : 0,
      max: 16,
    );
    n(
      '$prefix.radius',
      '$title corner radius',
      'Tile Appearance',
      'Uniform corner radius for this visual state; zero retains the underlying state radius when merged.',
      state == 'normal' ? 6 : 0,
      max: 128,
    );
    n(
      '$prefix.opacity',
      '$title opacity',
      'Tile Appearance',
      'Opacity multiplies with the other resolved appearance states.',
      1,
      max: 1,
    );
    n(
      '$prefix.titleSize',
      '$title title size',
      'Tile Appearance',
      'Optional title font size override applied by the appearance resolver.',
      null,
      min: 6,
      max: 96,
      nullLabel: 'Inherit',
    );
    n(
      '$prefix.valueSize',
      '$title value size',
      'Tile Appearance',
      'Optional value font size override applied by the appearance resolver.',
      null,
      min: 6,
      max: 96,
      nullLabel: 'Inherit',
    );
  }

  c(
    'labels.renderer',
    'Label renderer',
    'Labels',
    'Canvas uses optimized clipped text painting; widgets allows icons and arbitrary widgets; none omits labels.',
    'canvas',
    ['canvas', 'widgets', 'none'],
  );
  c(
    'labels.widgetBuilder',
    'Widget label builder',
    'Labels',
    'Standard text, icon/text virtualization, or category title with descendant total.',
    'standard',
    ['standard', 'icons', 'category'],
  );
  b(
    'labels.showTitle',
    'Show title',
    'Labels',
    'Paint the source or formatted node title.',
    true,
  );
  b(
    'labels.showValue',
    'Show value',
    'Labels',
    'Paint the effective node weight or selected value formatter.',
    true,
  );
  c(
    'labels.titleFormatter',
    'Title formatter',
    'Labels',
    'Registered source title, aggregate label, or uppercase title formatter.',
    'source',
    ['source', 'aggregate', 'uppercase'],
  );
  c(
    'labels.valueFormatter',
    'Value formatter',
    'Labels',
    'Registered weight, percent, or source-key formatter.',
    'weight',
    ['weight', 'percent', 'key'],
  );
  c(
    'labels.localizedFormatter',
    'Localized formatter',
    'Labels',
    'Locale-aware callback: none uses the ordinary value formatter; decimal and money use the preview locale.',
    'none',
    ['none', 'decimal', 'money'],
  );
  c(
    'labels.linesBuilder',
    'Canvas lines builder',
    'Labels',
    'Custom title/value/depth lines replace built-in line construction while preserving canvas clipping and text policy.',
    'default',
    ['default', 'titleValueDepth'],
  );
  s(
    'labels.fallbackTitle',
    'Fallback title',
    'Labels',
    'Used when a node has no usable title.',
    'Other',
  );
  n(
    'labels.weightFractionDigits',
    'Weight decimals',
    'Labels',
    'Fraction digits used by the standard weight formatter.',
    2,
    max: 12,
    integer: true,
  );
  for (final line in ['title', 'value']) {
    n(
      'labels.${line}Size',
      '${_humanize(line)} font size',
      'Labels',
      'Text size in logical pixels, before preview text scaling.',
      line == 'title' ? 12 : 11,
      min: 6,
      max: 96,
    );
    c(
      'labels.${line}Weight',
      '${_humanize(line)} font weight',
      'Labels',
      'Font weight for this text line.',
      line == 'title' ? 'w600' : 'w400',
      fontWeights,
    );
    col(
      'labels.${line}Color',
      '${_humanize(line)} color override',
      'Labels',
      'Inherit uses the label color resolver; an explicit color overrides it.',
      null,
      optional: true,
    );
  }
  c(
    'labels.colorResolver',
    'Text color resolver',
    'Labels',
    'Automatic contrasts against tile color; white or black fixes the text color.',
    'contrast',
    ['contrast', 'white', 'black'],
  );
  n(
    'labels.valueColorOpacity',
    'Value text opacity',
    'Labels',
    'Opacity applied to the inherited value color.',
    .82,
    max: 1,
  );
  n(
    'labels.maxLines',
    'Maximum title lines',
    'Labels',
    'Maximum title lines before overflow treatment.',
    1,
    min: 1,
    max: 12,
    integer: true,
  );
  c(
    'labels.overflow',
    'Text overflow',
    'Labels',
    'Overflow policy inside each node rectangle.',
    'ellipsis',
    ['ellipsis', 'clip', 'fade', 'visible'],
  );
  s(
    'labels.ellipsis',
    'Ellipsis',
    'Labels',
    'Text appended to clipped canvas titles.',
    '...',
    nonempty: true,
  );
  c(
    'labels.alignment',
    'Label alignment',
    'Labels',
    'Text block alignment inside the node bounds.',
    'topLeft',
    alignments,
  );
  c(
    'labels.textDirection',
    'Label text direction',
    'Labels',
    'Inherit follows preview direction; explicitly override label shaping without changing layout origin.',
    'inherit',
    ['inherit', 'ltr', 'rtl'],
  );
  inset(
    'labels.padding',
    'Label padding',
    'Labels',
    'Inset used by label rendering; it does not alter tile geometry.',
    6,
  );
  n(
    'labels.maximumNodes',
    'Maximum widget labels',
    'Labels',
    'Limit for widget labels; canvas labels do not use this limit.',
    null,
    min: 1,
    max: 10000,
    integer: true,
    nullLabel: 'Unlimited',
  );
  c(
    'labels.clip',
    'Widget label clipping',
    'Labels',
    'Per-node clipping for the widget label layer.',
    'hardEdge',
    clips,
  );
  n(
    'labels.minimumWidth',
    'Minimum label width',
    'Labels',
    'Widget label visibility threshold; independent of layout culling.',
    0,
    max: 512,
  );
  n(
    'labels.minimumHeight',
    'Minimum label height',
    'Labels',
    'Widget label visibility threshold; independent of layout culling.',
    0,
    max: 512,
  );

  b(
    'legend.enabled',
    'Show legend',
    'Legends and Breadcrumbs',
    'Render a legend using the chart-owned resolved color domain.',
    false,
  );
  c(
    'legend.kind',
    'Legend kind',
    'Legends and Breadcrumbs',
    'Auto selects a continuous bar or discrete items according to the configured scale.',
    'auto',
    ['auto', 'bar', 'discrete'],
  );
  c(
    'legend.position',
    'Legend position',
    'Legends and Breadcrumbs',
    'Directional cell around the chart viewport.',
    'bottomCenter',
    overlayPositions,
  );
  c(
    'legend.direction',
    'Legend direction',
    'Legends and Breadcrumbs',
    'Horizontal or vertical legend flow.',
    'horizontal',
    ['horizontal', 'vertical'],
  );
  c(
    'legend.overflow',
    'Legend overflow',
    'Legends and Breadcrumbs',
    'Wrap discrete items onto rows or scroll them along the configured axis.',
    'wrap',
    ['wrap', 'scroll'],
  );
  s(
    'legend.title',
    'Legend title',
    'Legends and Breadcrumbs',
    'Optional title; an empty string omits it.',
    '',
  );
  s(
    'legend.semanticsLabel',
    'Legend semantics',
    'Legends and Breadcrumbs',
    'Accessible label announced for the whole legend.',
    'Treemap legend',
  );
  b(
    'legend.segmented',
    'Segmented bar',
    'Legends and Breadcrumbs',
    'Use legend-entry colors instead of a finely sampled continuous bar.',
    false,
  );
  b(
    'legend.showLabels',
    'Legend labels',
    'Legends and Breadcrumbs',
    'Show numeric or categorical labels beside the color bar.',
    true,
  );
  for (final entry in [
    ('spacing', 8.0),
    ('runSpacing', 4.0),
    ('horizontalWidth', 160.0),
    ('horizontalHeight', 20.0),
    ('verticalWidth', 20.0),
    ('verticalHeight', 120.0),
    ('pointerExtent', 18.0),
    ('horizontalPointerOffset', 16.0),
    ('verticalPointerOffset', 18.0),
  ]) {
    n(
      'legend.${entry.$1}',
      'Legend ${_humanize(entry.$1)}',
      'Legends and Breadcrumbs',
      'Logical-pixel ${_humanize(entry.$1)} for the legend; horizontal and vertical sizes are stored independently.',
      entry.$2,
      min:
          entry.$1.contains('Width') ||
              entry.$1.contains('Height') ||
              entry.$1 == 'pointerExtent'
          ? 1
          : 0,
      max: 640,
    );
  }
  n(
    'legend.sampleCount',
    'Bar samples',
    'Legends and Breadcrumbs',
    'Number of samples used to paint a continuous bar; at least two.',
    32,
    min: 2,
    max: 256,
    integer: true,
  );
  c(
    'legend.wrapper',
    'Legend wrapper',
    'Legends and Breadcrumbs',
    'Registered standard, rounded theme-aware, or plain shell.',
    'standard',
    ['standard', 'rounded', 'plain'],
  );
  c(
    'legend.titleBuilder',
    'Legend title builder',
    'Legends and Breadcrumbs',
    'Registered standard or bold title widget.',
    'standard',
    ['standard', 'bold'],
  );
  c(
    'legend.labelBuilder',
    'Legend label builder',
    'Legends and Breadcrumbs',
    'Registered standard or compact label widget.',
    'standard',
    ['standard', 'compact'],
  );
  c(
    'legend.itemBuilder',
    'Legend item builder',
    'Legends and Breadcrumbs',
    'Registered swatch/label, rounded swatch, or chip.',
    'standard',
    ['standard', 'rounded', 'chips'],
  );
  c(
    'legend.barBuilder',
    'Legend bar builder',
    'Legends and Breadcrumbs',
    'Standard or rounded color bar.',
    'standard',
    ['standard', 'rounded'],
  );
  c(
    'legend.pointerBuilder',
    'Legend pointer builder',
    'Legends and Breadcrumbs',
    'Standard, current-color, numeric-text, or no pointer. Continuous pointers hide for nonnumeric inputs.',
    'standard',
    ['standard', 'color', 'text', 'none'],
  );
  b(
    'breadcrumbs.enabled',
    'Show breadcrumbs',
    'Legends and Breadcrumbs',
    'Controller navigation path; activate an ancestor to zoom out.',
    false,
  );
  c(
    'breadcrumbs.position',
    'Breadcrumb position',
    'Legends and Breadcrumbs',
    'Directional surrounding-grid cell for navigation.',
    'topStart',
    overlayPositions,
  );
  c(
    'breadcrumbs.overflow',
    'Breadcrumb overflow',
    'Legends and Breadcrumbs',
    'Wrap, scroll or ellipsis overflow for the path.',
    'wrap',
    ['wrap', 'scroll', 'ellipsis'],
  );
  n(
    'breadcrumbs.ellipsisMaximumChildren',
    'Breadcrumb limit',
    'Legends and Breadcrumbs',
    'Maximum visible path entries when ellipsis overflow is active.',
    2,
    min: 1,
    max: 16,
    integer: true,
  );
  c(
    'breadcrumbs.itemBuilder',
    'Breadcrumb item builder',
    'Legends and Breadcrumbs',
    'Standard item or animated orange current-item indicator.',
    'standard',
    ['standard', 'indicator'],
  );
  c(
    'breadcrumbs.separatorBuilder',
    'Breadcrumb separator',
    'Legends and Breadcrumbs',
    'Registered chevron, slash, or text separator widget.',
    'standard',
    ['standard', 'slash', 'text'],
  );
  s(
    'breadcrumbs.separatorText',
    'Separator text',
    'Legends and Breadcrumbs',
    'Text used by the text separator builder.',
    '/',
  );
  c(
    'breadcrumbs.wrapper',
    'Breadcrumb wrapper',
    'Legends and Breadcrumbs',
    'Standard, rounded, or plain breadcrumb shell.',
    'standard',
    ['standard', 'rounded', 'plain'],
  );
  c(
    'breadcrumbs.overflowIndicator',
    'Path overflow indicator',
    'Legends and Breadcrumbs',
    'Registered standard ellipsis or compact dots.',
    'standard',
    ['standard', 'dots'],
  );
  n(
    'surrounding.rowGap',
    'Surrounding row gap',
    'Legends and Breadcrumbs',
    'Gap between top, chart, and bottom rows.',
    0,
    max: 64,
  );
  n(
    'surrounding.columnGap',
    'Surrounding column gap',
    'Legends and Breadcrumbs',
    'Gap between surrounding cells and the chart.',
    0,
    max: 64,
  );
  inset(
    'surrounding.padding',
    'Surrounding padding',
    'Legends and Breadcrumbs',
    'Inset around the entire chart and surrounding composition.',
    0,
  );
  c(
    'surrounding.clip',
    'Surrounding clipping',
    'Legends and Breadcrumbs',
    'Clipping policy for the surrounding grid.',
    'none',
    clips,
  );

  for (final entry in [
    ('enabled', true),
    ('builtInBehavior', true),
    ('zoomOnTap', true),
    ('selectOnTap', false),
  ]) {
    b(
      'interaction.${entry.$1}',
      _humanize(entry.$1),
      'Interaction',
      'Controls chart interaction: ${_humanize(entry.$1)}. External callbacks run before built-in tap behavior.',
      entry.$2,
    );
  }
  n(
    'interaction.longPressMs',
    'Long press duration',
    'Interaction',
    'Milliseconds before a held pointer emits the long-press callback.',
    500,
    min: 1,
    max: 5000,
    integer: true,
  );
  n(
    'interaction.tapSlop',
    'Tap slop',
    'Interaction',
    'Maximum movement still considered a tap or long press.',
    18,
    max: 128,
  );
  n(
    'interaction.hitTestPadding',
    'Hit test padding',
    'Interaction',
    'Extra hit-testing margin in logical pixels.',
    0,
    max: 64,
  );
  n(
    'interaction.directionalCrossAxisWeight',
    'Keyboard cross-axis weight',
    'Interaction',
    'Penalty for cross-axis distance when arrow keys choose the next node.',
    .35,
    max: 4,
  );
  for (final event in ['tap', 'longPress', 'hover', 'selection']) {
    c(
      'interaction.${event}Callback',
      '${_humanize(event)} callback',
      'Interaction',
      'Registered callback. Log writes to the preview event readout; Snackbar shows a visible message. Hold leaf keeps terminal taps at their focus.',
      'none',
      event == 'tap'
          ? ['none', 'log', 'snackbar', 'holdLeaf']
          : ['none', 'log', 'snackbar'],
    );
  }
  c(
    'interaction.cursor',
    'Pointer cursor',
    'Interaction',
    'Default cursor, click over a node, or precise cursor over a node.',
    'default',
    ['default', 'click', 'precise'],
  );
  b(
    'selection.controlled',
    'Controlled selection',
    'Interaction',
    'The playground supplies the selection set and accepts proposed changes; off delegates ownership to the controller.',
    false,
  );
  b(
    'selection.allowMultiple',
    'Multiple selection',
    'Interaction',
    'Allow taps to accumulate selected nodes.',
    false,
  );
  b(
    'selection.toggleable',
    'Toggle selection',
    'Interaction',
    'A second tap on a selected node removes it.',
    true,
  );
  b(
    'selection.fallbackToNearestAncestor',
    'Selection ancestor fallback',
    'Interaction',
    'Preserve the nearest surviving ancestor when configured controlled selections disappear.',
    false,
  );
  n(
    'selection.maximum',
    'Controller selection limit',
    'Interaction',
    'Maximum programmatic controller selections; Unlimited allows any number.',
    1,
    min: 1,
    max: 10000,
    integer: true,
    nullLabel: 'Unlimited',
  );
  s(
    'selection.initial',
    'Initial selected keys',
    'Interaction',
    'Comma-separated source keys used only when loading a configuration; current selections are temporary and are not shared.',
    '',
  );
  b(
    'tooltip.enabled',
    'Show tooltip',
    'Interaction',
    'Optional presentation layer for pointer/tap details.',
    false,
  );
  c(
    'tooltip.activation',
    'Tooltip activation',
    'Interaction',
    'Hover, tap, or both pointer interactions.',
    'hoverAndTap',
    ['hover', 'tap', 'hoverAndTap'],
  );
  c(
    'tooltip.placement',
    'Tooltip placement',
    'Interaction',
    'Auto chooses available space; explicit placement chooses a side of the target.',
    'auto',
    ['auto', 'above', 'below', 'left', 'right'],
  );
  b(
    'tooltip.fitInside',
    'Keep tooltip inside',
    'Interaction',
    'Clamp tooltip presentation to the viewport.',
    true,
  );
  n(
    'tooltip.hideDelayMs',
    'Tooltip hide delay',
    'Interaction',
    'Milliseconds before a tapped tooltip is hidden.',
    2000,
    max: 10000,
    integer: true,
  );
  n(
    'tooltip.margin',
    'Tooltip margin',
    'Interaction',
    'Distance from the target tile.',
    8,
    max: 64,
  );
  n(
    'tooltip.maxWidth',
    'Tooltip max width',
    'Interaction',
    'Maximum logical-pixel width of the tooltip.',
    280,
    min: 1,
    max: 1000,
  );
  b(
    'tooltip.suppressDuringAnimation',
    'Hide tooltip during animation',
    'Interaction',
    'Suppress a tooltip while geometry is transitioning.',
    true,
  );
  c(
    'tooltip.builder',
    'Tooltip content',
    'Interaction',
    'Registered label/weight text or detail card.',
    'standard',
    ['standard', 'details'],
  );
  c(
    'tooltip.containerBuilder',
    'Tooltip container',
    'Interaction',
    'Standard or rounded theme-aware shell.',
    'standard',
    ['standard', 'rounded'],
  );
  b(
    'semantics.enabled',
    'Chart semantics',
    'Interaction',
    'Expose visible nodes to assistive technology. Canvas tiles alone do not create semantics.',
    false,
  );

  b(
    'animation.enabled',
    'Animate changes',
    'Animation',
    'Enable keyed bounds/opacity transitions for geometry updates.',
    false,
  );
  n(
    'animation.durationMs',
    'Animation duration',
    'Animation',
    'Transition duration in milliseconds; reduced motion overrides it to zero.',
    450,
    max: 5000,
    integer: true,
  );
  c(
    'animation.curve',
    'Animation curve',
    'Animation',
    'Registered interpolation curve for keyed transitions.',
    'easeInOutCubic',
    ['linear', 'easeInOutCubic', 'easeOut', 'fastOutSlowIn'],
  );
  c(
    'environment.theme',
    'Theme',
    'Environment',
    'Light, dark, or the platform theme. Text direction and text scaling affect only the preview.',
    'light',
    ['light', 'dark', 'system'],
  );
  c(
    'environment.direction',
    'Preview text direction',
    'Environment',
    'LTR or RTL for presentation. Layout origin remains independently configurable.',
    'ltr',
    ['ltr', 'rtl'],
  );
  c(
    'environment.locale',
    'Preview locale',
    'Environment',
    'Locale supplied to localized value formatters.',
    'en-US',
    ['en-US', 'de-DE', 'ar'],
  );
  n(
    'environment.textScale',
    'Preview text scale',
    'Environment',
    'Scale chart labels and chrome while keeping the property editor readable.',
    1,
    min: .5,
    max: 3,
  );
  b(
    'environment.reducedMotion',
    'Reduced motion',
    'Environment',
    'Simulate MediaQuery.disableAnimations; configured durations remain stored.',
    false,
  );
  b(
    'environment.accessibleNavigation',
    'Accessible navigation',
    'Environment',
    'Simulate MediaQuery.accessibleNavigation, also suppressing chart animation.',
    false,
  );

  c(
    'preview.mode',
    'Preview mode',
    'Preview',
    'Shared chart or a registered comparison, composition, standalone, validation or isolate demonstration.',
    'chart',
    [
      'chart',
      'sharedTree',
      'originsComparison',
      'axesComparison',
      'categoryCard',
      'opacityCard',
      'standalone',
      'externalLegend',
      'validation',
      'isolate',
    ],
  );
  n(
    'preview.width',
    'Preview width',
    'Preview',
    'Auto fills available width. A fixed logical-pixel width is constrained to the available space.',
    null,
    min: 1,
    max: 2400,
    nullLabel: 'Auto',
  );
  n(
    'preview.height',
    'Preview height',
    'Preview',
    'Auto fills available height. A fixed logical-pixel height is constrained to the available space.',
    null,
    min: 1,
    max: 1600,
    nullLabel: 'Auto',
  );
  n(
    'preview.aspectRatio',
    'Preview aspect ratio',
    'Preview',
    'Optional width-to-height ratio, such as 1 for a square. None uses width/height constraints.',
    null,
    min: .25,
    max: 4,
    nullLabel: 'None',
  );
  c(
    'preview.clip',
    'Chart clipping',
    'Preview',
    'Clipping policy for the chart surface stack.',
    'none',
    clips,
  );
  b(
    'preview.autofocus',
    'Chart autofocus',
    'Preview',
    'Request chart keyboard focus when the preview is first mounted.',
    false,
  );
  b(
    'preview.showHierarchy',
    'Show source hierarchy',
    'Preview',
    'Display the source hierarchy and normalized branch totals beneath a category composition.',
    false,
  );
  b(
    'preview.showPresentation',
    'Show presentation summary',
    'Preview',
    'A scoped readout of chart-owned visible bounds and tile count.',
    false,
  );
  b(
    'labels.ignorePointer',
    'Ignore label pointer input',
    'Labels',
    'Allow chart hit testing through custom label widgets.',
    true,
  );
  c(
    'semantics.labelResolver',
    'Semantics label resolver',
    'Interaction',
    'Use the standard accessible label or the stable source key.',
    'standard',
    ['standard', 'key'],
  );
  c(
    'semantics.valueResolver',
    'Semantics value resolver',
    'Interaction',
    'Use the standard effective weight or report geometry depth.',
    'standard',
    ['standard', 'depth'],
  );
  c(
    'semantics.hintResolver',
    'Semantics hint resolver',
    'Interaction',
    'Use standard navigation hints or the complete ancestor path.',
    'standard',
    ['standard', 'path'],
  );
  n(
    'labels.titleHeight',
    'Title line height',
    'Labels',
    'Line height multiplier for title text.',
    1.15,
    min: .5,
    max: 3,
  );
  n(
    'labels.valueHeight',
    'Value line height',
    'Labels',
    'Line height multiplier for value text.',
    1.15,
    min: .5,
    max: 3,
  );
  n(
    'labels.colorOpacity',
    'Resolved text opacity',
    'Labels',
    'Opacity of the label color resolver before value opacity is applied.',
    1,
    max: 1,
  );
  return List.unmodifiable(fields);
}

String? propertyDisabledReason(String key, PlaygroundConfig config) {
  final scale = config.text('color.scale');
  final mode = config.text('preview.mode');
  if (key == 'data.revision' &&
      ![
        'markets',
        'color-domain',
        'many-nodes',
      ].contains(config.text('data'))) {
    return 'Data revisions update Markets, Color domain, and Generated nodes.';
  }
  if (key == 'color.domainScope' &&
      (mode == 'standalone' ||
          config.optionalNumber('color.minimum') != null &&
              config.optionalNumber('color.maximum') != null)) {
    return mode == 'standalone'
        ? 'Standalone resolution uses the dataset leaf values.'
        : 'Domain scope is used when at least one bound is Auto.';
  }
  if (key.startsWith('legend.') && ['validation', 'isolate'].contains(mode)) {
    return 'This preview mode does not render a legend.';
  }
  if (key.startsWith('breadcrumbs.') &&
      ['validation', 'isolate'].contains(mode)) {
    return 'This preview mode has no chart navigation.';
  }
  if (key == 'color.mappings' && scale != 'exact') {
    return 'Used by the Exact color scale.';
  }
  if (key == 'color.ranges' && scale != 'numericRange') {
    return 'Used by the Numeric range scale.';
  }
  if (key == 'color.labels' && scale != 'categorical') {
    return 'Used by the Categorical scale.';
  }
  if (key.startsWith('color.') &&
      (key.contains('Saturation') || key == 'color.saturationHue') &&
      scale != 'saturation') {
    return 'Used by the Saturation scale.';
  }
  if (key == 'color.formatter' &&
      !['interpolated', 'saturation'].contains(scale)) {
    return 'Continuous scales format their numeric legend stops.';
  }
  if (key == 'color.palette' &&
      !['categorical', 'interpolated'].contains(scale) &&
      [
        'normal',
        'hover',
        'selected',
        'focused',
      ].every((state) => config.text('tiles.$state.gradient') == 'none')) {
    return 'Used by categorical/interpolated scales and tile gradients.';
  }
  if (key == 'layout.origin' &&
      config.text('preview.mode') == 'originsComparison') {
    return 'The comparison varies this property across its four charts.';
  }
  if (key == 'layout.axisOrder' &&
      config.text('preview.mode') == 'axesComparison') {
    return 'The comparison varies this property across its two charts.';
  }
  if ((key == 'tiles.maximumNodes' || key == 'tiles.ignorePointer') &&
      !['widgets', 'composite'].contains(config.text('tiles.renderer'))) {
    return 'Used by widget and composite tile renderers.';
  }
  if (key.startsWith('labels.') &&
      key != 'labels.renderer' &&
      config.text('labels.renderer') == 'none') {
    return 'Enable a label renderer to use this property.';
  }
  if ([
        'labels.widgetBuilder',
        'labels.maximumNodes',
        'labels.minimumWidth',
        'labels.minimumHeight',
        'labels.clip',
        'labels.ignorePointer',
      ].contains(key) &&
      config.text('labels.renderer') != 'widgets') {
    return 'Used by the Widget label renderer.';
  }
  if (key == 'labels.linesBuilder' &&
      config.text('labels.renderer') != 'canvas') {
    return 'Used by the Canvas label renderer.';
  }
  if (key == 'labels.ellipsis' && config.text('labels.renderer') != 'canvas') {
    return 'Custom ellipsis text is used by the Canvas label renderer.';
  }
  if (['labels.valueFormatter', 'labels.weightFractionDigits'].contains(key) &&
      config.text('labels.localizedFormatter') != 'none') {
    return 'The localized formatter supplies the displayed values.';
  }
  if (key.startsWith('legend.') &&
      key != 'legend.enabled' &&
      !config.flag('legend.enabled')) {
    return 'Enable the legend to use this property.';
  }
  final discreteLegend =
      config.text('legend.kind') == 'discrete' ||
      config.text('legend.kind') == 'auto' &&
          !['interpolated', 'saturation'].contains(scale) &&
          mode != 'opacityCard';
  if (discreteLegend &&
      ([
            'legend.segmented',
            'legend.showLabels',
            'legend.sampleCount',
            'legend.pointerExtent',
            'legend.barBuilder',
            'legend.pointerBuilder',
          ].contains(key) ||
          key.startsWith('legend.horizontal') ||
          key.startsWith('legend.vertical'))) {
    return 'Used by color bar legends.';
  }
  if (!discreteLegend &&
      [
        'legend.itemBuilder',
        'legend.runSpacing',
        'legend.overflow',
      ].contains(key)) {
    return 'Used by discrete legends.';
  }
  if (key.startsWith('legend.horizontal') &&
          config.text('legend.direction') != 'horizontal' ||
      key.startsWith('legend.vertical') &&
          config.text('legend.direction') != 'vertical') {
    return 'Used by the corresponding legend direction.';
  }
  if (key.startsWith('breadcrumbs.') &&
      key != 'breadcrumbs.enabled' &&
      !config.flag('breadcrumbs.enabled')) {
    return 'Enable breadcrumbs to use this property.';
  }
  if ([
        'breadcrumbs.ellipsisMaximumChildren',
        'breadcrumbs.overflowIndicator',
      ].contains(key) &&
      config.text('breadcrumbs.overflow') != 'ellipsis') {
    return 'Used when breadcrumb overflow is Ellipsis.';
  }
  if (key == 'breadcrumbs.separatorText' &&
      config.text('breadcrumbs.separatorBuilder') != 'text') {
    return 'Used by the Text separator builder.';
  }
  if (key.startsWith('tooltip.') &&
      key != 'tooltip.enabled' &&
      !config.flag('tooltip.enabled')) {
    return 'Enable tooltips to use this property.';
  }
  if (key.startsWith('semantics.') &&
      key != 'semantics.enabled' &&
      !config.flag('semantics.enabled')) {
    return 'Enable chart semantics to use this property.';
  }
  if (key.startsWith('animation.') &&
      key != 'animation.enabled' &&
      !config.flag('animation.enabled')) {
    return 'Enable animation to use this property.';
  }
  if (key == 'preview.showHierarchy' &&
      config.text('preview.mode') != 'categoryCard') {
    return 'Used by the Category card preview mode.';
  }
  return null;
}
