import 'package:latlong2/latlong.dart';

enum JourneyMode { bus, train }

class PickupStop {
  const PickupStop(this.id, this.name, this.position, this.instructions);
  factory PickupStop.custom({
    required JourneyMode mode,
    required String name,
    required LatLng position,
    required String instructions,
  }) => PickupStop(
    'custom-${mode.name}',
    name.trim(),
    position,
    instructions.trim(),
  );
  final String id;
  final String name;
  final LatLng position;
  final String instructions;

  bool get isCustom => id == 'custom-bus' || id == 'custom-train';
  bool get isValid =>
      id.trim().isNotEmpty &&
      id.length <= 120 &&
      name.trim().isNotEmpty &&
      name.length <= 160 &&
      instructions.trim().isNotEmpty &&
      instructions.length <= 1000 &&
      position.latitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude.isFinite &&
      position.longitude >= -180 &&
      position.longitude <= 180;
}

class Journey {
  const Journey({
    required this.mode,
    required this.operatorName,
    required this.boarding,
    required this.destination,
    required this.departure,
    required this.pickup,
  });
  final JourneyMode mode;
  final String operatorName;
  final String boarding;
  final String destination;
  final DateTime departure;
  final PickupStop pickup;

  bool get isValid =>
      operatorName.trim().isNotEmpty &&
      operatorName.length <= 120 &&
      boarding.trim().isNotEmpty &&
      boarding.length <= 120 &&
      destination.trim().isNotEmpty &&
      destination.length <= 120 &&
      boarding.trim().toLowerCase() != destination.trim().toLowerCase() &&
      pickup.isValid;
}

class SavedJourney {
  const SavedJourney({
    required this.id,
    required this.journey,
    required this.savedAt,
  });
  final String id;
  final Journey journey;
  final DateTime savedAt;
}
