import 'dart:math' as math;

import 'package:any_treemap/any_treemap.dart';
import 'package:flutter/material.dart';

import 'composition.dart';
import 'config.dart';
import 'datasets.dart';

typedef PlaygroundLayoutRunner =
    Future<TreemapGeometrySnapshot<String>> Function(
      TreemapNode<String> root,
      TreemapBounds viewport,
      TreemapLayoutConfig<String> config,
    );

Set<TreemapKey<String>> initialSelection(PlaygroundConfig config) => config
    .text('selection.initial')
    .split(',')
    .where((key) => key.trim().isNotEmpty)
    .map((key) => TreemapKey<String>.source(key.trim()))
    .toSet();

class PlaygroundPreview extends StatefulWidget {
  const PlaygroundPreview({
    super.key,
    required this.config,
    this.resetGeneration = 0,
    this.onPropertyChange,
    this.showToolbar = true,
    this.layoutRunner,
  });
  final PlaygroundConfig config;
  final int resetGeneration;
  final void Function(String, Object?)? onPropertyChange;
  final bool showToolbar;
  final PlaygroundLayoutRunner? layoutRunner;
  @override
  State<PlaygroundPreview> createState() => _PlaygroundPreviewState();
}

class _PlaygroundPreviewState extends State<PlaygroundPreview> {
  late TreemapController<String> _controller;
  late TreemapNode<String> _root;
  PlaygroundComposition? _composition;
  String? _dataError;
  Set<TreemapKey<String>> _selection = {};
  final _output = ValueNotifier<TreemapPresentationState<String>?>(null);
  String? _lastEvent;
  int _chartGeneration = 0;
  int _navigationResetGeneration = 0;
  int _executionGeneration = 0;
  bool _running = false;
  TreemapGeometrySnapshot<String>? _computed;
  String? _executionError;

  @override
  void initState() {
    super.initState();
    _root = createData(widget.config);
    _materialize();
    _installController();
  }

  void _materialize() {
    _composition = null;
    _dataError = null;
    try {
      TreemapNormalizer.normalize(_root);
      _composition = PlaygroundComposition(widget.config, _root);
    } catch (error) {
      _dataError = error.toString();
    }
  }

  void _installController() {
    _controller = TreemapController(
      maximumSelections: widget.config
          .optionalNumber('selection.maximum')
          ?.toInt(),
    );
    if (_dataError == null) _controller.synchronize(_root, notify: false);
    _selection = initialSelection(widget.config);
    _controller.setSelection(_selection);
    _controller.addListener(_onNavigation);
  }

