import 'package:latlong2/latlong.dart';
import 'category.dart';

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.area,
    required this.preparationMinutes,
    required this.rating,
    this.available = true,
    required this.description,
    this.isSample = true,
    this.published = true,
  });
  final String id;
  final String name;
  final Category category;
  final LatLng position;
  final String area;
  final int preparationMinutes;
  final double rating;
  final bool available;
  final String description;
  final bool isSample;
  final bool published;
}
