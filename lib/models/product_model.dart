import 'category.dart';

class Product {
  const Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.category,
    required this.pricePaise,
    required this.stock,
    required this.unit,
    required this.description,
    this.strength,
    this.dosageForm,
    this.genericName = '',
    this.brand = '',
    this.manufacturer = '',
    this.expiryDate = '',
    this.prescriptionRequired = false,
    this.published = true,
  });
  final String id;
  final String vendorId;
  final String name;
  final Category category;
  // Integer paise avoids floating-point rounding errors at checkout.
  final int pricePaise;
  final int stock;
  final String unit;
  final String description;
  final String? strength;
  final String? dosageForm;
  final String genericName;
  final String brand;
  final String manufacturer;
  final String expiryDate;
  final bool prescriptionRequired;
  final bool published;
  bool get expired =>
      expiryDate.isNotEmpty &&
      DateTime.parse('$expiryDate 23:59:59').isBefore(DateTime.now());
}
