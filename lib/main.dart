import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? true; // Default to dark mode
  
  runApp(ShiftSchedulerApp(initialDarkMode: isDarkMode));
}

class ShiftSchedulerApp extends StatefulWidget {
  final bool initialDarkMode;
  const ShiftSchedulerApp({super.key, required this.initialDarkMode});

  // Provide a global way to toggle theme from anywhere in the app
  static _ShiftSchedulerAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_ShiftSchedulerAppState>()!;

  @override
  State<ShiftSchedulerApp> createState() => _ShiftSchedulerAppState();
}

class _ShiftSchedulerAppState extends State<ShiftSchedulerApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    // Beautiful Modern Themes using Google Fonts
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E88E5), // Deep beautiful blue
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E88E5),
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E2C), // Deep premium dark background
        background: const Color(0xFF12121A),
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF12121A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );

    return MaterialApp(
      title: 'Egyptian Nursing Shift Scheduler',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: const WelcomeScreen(),
    );
  }
}
