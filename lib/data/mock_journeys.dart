import 'package:latlong2/latlong.dart';
import '../models/journey_model.dart';

// Fixed Kochi demonstration points. No live transit or routing integration.
const kochiCenter = LatLng(9.9755, 76.2880);
const busStops = [
  PickupStop(
    'ksrtc',
    'Ernakulam KSRTC bus stand',
    LatLng(9.9785, 76.2910),
    'Meet at the main entrance beside the enquiry counter. Confirm the safe meeting point before handover.',
  ),
  PickupStop(
    'vyttila',
    'Vyttila Mobility Hub',
    LatLng(9.9671, 76.3214),
    'Meet near the public information desk. Stay in the designated pedestrian area.',
  ),
];
const trainStops = [
  PickupStop(
    'south',
    'Ernakulam Junction',
    LatLng(9.9685, 76.2913),
    'Handover is outside the station main entrance. No platform or onboard delivery is provided.',
  ),
  PickupStop(
    'north',
    'Ernakulam Town',
    LatLng(9.9914, 76.2864),
    'Meet outside the station main entrance. Railway integration is not connected.',
  ),
];
const demoRoute = [
  LatLng(9.9685, 76.2913),
  LatLng(9.9720, 76.2915),
  LatLng(9.9785, 76.2910),
  LatLng(9.9814, 76.2890),
  LatLng(9.9870, 76.2870),
  LatLng(9.9914, 76.2864),
];
