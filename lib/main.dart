import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('FlutterError:');
    print(details.exceptionAsString());
    print(details.stack);
  };
  print('Starte App, lade .env ...');
  try {
    await dotenv.load(fileName: ".env");
    print('Starte DryRouteApp ...');
    runApp(const ProviderScope(child: DryRouteApp()));
  } catch (e, stack) {
    print('Fehler beim Start: $e');
    print(stack);
  }
}


final radarProviderSetting = StateProvider<String>((ref) => 'rainviewer');
final darkModeProvider = StateProvider<bool>((ref) => false);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DryRouteApp extends ConsumerWidget {
  const DryRouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('DryRouteApp build() gestartet');
    final darkMode = ref.watch(darkModeProvider);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: darkMode ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'DryRoute',
      navigatorKey: navigatorKey,
      theme: ThemeData.from(colorScheme: colorScheme).copyWith(
        useMaterial3: true,
      ),
      home: MapScreen(
        onOpenSettings: () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (ctx) => const SettingsScreen(),
            ),
          );
        },
      ),
    );
  }
}
      // called again, and so nothing would appear to happen.
