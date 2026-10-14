import 'package:flutter/material.dart';

/// Compact padding input with one slider for equal values on all four sides.
class PaddingInput extends StatefulWidget {
  const PaddingInput({
    super.key,
    required this.raw,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    required this.label,
    this.error,
    this.enabled = true,
    this.minimum = 0,
    this.maximum = 256,
    this.fieldKey,
    this.sliderKey,
  });

  final String raw;
  final EdgeInsets value;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;
  final String label;
  final String? error;
  final bool enabled;
  final int minimum;
  final int maximum;
  final Key? fieldKey;
  final Key? sliderKey;

  @override
  State<PaddingInput> createState() => _PaddingInputState();
}

class _PaddingInputState extends State<PaddingInput> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.raw);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus.hasFocus && !_dragging) widget.onCommit();
      });
    }
  }

  @override
  void didUpdateWidget(covariant PaddingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!_focus.hasFocus || _dragging) && _text.text != widget.raw) {
      _text.text = widget.raw;
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
  Widget build(BuildContext context) {
    final value = widget.value;
    final uniform =
        value.left == value.top &&
        value.left == value.right &&
        value.left == value.bottom;
    final sliderEnabled = widget.enabled && widget.error == null && uniform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: widget.label,
          child: TextField(
            key: widget.fieldKey,
            controller: _text,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 13),
            onChanged: widget.onChanged,
            onSubmitted: (_) {
              widget.onCommit();
              _focus.unfocus();
            },
            decoration: InputDecoration(
              hintText: '5 or 5,10 or 5,10,15,20',
              errorText: widget.error,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
          ),
        ),
        Tooltip(
          message: widget.error != null
              ? 'Enter valid padding to enable the slider.'
              : uniform
              ? 'Adjust all four sides together.'
              : 'The slider is available when all four sides are equal.',
          child: Slider(
            key: widget.sliderKey,
            value: value.left.clamp(
              widget.minimum.toDouble(),
              widget.maximum.toDouble(),
            ),
            min: widget.minimum.toDouble(),
            max: widget.maximum.toDouble(),
            divisions: widget.maximum - widget.minimum,
            label: value.left.round().toString(),
            semanticFormatterCallback: (value) => uniform
                ? '${value.toString().replaceFirst(RegExp(r'\.0$'), '')} on all sides'
                : 'Unequal padding; slider disabled',
            onChangeStart: sliderEnabled
                ? (_) {
                    _dragging = true;
                    _focus.unfocus();
                  }
                : null,
            onChanged: sliderEnabled
                ? (value) => widget.onChanged(value.round().toString())
                : null,
            onChangeEnd: sliderEnabled
                ? (_) {
                    widget.onCommit();
                    _dragging = false;
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
