
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum RadarSource { rainviewer, dwd, openweathermap }

class RadarState {
  final bool isVisible;
  final RadarSource source;
  final double opacity;

  const RadarState({
    this.isVisible = false,
    this.source = RadarSource.rainviewer,
    this.opacity = 0.7,
  });

  RadarState copyWith({
    bool? isVisible,
    RadarSource? source,
    double? opacity,
  }) {
    return RadarState(
      isVisible: isVisible ?? this.isVisible,
      source: source ?? this.source,
      opacity: opacity ?? this.opacity,
    );
  }
}

class RadarNotifier extends StateNotifier<RadarState> {
  RadarNotifier() : super(const RadarState());

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
  }

  void setSource(RadarSource source) {
    state = state.copyWith(source: source);
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.0, 1.0));
  }

  void hide() {
    state = state.copyWith(isVisible: false);
  }

  void show() {
    state = state.copyWith(isVisible: true);
  }
}

final radarProvider = StateNotifierProvider<RadarNotifier, RadarState>((ref) {
  return RadarNotifier();
});

// Hilfsfunktion für Radar-URLs
class RadarUrlHelper {
  static String getRadarUrl(RadarSource source, int x, int y, int z, {int? timestamp}) {
    switch (source) {
      case RadarSource.rainviewer:
        final ts = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        return 'https://tilecache.rainviewer.com/v2/radar/$ts/256/$z/$x/$y/2/1_1.png';
      
      case RadarSource.dwd:
        return 'https://maps.dwd.de/geoserver/dwd/wmts?'
            'layer=RADOLAN-OS&style=default&tilematrixset=EPSG:4326&'
            'Service=WMTS&Request=GetTile&Version=1.0.0&Format=image/png&'
            'TileMatrix=$z&TileCol=$x&TileRow=$y';
      
      case RadarSource.openweathermap:
        final apiKey = dotenv.env['OWM_API_KEY'] ?? '';
        if (apiKey.isEmpty) {
          print('Warning: OWM_API_KEY not found in .env file');
          return '';
        }
        return 'https://tile.openweathermap.org/map/precipitation_new/$z/$x/$y.png?appid=$apiKey';
    }
  }

  static String getSourceDisplayName(RadarSource source) {
    switch (source) {
      case RadarSource.rainviewer:
        return 'RainViewer';
      case RadarSource.dwd:
        return 'DWD (Deutscher Wetterdienst)';
      case RadarSource.openweathermap:
        return 'OpenWeatherMap';
    }
  }
}
