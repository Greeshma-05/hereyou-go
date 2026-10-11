class RouteStop {
  const RouteStop(this.name, this.detail, {this.latitude, this.longitude});
  final String name;
  final String detail;
  final double? latitude;
  final double? longitude;
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
}
