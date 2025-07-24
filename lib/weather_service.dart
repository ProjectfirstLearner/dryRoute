import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';

// Liest den OWM-API-Key aus der .env-Datei
final owmApiKey = dotenv.env['OWM_API_KEY'];

class WeatherService {
  static Future<bool> willRainAt({
    required LatLng point,
    required DateTime eta,
  }) async {
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
}
