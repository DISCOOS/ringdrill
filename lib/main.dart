import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ringdrill/screens/home_screen.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Load user consent for analytics from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool(AppConfig.keyIsFirstLaunch) ?? true;
  final analyticsConsent =
      prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;

  if (isFirstLaunch) {
    // Set default "analyticsConsent" to false (opt-out by default)
    await prefs.setBool(AppConfig.keyAnalyticsConsent, false);
    await prefs.setBool(AppConfig.keyIsFirstLaunch, false);
  }

  if (analyticsConsent) {
    // Run app with Sentry on consent
    await SentryFlutter.init(
      SentryConfig.apply,
      appRunner:
          () => runApp(SentryWidget(child: RingDrillApp(isFirstLaunch: false))),
    );
  } else {
    // Run app without Sentry if no consent
    runApp(RingDrillApp(isFirstLaunch: isFirstLaunch));
  }
}

class RingDrillApp extends StatelessWidget {
  const RingDrillApp({super.key, required this.isFirstLaunch});

  final bool isFirstLaunch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RingDrill',
      theme: ringDrillTheme,
      darkTheme: ringDrillDarkTheme,
      themeMode: ThemeMode.dark,
      home: HomeScreen(isFirstLaunch: isFirstLaunch),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Phase-specific colors (usable throughout the app)
class PhaseColors {
  static const drill = Color(0xFF10B981); // Green
  static const evaluation = Color(0xFFF59E0B); // Amber
  static const rotation = Color(0xFF3B82F6); // Blue
}

final ThemeData ringDrillTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  primaryColor: const Color(0xFF1E3A8A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E3A8A),
    primary: const Color(0xFF1E3A8A),
    secondary: const Color(0xFF4B5563),
    surface: const Color(0xFFE5E7EB),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: const Color(0xFF111827),
    onSurfaceVariant: const Color(0xFF374151),
    error: const Color(0xFFF59E0B),
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.robotoFlexTextTheme(),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFFE5E7EB),
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);

final ThemeData ringDrillDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF111827),
  primaryColor: const Color(0xFF60A5FA),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF60A5FA),
    primary: const Color(0xFF60A5FA),
    primaryFixed: const Color(0xFF1E3A8A),
    secondary: const Color(0xFF9CA3AF),
    surface: const Color(0xFF1F2937),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: Colors.white,
    onSurfaceVariant: Color(0xFF9CA3AF),
    error: const Color(0xFFF5800B),
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.robotoFlexTextTheme(ThemeData.dark().textTheme),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF60A5FA),
      foregroundColor: Colors.black,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF1F2937),
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);

/*
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Drill')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Start Time (e.g., 13:30)',
              ),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Number of Stations'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Drill Duration (min)'),
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'Evaluation Duration (min)',
              ),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Rotation Duration (min)'),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {},
                child: Text('Start Exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamViewScreen extends StatelessWidget {
  const TeamViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Team View')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Current: Post 2', style: TextStyle(fontSize: 20)),
            SizedBox(height: 8),
            Text('Phase: Evaluation'),
            Text('Started: 14:10'),
            SizedBox(height: 16),
            Text(
              'Next: Post 3 at 14:25',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class CoordinatorViewScreen extends StatelessWidget {
  const CoordinatorViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Coordinator View')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('R1: 13:30 - 14:25')),
          ListTile(title: Text('R2: 14:30 - 15:25')),
          ListTile(title: Text('R3: 15:30 - 16:25')),
          ListTile(title: Text('R4: 16:30 - 17:25')),
          Divider(),
          ListTile(
            title: Text(
              'Return: 17:50',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

 */
