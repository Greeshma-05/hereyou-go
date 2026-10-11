abstract final class DemoFormat {
  static String money(int paise) =>
      '₹${(paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2)}';
  static String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
