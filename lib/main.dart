import 'package:flutter/material.dart';
import 'ui/home_page.dart';

void main() {
  runApp(const FanoronaTeloApp());
}

class FanoronaTeloApp extends StatelessWidget {
  const FanoronaTeloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fanorona Telo',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020014),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF0066FF),
          secondary: const Color(0xFFFF1493),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}