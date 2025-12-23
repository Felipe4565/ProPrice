import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const PropriceApp());
}

class PropriceApp extends StatelessWidget {
  const PropriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Proprice',
      theme: ThemeData(
        primaryColor: const Color(0xFF1B4D3E),
        scaffoldBackgroundColor: const Color(0xFFF2EFE9),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- 1. SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
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
            Container(width: 160, height: 160, color: darkGreen),
            const SizedBox(height: 40),
            const Text('PROPRICE',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: darkGreen, letterSpacing: 2)),
            const Spacer(),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(darkGreen)),
            const Spacer(),
            const Text('“Los cultivos Uruguayos”',
                style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: darkGreen)),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

// --- 2. HOME PAGE (AMÉLIORÉE) ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);
    const Color lightBeige = Color(0xFFF2EFE9);

    return Scaffold(
      backgroundColor: lightBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: Text('PROPRICE', style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 16))),
        ),
        leadingWidth: 120,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(icon: const Icon(Icons.menu, color: darkGreen, size: 35), onPressed: () {}),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          // Section Titre et Prix
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("PRECIO ACTUAL DEL TRIGO",
                    style: TextStyle(color: darkGreen, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Text("515.00",
                        style: TextStyle(color: darkGreen, fontSize: 60, fontWeight: FontWeight.bold, height: 1)),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(8)),
                      child: const Text("VER GRAFICO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text("+4.09%", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
          
          const SizedBox(height: 40),

          // LE RECTANGLE BLANC (Optimisé)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20), // Marges sur les côtés
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildGrainTile("TRIGO", "🌾", isSelected: true),
                    _buildGrainTile("SOJA", "🌱"),
                    _buildGrainTile("MAIZ", "🌽"),
                    _buildGrainTile("CANOLA", "🌿"),
                    _buildGrainTile("GIRASOL", "🌻"),
                    _buildGrainTile("CEBADA", "🪴"),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      
      // BOTTOM BAR (Plus propre)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: darkGreen,
          unselectedItemColor: darkGreen.withOpacity(0.4),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 30), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined, size: 30), label: 'NEWS'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 30), label: 'SETTINGS'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 30), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }

  Widget _buildGrainTile(String name, String emoji, {bool isSelected = false}) {
    const Color darkGreen = Color(0xFF1B4D3E);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 25),
      decoration: BoxDecoration(
        color: isSelected ? darkGreen : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Text(name, style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(width: 10),
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const Spacer(),
          if (isSelected) ...[
            const Icon(Icons.star_border, color: Colors.white, size: 26),
            const SizedBox(width: 15),
            const Icon(Icons.alarm, color: Colors.white, size: 26),
            const SizedBox(width: 15),
            const Icon(Icons.bar_chart, color: Colors.white, size: 26),
          ]
        ],
      ),
    );
  }
}