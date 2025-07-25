import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';

class WeatherData {
  final bool willRainSoon;
  final Duration? timeToRain;
  final double? intensity;
  final String description;

  WeatherData({
    required this.willRainSoon,
    this.timeToRain,
    this.intensity,
    required this.description,
  });
}

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  String get _apiKey => dotenv.env['OWM_API_KEY'] ?? '';

  static Future<bool> willRainAt({
    required LatLng point,
    required DateTime eta,
  }) async {
    final owmApiKey = dotenv.env['OWM_API_KEY'];
    
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/forecast?lat=${point.latitude}&lon=${point.longitude}&appid=$owmApiKey&units=metric&lang=de',
    );
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List forecasts = data['list'];
      // Finde das Forecast-Objekt, das der ETA am nächsten ist
      forecasts.sort((a, b) => (a['dt'] as int).compareTo(b['dt'] as int));
      final etaTimestamp = eta.millisecondsSinceEpoch ~/ 1000;
      final forecast = forecasts.reduce((a, b) =>
        (a['dt'] - etaTimestamp).abs() < (b['dt'] - etaTimestamp).abs() ? a : b);
      final rain = forecast['rain'] ?? {};
      return rain.isNotEmpty;
    } else {
      throw Exception('Fehler beim Abrufen der Wetterdaten: ${response.body}');
    }
  }

  /// Minutely Forecast für genaue Regenvorhersage der nächsten Stunde
  Future<WeatherData?> getMinutelyForecast(LatLng location) async {
    if (_apiKey.isEmpty) {
      print('OpenWeatherMap API Key nicht gefunden');
      return null;
    }

    try {
      final url = Uri.parse('$_baseUrl/onecall')
          .replace(queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'appid': _apiKey,
        'exclude': 'daily,alerts',
        'units': 'metric',
        'lang': 'de',
      });

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherData(data);
      }
    } catch (e) {
      print('Wetter-API Fehler: $e');
    }
    return null;
  }

  WeatherData _parseWeatherData(Map<String, dynamic> data) {
    // Prüfe minutely Daten für die nächste Stunde
    final minutely = data['minutely'] as List<dynamic>?;
    if (minutely != null && minutely.isNotEmpty) {
      return _analyzeMinutelyData(minutely);
    }

    // Fallback auf hourly Daten
    final hourly = data['hourly'] as List<dynamic>?;
    if (hourly != null && hourly.isNotEmpty) {
      return _analyzeHourlyData(hourly);
    }

    // Fallback auf current weather
    final current = data['current'];
    final hasRain = current['rain'] != null;
    
    return WeatherData(
      willRainSoon: hasRain,
      description: hasRain ? 'Aktuell regnet es' : 'Kein Regen erwartet',
    );
  }

  WeatherData _analyzeMinutelyData(List<dynamic> minutely) {
    double maxIntensity = 0.0;
    int? minutesToRain;
    
    for (int i = 0; i < minutely.length; i++) {
      final precipitation = (minutely[i]['precipitation'] as num?)?.toDouble() ?? 0.0;
      
      if (precipitation > 0 && minutesToRain == null) {
        minutesToRain = i;
      }
      
      maxIntensity = math.max(maxIntensity, precipitation);
    }

    final willRain = maxIntensity > 0.1; // 0.1mm/h threshold
    
    return WeatherData(
      willRainSoon: willRain,
      timeToRain: minutesToRain != null ? Duration(minutes: minutesToRain) : null,
      intensity: maxIntensity,
      description: _generateDescription(willRain, minutesToRain, maxIntensity),
    );
  }

  WeatherData _analyzeHourlyData(List<dynamic> hourly) {
    final nextHour = hourly.first;
    final hasRain = nextHour['rain'] != null;
    final intensity = (nextHour['rain']?['1h'] as num?)?.toDouble() ?? 0.0;
    
    return WeatherData(
      willRainSoon: hasRain && intensity > 0.1,
      intensity: intensity,
      description: hasRain 
          ? 'Regen in der nächsten Stunde erwartet'
          : 'Kein Regen in der nächsten Stunde',
    );
  }

  String _generateDescription(bool willRain, int? minutesToRain, double intensity) {
    if (!willRain) {
      return 'Kein Regen in der nächsten Stunde erwartet';
    }

    if (minutesToRain != null) {
      if (minutesToRain == 0) {
        return 'Regen setzt gerade ein';
      } else if (minutesToRain <= 5) {
        return 'Regen in ca. $minutesToRain Minuten';
      } else if (minutesToRain <= 15) {
        return 'Regen in ca. $minutesToRain Minuten';
      } else {
        return 'Regen in ca. $minutesToRain Minuten';
      }
    }

    if (intensity > 2.5) {
      return 'Starker Regen erwartet';
    } else if (intensity > 0.5) {
      return 'Mäßiger Regen erwartet';
    } else {
      return 'Leichter Regen erwartet';
    }
  }

  /// Prüft ob es regnen wird, wenn man am Ziel ankommt
  Future<bool> willRainAtETA(LatLng destination, Duration travelTime) async {
    final eta = DateTime.now().add(travelTime);
    return await WeatherService.willRainAt(point: destination, eta: eta);
  }

  /// Einfache Wetterinfo für einen Ort
  Future<String> getWeatherDescription(LatLng location) async {
    final weatherData = await getMinutelyForecast(location);
    return weatherData?.description ?? 'Wetterdaten nicht verfügbar';
  }
}
