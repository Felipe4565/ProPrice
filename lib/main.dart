import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // AJOUTÉ
import 'package:shared_preferences/shared_preferences.dart'; // AJOUTÉ

import 'pages/home_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PropriceApp());
}

class PropriceApp extends StatelessWidget {
  const PropriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2EFE9),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(const Color(0xFF1B4D3E).withOpacity(0.5)),
          radius: const Radius.circular(10),
          thickness: WidgetStateProperty.all(6.0),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
      ),
      // Vérifie bien que ce nom correspond à la classe du dessous
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _startAppSequence();
  }

  // --- LOGIQUE DE SÉCURITÉ AU DÉMARRAGE ---
  Future<void> _startAppSequence() async {
    // 1. Petit délai pour que l'utilisateur voie ton logo (2s)
    await Future.delayed(const Duration(seconds: 2));

    // 2. On vérifie si la biométrie est activée
    final prefs = await SharedPreferences.getInstance();
    final bool isBioEnabled = prefs.getBool('bio_enabled') ?? false;

    if (isBioEnabled) {
      try {
        // 3. On demande l'empreinte/FaceID
        bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Identifícate para entrar en Proprice',
        );

        if (didAuthenticate) {
          _navigateToHome();
        } else {
          // Si l'utilisateur annule, on peut lui laisser un bouton pour réessayer
          // Pour l'instant on reste sur le splash
        }
      } catch (e) {
        debugPrint("Erreur biométrie: $e");
        _navigateToHome(); // En cas d'erreur technique, on laisse passer
      }
    } else {
      // Si pas activé, on va direct à la home
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const HomePage())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Container(
              width: 160, 
              height: 160,
              decoration: BoxDecoration(
                color: darkGreen, 
                borderRadius: BorderRadius.circular(45), 
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.3), 
                    blurRadius: 40, 
                    offset: const Offset(0, 20)
                  )
                ]
              ),
              child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 90),
            ),
            const SizedBox(height: 40),
            const Text(
              'PROPRICE', 
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: darkGreen, letterSpacing: 2)
            ),
            const Spacer(),
            const CircularProgressIndicator(
              strokeWidth: 3, 
              valueColor: AlwaysStoppedAnimation<Color>(darkGreen)
            ),
            const Spacer(),
            Text(
              '“Slogan de l’entreprise”', 
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: darkGreen.withOpacity(0.6))
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}