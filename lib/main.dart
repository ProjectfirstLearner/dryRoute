
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
    
    return MaterialApp(
      title: 'DryRoute',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4), // Türkis
          brightness: darkMode ? Brightness.dark : Brightness.light,
          primary: const Color(0xFF00BCD4),
          secondary: const Color(0xFFFF5722), // Orange für Warnungen
          surface: darkMode ? const Color(0xFF121212) : Colors.white,
          background: darkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        ),
        scaffoldBackgroundColor: darkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: darkMode ? Colors.white : const Color(0xFF212121),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkMode ? Colors.white : const Color(0xFF212121),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: darkMode ? Colors.white : const Color(0xFF212121),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: darkMode ? Colors.white70 : const Color(0xFF424242),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: darkMode ? Colors.white60 : const Color(0xFF757575),
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            color: darkMode ? Colors.white54 : const Color(0xFF9E9E9E),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF00BCD4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          selectedItemColor: const Color(0xFF00BCD4),
          unselectedItemColor: darkMode ? Colors.white54 : const Color(0xFF9E9E9E),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    MapScreen(
      onOpenSettings: () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (ctx) => const SettingsScreen(),
          ),
        );
      },
    ),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Karte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Favoriten',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final List<Map<String, String>> _favoriteRoutes = [
    {
      'name': 'Nach Hause',
      'from': 'Alexanderplatz, Berlin',
      'to': 'Potsdamer Platz, Berlin',
      'distance': '3.2 km',
      'mode': 'foot-walking',
    },
    {
      'name': 'Zur Arbeit',
      'from': 'Hauptbahnhof, Berlin',
      'to': 'Brandenburger Tor, Berlin',
      'distance': '1.8 km',
      'mode': 'cycling-regular',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Favoriten',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      // TODO: Implementiere Favorit hinzufügen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Favorit hinzufügen - Coming Soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _favoriteRoutes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Favoriten',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Plane eine Route und speichere sie als Favorit',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _favoriteRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _favoriteRoutes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                route['mode'] == 'cycling-regular' 
                                    ? Icons.directions_bike 
                                    : Icons.directions_walk,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              route['name']!,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        route['from']!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        route['to']!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  route['distance']!,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    // TODO: Route laden
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Route "${route['name']}" laden - Coming Soon!'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  style: IconButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _favoriteRoutes.removeAt(index);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Favorit "${route['name']}" entfernt'),
                                        action: SnackBarAction(
                                          label: 'Rückgängig',
                                          onPressed: () {
                                            setState(() {
                                              _favoriteRoutes.insert(index, route);
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete),
                                  style: IconButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
