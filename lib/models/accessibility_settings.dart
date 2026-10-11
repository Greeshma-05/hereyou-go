enum AppColorTheme { lime, blueAmber, highContrast }

enum ReadingSize {
  standard(1),
  large(1.15),
  extraLarge(1.3);

  const ReadingSize(this.factor);
  final double factor;
}
