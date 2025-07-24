
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Radar-Provider-Auswahl und Overlay-Steuerung
final radarOverlayProvider = StateProvider<bool>((ref) => true);
final radarTimestampProvider = StateProvider<String>((ref) => '');

/// Provider für aktuelle Radar-Zeitstempel von RainViewer
final radarTimestampsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final response = await http.get(
      Uri.parse('https://api.rainviewer.com/public/weather-maps.json'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final radar = data['radar'] as Map<String, dynamic>;
      final past = radar['past'] as List<dynamic>;
      
      // Extrahiere Zeitstempel und konvertiere zu String-Liste
      return past.map<String>((item) => item['time'].toString()).toList();
    }
  } catch (e) {
    print('Fehler beim Laden der Radar-Zeitstempel: $e');
  }
  return [];
});

/// Gibt das Radar-Tile-URL-Template zurück
final radarTileProviderProvider = Provider<String>((ref) {
  final timestamp = ref.watch(radarTimestampProvider);
  
  if (timestamp.isEmpty) {
    // Lade den neuesten Zeitstempel
    final timestampsAsync = ref.watch(radarTimestampsProvider);
    timestampsAsync.whenData((timestamps) {
      if (timestamps.isNotEmpty) {
        // Verwende den neuesten Zeitstempel
        final latestTimestamp = timestamps.last;
        Future.microtask(() {
          ref.read(radarTimestampProvider.notifier).state = latestTimestamp;
        });
      }
    });
    return '';
  }
  
  return 'https://tilecache.rainviewer.com/v2/radar/$timestamp/256/{z}/{x}/{y}/2/1_1.png';
});
