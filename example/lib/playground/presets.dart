import '../scenario.dart';
import '../scenarios/accessibility.dart';
import '../scenarios/appearance.dart';
import '../scenarios/data.dart';
import '../scenarios/interaction.dart';
import '../scenarios/layout.dart';

final allPresets = List<ExamplePreset>.unmodifiable([
  ...dataScenarios,
  ...layoutScenarios,
  ...appearanceScenarios,
  ...interactionScenarios,
  ...accessibilityScenarios,
]);
final presetsByKey = {for (final preset in allPresets) preset.id: preset};
const defaultPresetKey = 'data-explicit-tree';
