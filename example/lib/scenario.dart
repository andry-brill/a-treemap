import 'package:flutter/widgets.dart';

final class ExampleScenario {
  const ExampleScenario({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.builder,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final WidgetBuilder builder;
}
