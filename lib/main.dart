import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/app_settings.dart';
import 'providers/user_data_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ],
      child: const PropriceApp(),
    ),
  );
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

Future<void> _startAppSequence() async {
  await Future.delayed(const Duration(seconds: 2));
  _navigateToHome();
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