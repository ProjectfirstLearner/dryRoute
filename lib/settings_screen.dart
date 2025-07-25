import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'radar_provider.dart';

// Provider für Einstellungen
final defaultTransportModeProvider = StateProvider<String>((ref) => 'foot-walking');
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final radarAutoShowProvider = StateProvider<bool>((ref) => true);
final unitsProvider = StateProvider<String>((ref) => 'metric');
final darkModeProvider = StateProvider<bool>((ref) => false);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarProvider);
    final darkMode = ref.watch(darkModeProvider);
    final defaultTransportMode = ref.watch(defaultTransportModeProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final radarAutoShow = ref.watch(radarAutoShowProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          _buildSection(
            'Erscheinungsbild',
            [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(darkMode ? 'Aktiviert' : 'Deaktiviert'),
                value: darkMode,
                onChanged: (value) {
                  ref.read(darkModeProvider.notifier).state = value;
                },
              ),
            ],
          ),
          _buildSection(
            'Radar',
            [
              SwitchListTile(
                title: const Text('Radar anzeigen'),
                subtitle: const Text('Regenradar auf der Karte einblenden'),
                value: radarState.isVisible,
                onChanged: (value) {
                  if (value) {
                    ref.read(radarProvider.notifier).show();
                  } else {
                    ref.read(radarProvider.notifier).hide();
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Radar automatisch anzeigen'),
                subtitle: const Text('Bei Regen automatisch einblenden'),
                value: radarAutoShow,
                onChanged: (value) {
                  ref.read(radarAutoShowProvider.notifier).state = value;
                },
              ),
              ListTile(
                title: const Text('Radar-Quelle'),
                subtitle: Text(RadarUrlHelper.getSourceDisplayName(radarState.source)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showRadarSourceDialog(),
              ),
              ListTile(
                title: const Text('Radar-Transparenz'),
                subtitle: Slider(
                  value: radarState.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(radarState.opacity * 100).round()}%',
                  onChanged: (value) {
                    ref.read(radarProvider.notifier).setOpacity(value);
                  },
                ),
              ),
            ],
          ),
          _buildSection(
            'Navigation',
            [
              ListTile(
                title: const Text('Standard-Transportmittel'),
                subtitle: Text(_getTransportModeDisplayName(defaultTransportMode)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showTransportModeDialog(),
              ),
              ListTile(
                title: const Text('Einheiten'),
                subtitle: Text(units == 'metric' ? 'Metrisch (km/h)' : 'Imperial (mph)'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showUnitsDialog(),
              ),
            ],
          ),
          _buildSection(
            'Benachrichtigungen',
            [
              SwitchListTile(
                title: const Text('Benachrichtigungen'),
                subtitle: const Text('Bei Regen und Navigation'),
                value: notificationsEnabled,
                onChanged: (value) {
                  ref.read(notificationsEnabledProvider.notifier).state = value;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showRadarSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radar-Quelle wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RadarSource.values.map((source) {
            return RadioListTile<RadarSource>(
              title: Text(RadarUrlHelper.getSourceDisplayName(source)),
              value: source,
              groupValue: ref.read(radarProvider).source,
              onChanged: (value) {
                if (value != null) {
                  ref.read(radarProvider.notifier).setSource(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _showTransportModeDialog() {
    final modes = {
      'foot-walking': 'Zu Fuß',
      'cycling-regular': 'Fahrrad',
      'driving-car': 'Auto',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transportmittel wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: ref.read(defaultTransportModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(defaultTransportModeProvider.notifier).state = value;
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _showUnitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einheiten wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Metrisch (km, km/h)'),
              value: 'metric',
              groupValue: ref.read(unitsProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(unitsProvider.notifier).state = value;
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Imperial (mi, mph)'),
              value: 'imperial',
              groupValue: ref.read(unitsProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(unitsProvider.notifier).state = value;
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  String _getTransportModeDisplayName(String mode) {
    switch (mode) {
      case 'foot-walking':
        return 'Zu Fuß';
      case 'cycling-regular':
        return 'Fahrrad';
      case 'driving-car':
        return 'Auto';
      default:
        return 'Unbekannt';
    }
  }
}
