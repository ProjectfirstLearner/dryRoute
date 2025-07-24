import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main.dart';

// Neue Provider für Einstellungen
final defaultTransportModeProvider = StateProvider<String>((ref) => 'foot-walking');
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final radarAutoShowProvider = StateProvider<bool>((ref) => true);
final unitsProvider = StateProvider<String>((ref) => 'metric');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarProvider = ref.watch(radarProviderSetting);
    final darkMode = ref.watch(darkModeProvider);
    final defaultTransportMode = ref.watch(defaultTransportModeProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final radarAutoShow = ref.watch(radarAutoShowProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Einstellungen',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dark_mode),
                          title: const Text('Dark Mode'),
                          subtitle: Text(darkMode ? 'Aktiviert' : 'Deaktiviert'),
                          trailing: Switch(
                            value: darkMode,
                            onChanged: (val) => ref.read(darkModeProvider.notifier).state = val,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Navigation',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.directions),
                          title: const Text('Standard-Transportmittel'),
                          subtitle: Text(defaultTransportMode == 'cycling-regular' ? 'Fahrrad' : 'Zu Fuß'),
                          trailing: DropdownButton<String>(
                            value: defaultTransportMode,
                            items: const [
                              DropdownMenuItem(value: 'foot-walking', child: Text('Zu Fuß')),
                              DropdownMenuItem(value: 'cycling-regular', child: Text('Fahrrad')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(defaultTransportModeProvider.notifier).state = value;
                              }
                            },
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.straighten),
                          title: const Text('Einheiten'),
                          subtitle: Text(units == 'metric' ? 'Metrisch (km, m)' : 'Imperial (mi, ft)'),
                          trailing: DropdownButton<String>(
                            value: units,
                            items: const [
                              DropdownMenuItem(value: 'metric', child: Text('Metrisch')),
                              DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(unitsProvider.notifier).state = value;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Wetter & Radar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.radar),
                          title: const Text('Radar-Provider'),
                          subtitle: Text(radarProvider == 'rainviewer' ? 'Rainviewer' : 'DWD (Deutschland)'),
                          trailing: DropdownButton<String>(
                            value: radarProvider,
                            items: const [
                              DropdownMenuItem(value: 'rainviewer', child: Text('Rainviewer')),
                              DropdownMenuItem(value: 'dwd', child: Text('DWD')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(radarProviderSetting.notifier).state = value;
                              }
                            },
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.visibility),
                          title: const Text('Radar automatisch anzeigen'),
                          subtitle: const Text('Bei Regenwarnungen automatisch einblenden'),
                          trailing: Switch(
                            value: radarAutoShow,
                            onChanged: (val) => ref.read(radarAutoShowProvider.notifier).state = val,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Benachrichtigungen',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Regenwarnungen'),
                          subtitle: const Text('Benachrichtigungen bei Regen auf der Route'),
                          trailing: Switch(
                            value: notificationsEnabled,
                            onChanged: (val) => ref.read(notificationsEnabledProvider.notifier).state = val,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Über DryRoute'),
                          subtitle: const Text('Version 1.0.0'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'DryRoute',
                              applicationVersion: '1.0.0',
                              applicationIcon: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.umbrella,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              children: [
                                const Text('DryRoute hilft dir dabei, trocken ans Ziel zu kommen. '
                                    'Intelligente Routenplanung mit Live-Wetterwarnungen für Radfahrer und Fußgänger.'),
                              ],
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.feedback_outlined),
                          title: const Text('Feedback senden'),
                          subtitle: const Text('Teile deine Meinung mit uns'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Feedback-Funktion - Coming Soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
