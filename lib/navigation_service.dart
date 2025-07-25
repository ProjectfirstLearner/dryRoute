
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'weather_service.dart';
import 'models/route_data.dart';

class NavigationService extends ChangeNotifier {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isNavigating = false;
  RouteData? _currentRoute;
  LatLng? _currentLocation;
  Timer? _trackingTimer;
  Timer? _weatherCheckTimer;
  List<LatLng> _routeSegments = [];
  int _currentSegmentIndex = 0;

  bool get isNavigating => _isNavigating;
  RouteData? get currentRoute => _currentRoute;
  LatLng? get currentLocation => _currentLocation;
  int get currentSegmentIndex => _currentSegmentIndex;
  List<LatLng> get routeSegments => _routeSegments;

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
          requestCriticalPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);
    
    // Kritische Benachrichtigungen für iOS anfordern
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
  }

  Future<void> startNavigation(RouteData route) async {
    _isNavigating = true;
    _currentRoute = route;
    _routeSegments = _segmentizeRoute(route.polylinePoints, segmentLength: 500); // 500m Segmente
    _currentSegmentIndex = 0;
    
    // Standort-Tracking starten
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateCurrentLocation();
    });
    
    // Wetter-Check starten
    _weatherCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkWeatherOnRoute();
    });
    
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentRoute = null;
    _routeSegments.clear();
    _currentSegmentIndex = 0;
    
    _trackingTimer?.cancel();
    _weatherCheckTimer?.cancel();
    
    notifyListeners();
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      
      // Prüfen ob nächstes Segment erreicht wurde
      _updateCurrentSegment();
      
      notifyListeners();
    } catch (e) {
      print('Fehler beim Standort-Update: $e');
    }
  }

  void _updateCurrentSegment() {
    if (_currentLocation == null || _routeSegments.isEmpty) return;
    
    const Distance distance = Distance();
    
    // Nächstes Segment finden
    for (int i = _currentSegmentIndex; i < _routeSegments.length; i++) {
      final distanceToSegment = distance.as(
        LengthUnit.Meter,
        _currentLocation!,
        _routeSegments[i],
      );
      
      if (distanceToSegment < 50) { // 50m Toleranz
        _currentSegmentIndex = i;
        break;
      }
    }
  }

  Future<void> _checkWeatherOnRoute() async {
    if (!_isNavigating || _currentLocation == null || _routeSegments.isEmpty) return;
    
    try {
      final weatherService = WeatherService();
      
      // Kommende Segmente der Route prüfen (nächste 5 Minuten / ~1km)
      final upcomingSegments = _getUpcomingSegments(distance: 1000);
      
      for (final segment in upcomingSegments) {
        final weather = await weatherService.getMinutelyForecast(segment);
        
        if (weather != null && weather.willRainSoon) {
          final timeToRain = weather.timeToRain;
          
          if (timeToRain != null && timeToRain <= const Duration(minutes: 5)) {
            await _showRainWarning(timeToRain, segment);
            break; // Nur eine Warnung zur Zeit
          }
        }
      }
    } catch (e) {
      print('Fehler beim Wetter-Check: $e');
    }
  }

  List<LatLng> _getUpcomingSegments({required double distance}) {
    if (_routeSegments.isEmpty || _currentLocation == null) return [];
    
    const Distance distanceCalc = Distance();
    final List<LatLng> upcoming = [];
    double accumulatedDistance = 0;
    
    for (int i = _currentSegmentIndex; i < _routeSegments.length; i++) {
      if (i > _currentSegmentIndex) {
        accumulatedDistance += distanceCalc.as(
          LengthUnit.Meter,
          _routeSegments[i - 1],
          _routeSegments[i],
        );
      }
      
      upcoming.add(_routeSegments[i]);
      
      if (accumulatedDistance >= distance) break;
    }
    
    return upcoming;
  }

  Future<void> _showRainWarning(Duration timeToRain, LatLng location) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'weather_warnings',
      'Wetter Warnungen',
      channelDescription: 'Benachrichtigungen über anstehenden Regen',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final minutes = timeToRain.inMinutes;
    final message = minutes > 0 
        ? 'Regen in $minutes Minuten auf Ihrer Route erwartet!'
        : 'Regen auf Ihrer Route - suchen Sie Schutz!';

    await _notifications.show(
      0,
      'Regen-Warnung',
      message,
      platformChannelSpecifics,
    );
  }

  List<LatLng> _segmentizeRoute(List<LatLng> route, {required double segmentLength}) {
    if (route.length < 2) return route;
    
    const Distance distance = Distance();
    final List<LatLng> segments = [route.first];
    
    double accumulatedDistance = 0;
    
    for (int i = 1; i < route.length; i++) {
      final segmentDistance = distance.as(
        LengthUnit.Meter,
        route[i - 1],
        route[i],
      );
      
      accumulatedDistance += segmentDistance;
      
      if (accumulatedDistance >= segmentLength) {
        segments.add(route[i]);
        accumulatedDistance = 0;
      }
    }
    
    // Letzten Punkt hinzufügen falls nicht bereits vorhanden
    if (segments.last != route.last) {
      segments.add(route.last);
    }
    
    return segments;
  }
}
