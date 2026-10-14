import 'package:flutter/foundation.dart';

import 'config.dart';
import 'location.dart';
import 'presets.dart';
import 'padding_values.dart';

enum HistoryIntent { replace, push }

/// UI events update configuration; routing and preview only consume it.
final class PlaygroundStore extends ChangeNotifier {
  PlaygroundStore({PlaygroundLocation? initial}) {
    _location = initial ?? PlaygroundLocationCodec.decode(Uri(path: '/'));
    _preview = _location.config;
  }
  late PlaygroundLocation _location;
  late PlaygroundConfig _preview;
  final _drafts = <String, Object?>{};
  final _rawDrafts = <String, String>{};
  final _paddingDrafts = <String, String>{};
  final _errors = <String, String>{};
  int resetGeneration = 0;
  int formGeneration = 0;
  HistoryIntent historyIntent = HistoryIntent.replace;

  PlaygroundLocation get location => _location;
  PlaygroundConfig get committed => _location.config;
  PlaygroundConfig get preview => _preview;
  String? get exampleKey => _location.exampleKey;
  Map<String, String> get errors => Map.unmodifiable(_errors);
  String? rawDraft(String key) => _rawDrafts[key];
  String? paddingDraft(String prefix) => _paddingDrafts[prefix];
  bool get hasDrafts => _rawDrafts.isNotEmpty || _paddingDrafts.isNotEmpty;

  void draftPadding(String prefix, String raw) {
    for (final key in paddingKeys(prefix)) {
      _rawDrafts.remove(key);
    }
    _paddingDrafts[prefix] = raw;
    _rebuildDrafts();
    historyIntent = HistoryIntent.replace;
    notifyListeners();
  }

  void commitPadding(String prefix) {
    final keys = paddingKeys(prefix);
    if (_errors.containsKey(prefix) || !keys.every(_drafts.containsKey)) return;
    _commitDrafts({for (final key in keys) key: _drafts[key]});
  }

  void restore(PlaygroundLocation value) {
    _location = value;
    _clearDrafts();
    resetGeneration++;
    formGeneration++;
    historyIntent = HistoryIntent.replace;
    notifyListeners();
  }

  void selectPreset(String key) {
    final preset = presetsByKey[key]!;
    final changed = key != exampleKey || preset.config != committed;
    _location = PlaygroundLocation(
      config: preset.config,
      exampleKey: key,
      path: _location.path,
    );
    _clearDrafts();
    resetGeneration++;
    formGeneration++;
    historyIntent = changed ? HistoryIntent.push : HistoryIntent.replace;
    notifyListeners();
  }

  void draftRaw(String key, String raw) {
    _rawDrafts[key] = raw;
    _rebuildDrafts();
    historyIntent = HistoryIntent.replace;
    notifyListeners();
  }

  void draft(String key, Object? value) => draftRaw(
    key,
    propertiesByKey[key]!.encodeValue(
      propertiesByKey[key]!.editor == PropertyEditor.number && value is num
          ? value.toDouble()
          : value,
    ),
  );

  void change(String key, Object? value) {
    draft(key, value);
    commitField(key);
  }

  void commitField(String key) {
    if (_errors.containsKey(key) || !_drafts.containsKey(key)) return;
    final edits = {key: _drafts[key]};
    try {
      committed.withValues(edits);
    } on FormatException {
      // A bound can require its paired draft to make a valid interval.
      final related = switch (key) {
        'color.minimum' ||
        'color.maximum' => ['color.minimum', 'color.maximum'],
        'color.minimumSaturation' || 'color.maximumSaturation' => [
          'color.minimumSaturation',
          'color.maximumSaturation',
        ],
        _ => <String>[],
      };
      for (final other in related) {
        if (_drafts.containsKey(other)) edits[other] = _drafts[other];
      }
    }
    _commitDrafts(edits);
  }

  void _rebuildDrafts() {
    _errors.clear();
    _drafts.clear();
    final candidates = <String, Object?>{};
    for (final entry in _rawDrafts.entries) {
      try {
        candidates[entry.key] = propertiesByKey[entry.key]!.parse(entry.value);
      } catch (error) {
        _errors[entry.key] = error is FormatException
            ? error.message
            : 'Invalid value.';
      }
    }
    for (final entry in _paddingDrafts.entries) {
      try {
        final field = propertiesByKey['${entry.key}.left']!;
        final values = parsePaddingValues(
          entry.value,
          minimum: field.minimum!.toInt(),
          maximum: field.maximum!.toInt(),
        );
        final keys = paddingKeys(entry.key);
        for (var i = 0; i < keys.length; i++) {
          candidates[keys[i]] = values[i].toDouble();
        }
      } on FormatException catch (error) {
        _errors[entry.key] = error.message;
      }
    }
    try {
      _preview = committed.withValues(candidates);
      _drafts.addAll(candidates);
    } catch (_) {
      // Keep independent valid edits while marking cross-field conflicts.
      _preview = committed;
      for (final entry in candidates.entries) {
        try {
          _preview = _preview.withValues({entry.key: entry.value});
          _drafts[entry.key] = entry.value;
        } catch (error) {
          _errors[entry.key] = error is FormatException
              ? error.message
              : 'Invalid value.';
        }
      }
    }
  }

  /// Copy link includes valid drafts while leaving invalid fields visibly invalid.
  void commitValidDrafts() {
    if (_drafts.isEmpty) return;
    _commitDrafts(Map.of(_drafts));
  }

  void _commitDrafts(Map<String, Object?> edits) {
    final next = committed.withValues(edits);
    for (final key in edits.keys) {
      _rawDrafts.remove(key);
    }
    _paddingDrafts.removeWhere(
      (prefix, _) => paddingKeys(prefix).every(edits.containsKey),
    );
    _commit(next);
  }

  void _commit(PlaygroundConfig next) {
    if (next == committed) {
      _rebuildDrafts();
      historyIntent = HistoryIntent.replace;
      notifyListeners();
      return;
    }
    if (next.text('data') != committed.text('data') ||
        next.text('data.singleChildPolicy') !=
            committed.text('data.singleChildPolicy')) {
      resetGeneration++;
    }
    _location = PlaygroundLocation(config: next, path: _location.path);
    _rebuildDrafts();
    historyIntent = HistoryIntent.push;
    notifyListeners();
  }

  void dismissNotices() {
    _location = PlaygroundLocation(
      config: committed,
      exampleKey: exampleKey,
      path: _location.path,
    );
    historyIntent = HistoryIntent.replace;
    notifyListeners();
  }

  void _clearDrafts() {
    _drafts.clear();
    _rawDrafts.clear();
    _paddingDrafts.clear();
    _errors.clear();
    _preview = committed;
  }
}
