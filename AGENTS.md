# Contributor notes

## Example coverage

Keep the runnable feature catalog aligned with the public API.

- Add at least one runnable example scenario for every new public feature. Add separate scenarios when variants have materially different behavior.
- Define scenarios in the matching `example/lib/scenarios/*.dart` file with a unique, stable ID, a concise title, a group, and a useful description.
- Descriptions should explain what the scenario demonstrates, cite concrete input or configuration values where helpful, and tell the reader what interaction or result to observe.
- Add or update the matching row in `example/FEATURES.md`. Every catalog scenario should appear exactly once in that matrix.
- Preserve representative coverage for data construction and errors; all layout algorithms, sorting, origins, axis orders, multilevel rules, aggregation, and custom strategies; all color scales and legends; builders and visual states; selection, tooltips, navigation, updates, and pointer modes; and keyboard, RTL, text, theme, locale, reduced-motion, and isolate behavior.
- Keep examples focused: one scenario may cover closely related behavior, but its title and description must make that coverage explicit.

Before completing an example or public-API change, run `flutter analyze`, `flutter test`, and `flutter build web` from `example` when the catalog UI changed.