  void _onNavigation() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PlaygroundPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reset = widget.resetGeneration != oldWidget.resetGeneration;
    final dataChanged =
        widget.config.dataSignature != oldWidget.config.dataSignature;
    final selectionLimitChanged =
        widget.config.optionalNumber('selection.maximum') !=
        oldWidget.config.optionalNumber('selection.maximum');
    if (dataChanged) _root = createData(widget.config);
    if (widget.config != oldWidget.config) {
      _materialize();
      _executionGeneration++;
      _computed = null;
      _executionError = null;
      _running = false;
    }
    if (reset || selectionLimitChanged) {
      final oldFocus = reset ? null : _controller.focusKey?.sourceKey;
      final oldSelected = reset ? null : _controller.selectedEntries;
      _controller.removeListener(_onNavigation);
      _controller.dispose();
      _installController();
      if (oldFocus != null) _controller.zoomTo(oldFocus);
      if (oldSelected != null) {
        _controller.setSelection(oldSelected);
        _selection = _controller.selectedEntries.toSet();
      }
      _chartGeneration++;
      _lastEvent = null;
      _output.value = null;
    } else if (dataChanged && _dataError == null) {
      final tree = TreemapNormalizer.normalize(_root);
      _selection = _selection
          .where((key) => key.isSource && tree.nodes.containsKey(key.sourceKey))
          .toSet();
      _controller.synchronize(_root, notify: false);
    }
    if (widget.config.text('selection.initial') !=
        oldWidget.config.text('selection.initial')) {
      _selection = initialSelection(widget.config);
      _controller.setSelection(_selection);
    } else if (widget.config.flag('selection.controlled') &&
        !oldWidget.config.flag('selection.controlled')) {
      _selection = _controller.selectedEntries.toSet();
    }
  }

  @override
  void dispose() {
    _executionGeneration++;
    _controller.removeListener(_onNavigation);
    _controller.dispose();
    _output.dispose();
    super.dispose();
  }

  void _event(String mode, String message) {
    if (mode == 'none' || mode == 'holdLeaf') return;
    setState(() => _lastEvent = message);
    if (mode == 'snackbar') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _select(Set<TreemapKey<String>> keys) {
    if (widget.config.flag('selection.controlled')) {
      setState(() => _selection = keys);
    }
  }

  Widget _chart(
    PlaygroundComposition composition, {
    bool external = false,
    Widget? customTopEnd,
  }) => composition.chart(
    key: ValueKey(_chartGeneration),
    controller: _controller,
    selection: _selection,
    onSelection: _select,
    onEvent: _event,
    omitLegend: external || customTopEnd != null,
    customTopEnd: customTopEnd,
    onPresentation: external
        ? (state) {
            if (mounted) _output.value = state;
          }
        : null,
  );

  Widget _legend(PlaygroundComposition composition) => ValueListenableBuilder(
    valueListenable: _output,
    builder: (context, state, _) => TreemapLegendView<String>(
      scale: state == null
          ? composition.scale.resolveDomain(const [])
          : composition.scale,
      presentation: state,
      config: composition.legendConfig,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final localeParts = config.text('environment.locale').split('-');
    Widget preview = LayoutBuilder(
      builder: (context, constraints) {
        var width = math.min(
          config.optionalNumber('preview.width') ?? constraints.maxWidth,
          constraints.maxWidth,
        );
        var height = math.min(
          config.optionalNumber('preview.height') ?? constraints.maxHeight,
          constraints.maxHeight,
        );
        final ratio = config.optionalNumber('preview.aspectRatio');
        if (ratio != null) {
          width = math.min(width, height * ratio);
          height = width / ratio;
        }
        if (config.text('preview.mode') == 'categoryCard') {
          width = math.min(width, 440);
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: _dataError != null
                ? _message('Invalid data', _dataError!)
                : _content(_composition!),
          ),
        );
      },
    );
    preview = Localizations.override(
      context: context,
      locale: Locale(
        localeParts.first,
        localeParts.length > 1 ? localeParts.last : null,
      ),
      child: Directionality(
        textDirection: named(
          TextDirection.values,
          config.text('environment.direction'),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              config.number('environment.textScale'),
            ),
            disableAnimations: config.flag('environment.reducedMotion'),
            accessibleNavigation: config.flag(
              'environment.accessibleNavigation',
            ),
          ),
          child: preview,
        ),
      ),
    );
    return Column(
      children: [
        if (widget.showToolbar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('preview-back'),
                  tooltip: 'Back one level',
                  onPressed: _controller.canZoomOut
                      ? _controller.zoomOut
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  key: const ValueKey('preview-reset'),
                  tooltip: 'Reset chart navigation',
                  onPressed: _dataError == null
                      ? () {
                          _controller.reset();
                          _controller.clearSelection();
                          setState(() {
                            _selection = {};
                            _navigationResetGeneration++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.home_outlined),
                ),
                if (widget.onPropertyChange != null)
                  IconButton(
                    tooltip: 'Update data revision',
                    onPressed:
                        propertiesByKey['data.revision']!.enabled(config) &&
                            config.number('data.revision') <
                                propertiesByKey['data.revision']!.maximum!
                        ? () => widget.onPropertyChange!(
                            'data.revision',
                            config.integer('data.revision') + 1.0,
                          )
                        : null,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(widget.showToolbar ? 16 : 0),
            child: RepaintBoundary(
              key: const ValueKey('playground-chart-preview'),
              child: preview,
            ),
          ),
        ),
        if (_lastEvent != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _lastEvent!,
              key: const ValueKey('preview-event'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _content(PlaygroundComposition composition) {
    final mode = widget.config.text('preview.mode');
    if (mode == 'validation') {
      return _message(
        'Valid data',
        'The current dataset passes normalization. Select Invalid weight to inspect the typed error.',
      );
    }
    if (mode == 'isolate') return _isolate(composition);
    if (mode == 'originsComparison' || mode == 'axesComparison') {
      final options = mode == 'originsComparison' ? origins : axes;
      final property = mode == 'originsComparison'
          ? 'layout.origin'
          : 'layout.axisOrder';
      return Column(
        children: [
          for (var row = 0; row < (options.length / 2).ceil(); row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < 2; column++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ComparisonPane(
                          key: ValueKey(options[row * 2 + column]),
                          root: _root,
                          config: widget.config.withValues({
                            property: options[row * 2 + column],
                          }),
                          caption: options[row * 2 + column],
                          resetGeneration: widget.resetGeneration,
                          navigationResetGeneration: _navigationResetGeneration,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
    if (mode == 'standalone') {
      return Column(
        children: [
          if (widget.config.flag('legend.enabled'))
            TreemapLegendView<String>(
              scale: composition.scale,
              config: composition.legendConfig,
            ),
          Expanded(child: _chart(composition, external: true)),
        ],
      );
    }
    if (mode == 'externalLegend') {
      return Column(
        children: [
          Expanded(child: _chart(composition, external: true)),
          if (widget.config.flag('legend.enabled')) _legend(composition),
        ],
      );
    }
    if (mode == 'categoryCard') {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _chart(composition)),
                if (widget.config.flag('preview.showHierarchy') &&
                    constraints.maxHeight >= 80) ...[
                  const Divider(),
                  SizedBox(
                    height: math.min(180, constraints.maxHeight * .4),
                    child: SingleChildScrollView(child: _hierarchy(_root)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    if (mode == 'opacityCard') {
      return _chart(
        composition,
        customTopEnd: !widget.config.flag('legend.enabled')
            ? null
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in [
                      ('Blue', blueOpacityPalette),
                      ('Pink', pinkOpacityPalette),
                    ])
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: TreemapLegendView<String>(
                          scale: TreemapColorScale.interpolated(
                            minimum: 0,
                            maximum: 1,
                            colors: entry.$2,
                            fallback: entry.$2.last,
                            labelFormatter: (value) =>
                                '${(100 - value * 80).round()}%',
                          ),
                          config: composition.legendConfig.copyWith(
                            title: entry.$1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
    }
    // The error policy is deliberate. Validate against the actual viewport
    // before mounting a child LayoutBuilder that could throw asynchronously.
    if (widget.config.text('layout.insufficientSpacePolicy') == 'error') {
      return LayoutBuilder(
        builder: (context, constraints) {
          try {
            TreemapLayoutEngine<String>().layout(
              root: _root,
              viewport: TreemapBounds.fromLTWH(
                0,
                0,
                constraints.maxWidth,
                constraints.maxHeight,
              ),
              config: composition.layout,
              focus: _controller.layoutFocus,
            );
          } catch (error) {
            return _message('Layout error', error.toString());
          }
          return _chart(composition);
        },
      );
    }
    return _chart(composition);
  }

  Widget _hierarchy(TreemapNode<String> root) {
    final totals = TreemapNormalizer.normalize(root).totals;
    Widget row(TreemapNode<String> node, int depth) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(depth * 16.0, 5, 0, 5),
          child: Row(
            children: [
              Expanded(child: Text(node.label ?? node.key)),
              Text(totals[node.key]!.round().toString()),
            ],
          ),
        ),
        for (final child in node.children) row(child, depth + 1),
      ],
    );
    return row(root, 0);
  }

  Future<void> _runLayout(PlaygroundComposition composition) async {
    final generation = ++_executionGeneration;
    setState(() {
      _running = true;
      _executionError = null;
      _computed = null;
    });
    try {
      final viewport = TreemapBounds.fromLTWH(
        0,
        0,
        widget.config.optionalNumber('preview.width') ?? 1600,
        widget.config.optionalNumber('preview.height') ?? 900,
      );
      final result =
          await (widget.layoutRunner?.call(
                _root,
                viewport,
                composition.layout,
              ) ??
              TreemapLayoutEngine<String>().layoutAsync(
                root: _root,
                viewport: viewport,
                config: composition.layout,
              ));
      if (!mounted || generation != _executionGeneration) return;
      setState(() {
        _computed = result;
        _running = false;
      });
    } catch (error) {
      if (!mounted || generation != _executionGeneration) return;
      setState(() {
        _executionError = error.toString();
        _running = false;
      });
    }
  }

  Widget _isolate(PlaygroundComposition composition) => Column(
    children: [
      FilledButton.icon(
        key: const ValueKey('run-isolate'),
        onPressed: _running ? null : () => _runLayout(composition),
        icon: const Icon(Icons.play_arrow),
        label: Text(_running ? 'Computing…' : 'Run layout'),
      ),
      const SizedBox(height: 12),
      if (_running) const LinearProgressIndicator(),
      if (_computed != null)
        Text('Computed ${_computed!.nodes.length} geometry nodes.'),
      Expanded(
        child: _executionError != null
            ? _message('Execution error', _executionError!)
            : _computed == null
            ? const Center(child: Text('Run layout to inspect the result.'))
            : FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _computed!.viewport.width,
                  height: _computed!.viewport.height,
                  child: ComputedSnapshotView(
                    root: _root,
                    snapshot: _computed!,
                    composition: composition,
                  ),
                ),
              ),
      ),
    ],
  );
  Widget _message(String title, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SelectionArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

class ComparisonPane extends StatefulWidget {
  const ComparisonPane({
    super.key,
    required this.root,
    required this.config,
    required this.caption,
    required this.resetGeneration,
    this.navigationResetGeneration = 0,
  });
  final TreemapNode<String> root;
  final PlaygroundConfig config;
  final String caption;
  final int resetGeneration;
  final int navigationResetGeneration;
  @override
  State<ComparisonPane> createState() => _ComparisonPaneState();
}

class _ComparisonPaneState extends State<ComparisonPane> {
  late TreemapController<String> _controller;
  Set<TreemapKey<String>> _selection = {};
  @override
  void initState() {
    super.initState();
    _install();
  }

  void _install() {
    _controller = TreemapController(
      maximumSelections: widget.config
          .optionalNumber('selection.maximum')
          ?.toInt(),
    )..synchronize(widget.root, notify: false);
    _selection = initialSelection(widget.config);
    _controller.setSelection(_selection);
    _controller.addListener(_navigationChanged);
  }

  void _navigationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ComparisonPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetGeneration != oldWidget.resetGeneration ||
        widget.config.optionalNumber('selection.maximum') !=
            oldWidget.config.optionalNumber('selection.maximum')) {
      final reset = widget.resetGeneration != oldWidget.resetGeneration;
      final focus = reset ? null : _controller.focusKey?.sourceKey;
      final selected = reset ? null : _controller.selectedEntries;
      _controller.removeListener(_navigationChanged);
      _controller.dispose();
      _install();
      if (focus != null) _controller.zoomTo(focus);
      if (selected != null) {
        _controller.setSelection(selected);
        _selection = _controller.selectedEntries.toSet();
      }
    }
    if (widget.navigationResetGeneration !=
        oldWidget.navigationResetGeneration) {
      _controller.reset();
      _controller.clearSelection();
      _selection = {};
    } else if (widget.config.text('selection.initial') !=
        oldWidget.config.text('selection.initial')) {
      _selection = initialSelection(widget.config);
      _controller.setSelection(_selection);
    } else if (widget.config.flag('selection.controlled') &&
        !oldWidget.config.flag('selection.controlled')) {
      _selection = _controller.selectedEntries.toSet();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_navigationChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composition = PlaygroundComposition(widget.config, widget.root);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(widget.caption, overflow: TextOverflow.ellipsis),
              ),
              if (_controller.canZoomOut)
                IconButton(
                  tooltip: 'Back in ${widget.caption}',
                  onPressed: _controller.zoomOut,
                  icon: const Icon(Icons.arrow_back, size: 16),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chart = composition.chart(
                controller: _controller,
                selection: _selection,
                onSelection: (value) => setState(() => _selection = value),
                onEvent: (_, _) {},
              );
              return widget.config.text('preview.mode') == 'axesComparison'
                  ? Center(
                      child: SizedBox.square(
                        dimension: math.min(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        child: chart,
                      ),
                    )
                  : chart;
            },
          ),
        ),
      ],
    );
  }
}

class ComputedSnapshotView extends StatelessWidget {
  const ComputedSnapshotView({
    super.key,
    required this.root,
    required this.snapshot,
    required this.composition,
  });
  final TreemapNode<String> root;
  final TreemapGeometrySnapshot<String> snapshot;
  final PlaygroundComposition composition;
  @override
  Widget build(BuildContext context) {
    return _ComputedLayers(
      root: root,
      snapshot: snapshot,
      composition: composition,
    );
  }
}

class _ComputedLayers extends StatefulWidget {
  const _ComputedLayers({
    required this.root,
    required this.snapshot,
    required this.composition,
  });
  final TreemapNode<String> root;
  final TreemapGeometrySnapshot<String> snapshot;
  final PlaygroundComposition composition;
  @override
  State<_ComputedLayers> createState() => _ComputedLayersState();
}

class _ComputedLayersState extends State<_ComputedLayers> {
  final _controller = TreemapController<String>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = TreemapPresentationState.fromData(
      root: widget.root,
      targetSnapshot: widget.snapshot,
    );
    final visual = TreemapVisualContext<String>(
      snapshot: widget.snapshot,
      presentation: state,
      details: {
        for (final node in widget.snapshot.nodes)
          node.key: TreemapNodeDetails(
            geometry: node,
            path: widget.snapshot.path,
          ),
      },
      states: const {},
      controller: _controller,
      selection: const {},
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      isAnimating: false,
      onActivate: (_) {},
      onFocus: (_) {},
    );
    return Stack(
      children: [
        Positioned.fill(child: widget.composition.tiles.build(context, visual)),
        if (widget.composition.labels case final labels?)
          Positioned.fill(child: labels.build(context, visual)),
      ],
    );
  }
}
