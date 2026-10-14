import 'playground/config.dart';

final class ExamplePreset {
  ExamplePreset({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.dataKey,
    this.overrides = const {},
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String dataKey;
  final Map<String, Object?> overrides;
  late final PlaygroundConfig config = PlaygroundConfig.fromOverrides({
    'data': dataKey,
    ...overrides,
  });
}
