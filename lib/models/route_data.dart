import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> polylinePoints;
  final double totalDistance; // in Metern
  final Duration estimatedDuration;
  final String startAddress;
  final String endAddress;
  final LatLng startPoint;
  final LatLng endPoint;
  final DateTime createdAt;

  // Additional properties for compatibility
  final LatLng? start;
  final LatLng? end;
  final List<LatLng> route;
  final List<LatLng> shelters;
  final bool isLoading;
  final String? error;
  final double? distanceInMeters;
  final double? durationInSeconds;

  const RouteData({
    required this.polylinePoints,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.startAddress,
    required this.endAddress,
    required this.startPoint,
    required this.endPoint,
    required this.createdAt,
    // Optional compatibility parameters
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
    List<LatLng>? polylinePoints,
    double? totalDistance,
    Duration? estimatedDuration,
    String? startAddress,
    String? endAddress,
    LatLng? startPoint,
    LatLng? endPoint,
    DateTime? createdAt,
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
      polylinePoints: polylinePoints ?? this.polylinePoints,
      totalDistance: totalDistance ?? this.totalDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      createdAt: createdAt ?? this.createdAt,
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

  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.round()} m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    final hours = estimatedDuration.inHours;
    final minutes = estimatedDuration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  @override
  String toString() {
    return 'RouteData(distance: $formattedDistance, duration: $formattedDuration, points: ${polylinePoints.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteData &&
        other.startPoint == startPoint &&
        other.endPoint == endPoint &&
        other.totalDistance == totalDistance;
  }

  @override
  int get hashCode {
    return Object.hash(startPoint, endPoint, totalDistance);
  }
}
