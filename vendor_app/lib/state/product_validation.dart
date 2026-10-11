int? priceInPaise(String value) {
  final clean = value.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(clean)) return null;
  final parts = clean.split('.');
  final paise =
      int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  return paise > 0 && paise <= 10000000 ? paise : null;
}

String? expiryError(
  String? value, {
  required bool required,
  bool allowPast = false,
}) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) return required ? 'Enter the expiry date.' : null;
  final date = DateTime.tryParse(s);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
      date == null ||
      date.toIso8601String().substring(0, 10) != s) {
    return 'Use a valid date: YYYY-MM-DD.';
  }
  final now = DateTime.now();
  if (!allowPast && date.isBefore(DateTime(now.year, now.month, now.day))) {
    return 'Expired products cannot be published.';
  }
  return null;
}
