import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../painters/centered_text_painter.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';
import '../presentation/label_placement.dart';
import 'centered_content.dart';

final _lineBreaks = RegExp(r'[\r\n\u0085\u2028\u2029]');

/// Single-line canvas text scaled using one shared template measurement.
///
/// Compose over standard tiles with `TreemapCompositeTileLayer`. Each deepest
/// visible block receives the same reference text box, centered and uniformly
/// scaled to its allocation. Collapsed parents and aggregates are included.
///
/// The complete [template] defines the reference width; no character count is
/// needed. Narrower strings are centered by [TextAlign.center]. Text that exceeds
/// this budget is clipped/truncated to one line without ellipsis. Choose a
/// template that accommodates the expected alphabet, including fallback fonts.
///
/// [TextStyle.fontSize] is ignored. Typography is normalized once to an internal
/// reference size, with an enforced line height. Canvas scaling determines the
/// displayed size independently of inherited text scaling. There is no wrapping
/// or per-string font fitting.
///
/// Template metrics and distinct text painters are retained in widget state,
/// including when this layer is recreated. Geometry-only updates change the
/// allocation and canvas transform without laying text out again. Changing the
/// template, style, locale, direction or loaded fonts invalidates the cache.
/// Unused painters are disposed when their text leaves the visible content.
final class TreemapCenteredTextLayer<K> implements TreemapTileLayer<K> {
  const TreemapCenteredTextLayer.fixed({
    required this.template,
    required this.textBuilder,
    this.style = const TextStyle(color: Color(0xFFFFFFFF)),
    this.widthFactor = 1,
    this.heightFactor = 1,
    this.aspect,
    this.minimumSize,
    this.region = TreemapContentRegion.available,
    this.appearance,
  }) : assert(template.length > 0),
       assert(widthFactor >= 0 && widthFactor <= 1),
       assert(heightFactor >= 0 && heightFactor <= 1),
       assert(aspect == null || (aspect > 0 && aspect < double.infinity));

  /// Complete nonempty, single-line sizing reference, for example `W` or `WWW`.
  final String template;

  /// Called for nonempty allocations that meet [minimumSize], before painting.
  /// Return an empty string to omit content. Returned text must be single-line.
  final TreemapStatefulNodeTextBuilder<K> textBuilder;

  /// Shared typography and paint. Its font size is ignored; other dimensions,
  /// including letter spacing and shadows, scale with the canvas transform.
  final TextStyle style;
  final double widthFactor;
  final double heightFactor;

  /// Available space by default; [TreemapContentRegion.tile] ignores labels.
  final TreemapContentRegion region;

  /// Optional width-to-height ratio fitted after the independent factors.
  final double? aspect;

  /// Skip content if either final dimension is below its minimum; equality
  /// passes. Null disables the cutoff. Tile layout and visibility are unchanged.
  /// Finite, nonnegative dimensions are asserted at build time to retain const
  /// construction, just as for `TreemapCenteredWidgetLayer`.
  final Size? minimumSize;

  /// Optional background declaration for labels; this layer paints no fill.
  @override
  final TreemapAppearanceResolver<K>? appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      _CenteredText<K>(
        layer: this,
        visual: visual,
        locale: Localizations.maybeLocaleOf(context),
      );
}

class _CenteredText<K> extends StatefulWidget {
  const _CenteredText({
    required this.layer,
    required this.visual,
    required this.locale,
  });
  final TreemapCenteredTextLayer<K> layer;
  final TreemapVisualContext<K> visual;
  final Locale? locale;

  @override
  State<_CenteredText<K>> createState() => _CenteredTextState<K>();
}

class _CenteredTextState<K> extends State<_CenteredText<K>> {
  static const _referenceFontSize = 64.0;
  final _painters = <String, TextPainter>{};
  TextPainter? _reference;
  late TextStyle _sourceStyle;
  late TextStyle _style;
  late StrutStyle _strut;
  late String _template;
  late TextDirection _direction;
  Locale? _locale;
  late Size _referenceSize;
  late Offset _paintOffset;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _clear() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
    _reference?.dispose();
    _reference = null;
  }

  void _fontsChanged() => setState(_clear);

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _clear();
    super.dispose();
  }

  void _prepare() {
    final layer = widget.layer;
    final direction = widget.visual.textDirection;
    if (_reference != null &&
        layer.template == _template &&
        layer.style == _sourceStyle &&
        direction == _direction &&
        widget.locale == _locale) {
      return;
    }
    _clear();
    _sourceStyle = layer.style;
    _style = layer.style.copyWith(fontSize: _referenceFontSize);
    _strut = StrutStyle.fromTextStyle(_style, forceStrutHeight: true);
    _template = layer.template;
    _direction = direction;
    _locale = widget.locale;
    _reference = _createPainter(_template)..layout();
    _referenceSize = _reference!.size;
    _paintOffset = Offset(
      -_referenceSize.width / 2,
      -_referenceSize.height / 2,
    );
  }

  TextPainter _createPainter(String text) {
    assert(
      !text.contains(_lineBreaks),
      'Centered fixed text and its template must be single-line.',
    );
    return TextPainter(
      text: TextSpan(text: text, style: _style),
      textAlign: TextAlign.center,
      textDirection: _direction,
      textScaler: TextScaler.noScaling,
      strutStyle: _strut,
      locale: _locale,
      maxLines: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    _prepare();
    final layer = widget.layer;
    final minimum = layer.minimumSize;
    assert(
      minimum == null ||
          (minimum.width.isFinite &&
              minimum.width >= 0 &&
              minimum.height.isFinite &&
              minimum.height >= 0),
      'minimumSize dimensions must be finite and nonnegative.',
    );
    final visual = widget.visual;
    final entries = <TreemapCenteredTextPaintEntry<K>>[];
    final used = <String>{};
    for (final node in visual.presentation.visibleLeafNodes) {
      final bounds = visual.contentBoundsFor(node.key, region: layer.region);
      final size = resolveCenteredContentSize(
        bounds.size,
        widthFactor: layer.widthFactor,
        heightFactor: layer.heightFactor,
        aspect: layer.aspect,
        minimumSize: layer.minimumSize,
      );
      if (size == null ||
          _referenceSize.isEmpty ||
          !_referenceSize.width.isFinite ||
          !_referenceSize.height.isFinite) {
        continue;
      }
      final text = layer.textBuilder(
        context,
        visual.presentation.details[node.key]!,
        visual.presentation.statesFor(node.key),
      );
      if (text.isEmpty) continue;
      used.add(text);
      final painter = text == _template
          ? _reference!
          : _painters.putIfAbsent(
              text,
              () => _createPainter(text)
                ..layout(
                  minWidth: _referenceSize.width,
                  maxWidth: _referenceSize.width,
                ),
            );
      entries.add((
        key: node.key,
        bounds: Rect.fromCenter(
          center: bounds.center,
          width: size.width,
          height: size.height,
        ),
        scale: math.min(
          size.width / _referenceSize.width,
          size.height / _referenceSize.height,
        ),
        painter: painter,
      ));
    }
    for (final text in _painters.keys.toList(growable: false)) {
      if (!used.contains(text)) _painters.remove(text)!.dispose();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: TreemapCenteredTextPainter<K>(
          entries: entries,
          referenceSize: _referenceSize,
          paintOffset: _paintOffset,
        ),
      ),
    );
  }
}
