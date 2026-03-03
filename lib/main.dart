import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/env/app.env');
  } catch (_) {
    // Optional: app can still run using --dart-define or saved preferences.
  }
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
