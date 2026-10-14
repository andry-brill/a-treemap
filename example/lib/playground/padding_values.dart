const paddingSides = ['left', 'top', 'right', 'bottom'];

List<String> paddingKeys(String prefix) => [
  for (final side in paddingSides) '$prefix.$side',
];

/// Expands whole-number input into left, top, right, bottom values.
List<int> parsePaddingValues(String raw, {int minimum = 0, int maximum = 256}) {
  final parts = raw.split(',').map((part) => part.trim()).toList();
  final values = <int>[];
  for (final part in parts) {
    final value = RegExp(r'^\d+$').hasMatch(part) ? int.tryParse(part) : null;
    if (value == null || value < minimum || value > maximum) {
      throw FormatException(
        'Use 1, 2 or 4 whole numbers from $minimum to $maximum.',
      );
    }
    values.add(value);
  }
  return switch (values.length) {
    1 => List.filled(4, values.single),
    2 => [values[0], values[1], values[0], values[1]],
    4 => values,
    _ => throw const FormatException('Use 1, 2 or 4 comma-separated values.'),
  };
}

/// Uses the shortest lossless form, including existing fractional URL values.
String formatPaddingValues(List<double> values) {
  String number(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');
  if (values.every((value) => value == values.first)) {
    return number(values.first);
  }
  if (values[0] == values[2] && values[1] == values[3]) {
    return '${number(values[0])},${number(values[1])}';
  }
  return values.map(number).join(',');
}
