import 'package:flutter/material.dart';
import 'dart:async';

void main() => runApp(const PropriceApp());

class PropriceApp extends StatelessWidget {
  const PropriceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, // Standard de design Flutter moderne
        scaffoldBackgroundColor: const Color(0xFFF2EFE9),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(const Color(0xFF1B4D3E).withOpacity(0.5)),
          radius: const Radius.circular(10),
          thickness: WidgetStateProperty.all(6.0),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
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
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
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
            Container(width: 200, height: 180, color: darkGreen),
            const SizedBox(height: 40),
            const Text('PROPRICE', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: darkGreen, letterSpacing: 2)),
            const Spacer(),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(darkGreen)),
            const Spacer(),
            const Text('“slogan”', style: TextStyle(fontSize: 24, fontStyle: FontStyle.italic, color: darkGreen)),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

// --- 2. HOME PAGE (INTERACTIVE AVEC DONNÉES) ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Élément sélectionné par défaut
  String selectedGrain = "TRIGO";

  // JEU DE DONNÉES COMPLET
  final List<Map<String, dynamic>> grainsData = [
    {
      "name": "TRIGO",
      "emoji": "🌾",
      "price": "515.00",
      "variation": "+4.09%",
      "history": [500.0, 505.0, 515.0]
    },
    {
      "name": "SOJA",
      "emoji": "🌱",
      "price": "420.50",
      "variation": "-1.20%",
      "history": [430.0, 425.0, 420.5]
    },
    {
      "name": "MAIZ",
      "emoji": "🌽",
      "price": "185.00",
      "variation": "+0.50%",
      "history": [180.0, 182.0, 185.0]
    },
    {
      "name": "CANOLA",
      "emoji": "🌿",
      "price": "610.00",
      "variation": "+2.15%",
      "history": [590.0, 600.0, 610.0]
    },
    {
      "name": "GIRASOL",
      "emoji": "🌻",
      "price": "390.00",
      "variation": "-0.75%",
      "history": [400.0, 395.0, 390.0]
    },
    {
      "name": "CEBADA",
      "emoji": "🪴",
      "price": "210.00",
      "variation": "+1.10%",
      "history": [205.0, 208.0, 210.0]
    },
    {
      "name": "ARROZ",
      "emoji": "🍚",
      "price": "12.40",
      "variation": "+0.25%",
      "history": [12.10, 12.30, 12.40]
    },
  ];

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);

    // Récupération des données de l'élément sélectionné
    final currentData = grainsData.firstWhere((g) => g["name"] == selectedGrain);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2EFE9), // Assorti au fond
        surfaceTintColor: Colors.transparent,     // FIX : Empêche l'AppBar de devenir grise au scroll
        elevation: 0,
        title: const Text('PROPRICE', style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.menu, color: darkGreen, size: 35), onPressed: () {})],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // EN-TÊTE DYNAMIQUE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PRECIO ACTUAL DEL ${currentData["name"]}", 
                  style: const TextStyle(color: darkGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text("${currentData["price"]}", 
                      style: const TextStyle(color: darkGreen, fontSize: 50, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: () {
                        print("Graphique de : ${currentData["name"]}");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      ),
                      child: const Text("VER GRAFICO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(
                  currentData["variation"], 
                  style: TextStyle(
                    color: currentData["variation"].contains('+') ? Colors.green : Colors.red, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18
                  )
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // RECTANGLE BLANC ET LISTE D'ÉLÉMENTS
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    itemCount: grainsData.length,
                    itemBuilder: (context, index) {
                      final item = grainsData[index];
                      final isSelected = selectedGrain == item["name"];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedGrain = item["name"];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? darkGreen : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? darkGreen : Colors.grey.withOpacity(0.2), 
                              width: 1.5
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25), // Tailles des rectangles
                            child: Row(
                              children: [
                                Text(item["name"], 
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : darkGreen, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 22
                                  )
                                ),
                                const SizedBox(width: 10),
                                Text(item["emoji"], style: const TextStyle(fontSize: 24)),
                                const Spacer(),
                                if (isSelected) ...[
                                  _whiteIconButton(Icons.star, darkGreen),
                                  const SizedBox(width: 10),
                                  _whiteIconButton(Icons.alarm, darkGreen),
                                  const SizedBox(width: 10),
                                  _whiteIconButton(Icons.bar_chart, darkGreen),
                                ]
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: darkGreen,
        unselectedItemColor: darkGreen.withOpacity(0.4),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, size: 30), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.article, size: 30), label: 'NEWS'),
          BottomNavigationBarItem(icon: Icon(Icons.settings, size: 30), label: 'SETTINGS'),
          BottomNavigationBarItem(icon: Icon(Icons.person, size: 30), label: 'PROFILE'),
        ],
      ),
    );
  }

  Widget _whiteIconButton(IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}