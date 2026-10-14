import 'package:flutter/material.dart';

import 'config.dart';

class PropertyHelp extends StatefulWidget {
  const PropertyHelp({super.key, required this.label, required this.message});
  final String label;
  final String message;
  @override
  State<PropertyHelp> createState() => _PropertyHelpState();
}

class _PropertyHelpState extends State<PropertyHelp> {
  final _tooltip = GlobalKey<TooltipState>();
  void _show() => _tooltip.currentState?.ensureTooltipVisible();
  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltip,
    message: widget.message,
    excludeFromSemantics: true,
    waitDuration: const Duration(milliseconds: 300),
    showDuration: const Duration(seconds: 8),
    constraints: const BoxConstraints(maxWidth: 320),
    child: Focus(
      onFocusChange: (focused) {
        if (focused) _show();
      },
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.all(6),
        iconSize: 16,
        onPressed: _show,
        icon: Icon(Icons.info_outline, semanticLabel: 'About ${widget.label}'),
      ),
    ),
  );
}

/// Keeps incomplete text local while the schema validates preview drafts.
class CommitInput extends StatefulWidget {
  const CommitInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    this.label,
    this.error,
    this.enabled = true,
    this.numeric = false,
    this.fieldKey,
    this.semanticLabel,
    this.prefix,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;
  final String? label;
  final String? error;
  final bool enabled;
  final bool numeric;
  final Key? fieldKey;
  final String? semanticLabel;
  final String? prefix;
  @override
  State<CommitInput> createState() => _CommitInputState();
}

class _CommitInputState extends State<CommitInput> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.value);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus.hasFocus) widget.onCommit();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CommitInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    child: TextField(
      key: widget.fieldKey,
      controller: _text,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      onChanged: widget.onChanged,
      onSubmitted: (_) {
        widget.onCommit();
        _focus.unfocus();
      },
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.error,
        prefixText: widget.prefix,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
    ),
  );
}

Future<Color?> chooseColor(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a color'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in [
                Colors.blue,
                Colors.red,
                Colors.indigo,
                Colors.teal,
                Colors.orange,
                Colors.pink,
                Colors.amber,
                Colors.cyan,
                Colors.green,
                Colors.deepPurple,
                Colors.white,
                Colors.black,
                Colors.grey,
                Colors.transparent,
              ])
                Semantics(
                  label: colorHex(color),
                  button: true,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, color),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: color.toARGB32() == initial.toARGB32()
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > .4
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

class ColorInput extends StatelessWidget {
  const ColorInput({
    super.key,
    required this.raw,
    required this.onChanged,
    required this.onCommit,
    required this.onPicked,
    this.error,
    this.enabled = true,
    this.fieldKey,
    this.semanticLabel,
  });
  final String raw;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;
  final ValueChanged<Color> onPicked;
  final String? error;
  final bool enabled;
  final Key? fieldKey;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    Color? color;
    try {
      color = parseColor(raw);
    } catch (_) {}
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CommitInput(
            value: raw,
            fieldKey: fieldKey,
            onChanged: onChanged,
            onCommit: onCommit,
            error: error,
            enabled: enabled,
            prefix: '#',
            semanticLabel: semanticLabel,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          height: 42,
          child: IconButton.filledTonal(
            tooltip: 'Choose color',
            onPressed: enabled
                ? () async {
                    final picked = await chooseColor(
                      context,
                      color ?? Colors.blue,
                    );
                    if (picked != null) onPicked(picked);
                  }
                : null,
            icon: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
