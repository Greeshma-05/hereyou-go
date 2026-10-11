import 'package:intl/intl.dart';

String money(int paise) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: paise % 100 == 0 ? 0 : 2,
).format(paise / 100);
String dateLabel(DateTime date) => DateFormat('d MMM yyyy').format(date);
String timeLabel(DateTime date) => DateFormat('h:mm a').format(date);
String? requiredField(String? value) => value == null || value.trim().isEmpty
    ? 'Please complete this field.'
    : null;
String? contactError(String? value) {
  final text = value?.trim() ?? '';
  if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text) ||
      RegExp(r'^\+?[0-9][0-9\s-]{8,14}[0-9]$').hasMatch(text)) {
    return null;
  }
  return 'Enter a valid email or phone number.';
}

String? emailError(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter a valid email address.';
