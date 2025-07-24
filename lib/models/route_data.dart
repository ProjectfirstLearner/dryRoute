
import 'package:latlong2/latlong.dart';

class RouteData {
  final LatLng? start;
  final LatLng? end;
  final List<LatLng> route;
  final List<LatLng> shelters;
  final bool isLoading;
  final String? error;
  final double? distanceInMeters;
  final double? durationInSeconds;

  const RouteData({
    this.start,
    this.end,
    this.route = const [],
    this.shelters = const [],
    this.isLoading = false,
    this.error,
    this.distanceInMeters,
    this.durationInSeconds,
  });

  RouteData copyWith({
    LatLng? start,
    LatLng? end,
    List<LatLng>? route,
    List<LatLng>? shelters,
    bool? isLoading,
    String? error,
    double? distanceInMeters,
    double? durationInSeconds,
  }) {
    return RouteData(
      start: start ?? this.start,
      end: end ?? this.end,
      route: route ?? this.route,
      shelters: shelters ?? this.shelters,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    );
  }
}
