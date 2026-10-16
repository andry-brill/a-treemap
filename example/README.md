# any_treemap playground

Run `flutter run -d chrome` from this directory. The editor has a 360-pixel property panel on desktop and a Properties drawer below 900 pixels. The preview remains bounded and centered. Choose an example, select shared data, then edit individual settings. Search finds properties by label, key, or help text.

Inner spacing defaults to `0`, matching `TreemapLayoutConfig`. Presets inherit
this value unless they explicitly override `layout.innerSpacing`.

Outer, level, label and surrounding padding each use one input. Enter whole
numbers from 0 to 256: `5` applies to every side, `5,10` means horizontal 5 and
vertical 10, and `1,2,3,4` means left, top, right and bottom. The slider changes
all four sides together and is disabled for unequal values or invalid drafts.
Equal sides display as one value after committing the edit. Text commits on
Enter or blur; slider drags commit on release. Shared links retain the existing
four side parameters and support fractional values supplied through URLs;
new padding input uses whole numbers.

## Shared links

- `?example=appearance-auto-visible` loads a complete preset, including its dataset.
- Changing a property removes `example` and writes every setting, including defaults and inactive values. Every custom URL includes `data=dataset-key`.
- Choosing another example replaces all settings. Custom settings are not automatically matched back to a preset.
- Values use readable enum names, `true`/`false`, ARGB hex, `auto` for automatic bounds, and `none` for other optional values. Palettes, ranges, exact maps, and rule rows use compact URI-encoded JSON.
- A mixed URL applies an example first and explicit properties second, then becomes a complete custom URL. Missing fields use shared defaults. Unknown/invalid input produces a dismissible notice and is replaced with valid defaults; repeated parameters use their last value.
- Browser Back/Forward restores committed edits. Typing and dragging preview valid values immediately, then commit once on Enter, blur, or drag completion. Copy link commits valid pending edits and leaves invalid drafts visibly invalid.
- Chart focus, current selection, hover, and tooltips are temporary. Initial selection is a configured property, not a snapshot of current interaction. Example/data selection and history restoration reset chart interaction.
- **Data → Single-child branches** chooses `preserve` (default) or `promote`, serialized as `data.singleChildPolicy`. Promote removes intermediate parents before preparation completes, retains child metadata and the root, and changes paths and depths. Changing this policy resets chart interaction. Try `?example=data-single-child-promotion`; `appearance-auto-saturation` also enables promotion.

URLs use ordinary query parameters on the current application path. For hosting under a prefix, build with `flutter build web --base-href /playground/` and serve that directory at `/playground/`. Keep the trailing slash. No server-side route rewriting is required when using the same application path with different query strings.

## Adding coverage

The shared implementation lives in `lib/playground`:

- `config.dart` and `properties.dart` define immutable configuration, typed property descriptors, field validation, applicable controls, and wire values.
- `datasets.dart` owns stable datasets, source constructors, generators, grouping, and color-input transformations. Source data is rebuilt only when data properties change.
- `composition.dart` translates configuration into library objects and registered builders/strategies. `preview.dart` owns temporary chart interaction and the specialized preview modes. It keeps immutable chart output separate from the navigation controller.
- `location.dart`, `store.dart`, and `router.dart` separate URL parsing, edit drafts/commits, and browser history. Browser canonicalization replaces the current entry; a completed edit pushes one entry.
- `page.dart`, `property_editor.dart`, `structured_editor.dart`, and `inputs.dart` render the common editor. New properties need one descriptor and a corresponding composition binding.

Presets stay grouped in `lib/scenarios/*.dart`. Each `ExamplePreset` supplies its existing stable ID, title, concise description, dataset key, and configuration overrides. It does not build an independent page. Update `FEATURES.md` exactly once for each preset. Registered custom implementations must be chosen through configuration so a customized URL remains reproducible without an example ID.

## Validation

Run `flutter analyze`, `flutter test`, and `flutter build web` here, plus package analysis/tests at the repository root. Tests cover all 68 presets, configuration/URL round trips, draft validation, browser route restoration, responsive/help UI, interaction/state ownership, and chart goldens. The existing example golden images moved into `test/goldens` without changing their baselines.

CI runs only on `windows-latest` with Flutter **3.47.3**. All package and example
goldens use Flutter's standard pixel-exact comparator with **zero tolerance**;
there are no per-platform or per-image allowances. Generate and review baselines
on Windows with the same Flutter version. Inspect failure images before updating
a baseline. Full playground snapshots retain their configured canvas/widget
styles to cover contrast, opacity and state overrides.

Prepared source data is retained by the data signature. Styling and layout edits
reuse it; dataset or single-child-policy changes prepare a new immutable tree. The `data-prepared-tree`
preset shares one tree between two independently interactive charts. Custom
presentation controls use keyed chart actions, and external views consume the
same immutable presentation published after the frame.

Typography lives under Labels: `labels.titleSize/valueSize` set the base, and
`labels.hover.titleSize/valueSize`, `labels.selected.titleSize/valueSize`, and
`labels.focused.titleSize/valueSize` set rendering overrides. `labels.nodeStyle`
selects a final per-node override. Previous `tiles.<state>.titleSize/valueSize`
links show unknown-property notices; use the new keys. Automatic parent headers
always use base typography, including when switching canvas/widget renderers.

Every custom `TreemapLabelLayer` implements `resolveParentHeaderHeight(context)`
directly. `ConfiguredWidgetLabels` delegates to its configured widget label layer
before geometry is computed; custom layers without reserved headers return
`null`. `layout-parent-headers` demonstrates this sizing contract across canvas
and widget renderers, including text scaling and independent parent visibility.

`appearance-shared-tile-labels` demonstrates shared background contrast across
canvas, widget and composite tile renderers. `appearance-label-fallback` uses
invisible tiles declaring a white background source while painting nothing
(the existing scenario URL is retained). Canvas labels receive only label
configuration; all background sources belong to tile layers, including invisible
ones. Every custom `TreemapTileLayer` implements its nullable `appearance` getter
directly; wrappers can forward their delegate's source. Composite layers name
their source explicitly. Return `null` only when no shared background is needed.
