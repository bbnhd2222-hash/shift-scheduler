import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ShiftSchedulerApp());
}

class ShiftSchedulerApp extends StatelessWidget {
  const ShiftSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Egyptian Nursing Shift Scheduler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
