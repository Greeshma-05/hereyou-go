enum Category {
  food('Food & Drinks', 'Food'),
  medicine('Medicines', 'Medicines'),
  hygiene('Hygiene', 'Hygiene'),
  baby('Baby Care', 'Baby'),
  travel('Travel Essentials', 'Travel');

  const Category(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}
