import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screen/home_screen.dart'; // Import layar yang kita buat tadi

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ganti dengan Project URL dan Anon Key milik Anda
  await Supabase.initialize(
    url: 'https://lnsaufsvqlicwjhqbmrh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxuc2F1ZnN2cWxpY3dqaHFibXJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1OTM4MjQsImV4cCI6MjA5NDE2OTgyNH0.-5n78aFX8PFdsv6kRiti8zZYiXMO2fn9d9SrRy2SPzc',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Directory',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(), // Panggil HomeScreen yang sudah kita buat
    );
  }
}