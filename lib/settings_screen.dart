import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'radar_provider.dart';
import 'main.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarProvider = ref.watch(radarProviderSetting);
    final darkMode = ref.watch(darkModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Radar-Provider'),
            subtitle: Text(radarProvider == 'rainviewer' ? 'Rainviewer' : 'DWD'),
            trailing: DropdownButton<String>(
              value: radarProvider,
              items: const [
                DropdownMenuItem(value: 'rainviewer', child: Text('Rainviewer')),
                DropdownMenuItem(value: 'dwd', child: Text('DWD (Deutschland)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(radarProviderSetting.notifier).state = value;
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: darkMode,
            onChanged: (val) => ref.read(darkModeProvider.notifier).state = val,
          ),
        ],
      ),
    );
  }
}
