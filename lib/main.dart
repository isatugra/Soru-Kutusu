import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/ogrenci/ogrenci_home_screen.dart';
import 'screens/ogretmen/ogretmen_home_screen.dart'; // Eklendi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  bool? isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? rol = prefs.getString('rol') ?? "Öğrenci"; // Giriş yapanın rolünü oku

  runApp(SoruKutusuApp(isLoggedIn: isLoggedIn, rol: rol));
}

class SoruKutusuApp extends StatelessWidget {
  final bool isLoggedIn;
  final String rol;
  const SoruKutusuApp({super.key, required this.isLoggedIn, required this.rol});

  @override
  Widget build(BuildContext context) {
    // Gidilecek ana ekranı belirliyoruz
    Widget anaEkran;
    if (isLoggedIn) {
      anaEkran =
          (rol == "Öğretmen")
              ? const OgretmenHomeScreen()
              : const OgrenciHomeScreen();
    } else {
      anaEkran = const LoginScreen();
    }

    return MaterialApp(
      title: 'Soru Kutusu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: anaEkran,
    );
  }
}
