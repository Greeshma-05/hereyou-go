import 'package:latlong2/latlong.dart';
import '../models/category.dart';
import '../models/vendor_model.dart';

const mockVendors = [
  Vendor(
    id: 'cafe',
    name: 'The Travellers’ Kitchen',
    category: Category.food,
    position: LatLng(9.9772, 76.2890),
    area: 'KSRTC bus stand',
    preparationMinutes: 15,
    rating: 4.8,
    description:
        'Comfort food, Kerala favourites and a little fuel for the road.',
  ),
  Vendor(
    id: 'pharmacy',
    name: 'Green Cross Pharmacy',
    category: Category.medicine,
    position: LatLng(9.9722, 76.2922),
    area: 'Ernakulam Junction',
    preparationMinutes: 10,
    rating: 4.7,
    description: 'A sample pharmacy catalog. Availability is not verified.',
  ),
  Vendor(
    id: 'daily',
    name: 'Everyday Essentials',
    category: Category.hygiene,
    position: LatLng(9.9810, 76.2868),
    area: 'MG Road',
    preparationMinutes: 8,
    rating: 4.6,
    description: 'The small things that make your journey more comfortable.',
  ),
  Vendor(
    id: 'baby',
    name: 'Little Steps',
    category: Category.baby,
    position: LatLng(9.9890, 76.2875),
    area: 'Ernakulam Town',
    preparationMinutes: 12,
    rating: 4.9,
    description: 'Everyday care for your littlest travel companion.',
  ),
  Vendor(
    id: 'travel',
    name: 'Onward Travel Store',
    category: Category.travel,
    position: LatLng(9.9680, 76.2940),
    area: 'South railway station',
    preparationMinutes: 10,
    rating: 4.5,
    available: false,
    description:
        'Travel accessories and everyday necessities. Currently closed.',
  ),
];
