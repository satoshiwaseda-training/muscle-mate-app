import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MuscleMateApp());
}

class MuscleMateApp extends StatelessWidget {
  const MuscleMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muscle Mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935), // 筋トレ感のある赤
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
