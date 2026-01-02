import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Réajouté pour la sauvegarde
import 'dart:async';
import 'dart:math';

void main() async {
  // INDISPENSABLE : Initialise le moteur avant de charger les préférences
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
      home: const SplashScreen(),
    );
  }
}

// --- COMPOSANT GRAPHIQUE (Ton design validé) ---
class RealMiniChart extends StatelessWidget {
  final String variation;
  final Color color;
  final double price;

  const RealMiniChart({super.key, required this.variation, required this.color, required this.price});

  @override
  Widget build(BuildContext context) {
    bool isPositive = variation.contains('+');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: 35,
          width: 90,
          child: CustomPaint(
            painter: _ChartPainter(color: color, isPositive: isPositive, seed: price.toInt()),
          ),
        ),
        const SizedBox(height: 4),
        Text("LAST 24H", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color color;
  final bool isPositive;
  final int seed;
  _ChartPainter({required this.color, required this.isPositive, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    final dashPaint = Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 1;
    
    // Ligne pointillée centrale
    for (double i = 0; i < size.width; i += 5) {
      canvas.drawLine(Offset(i, size.height / 2), Offset(i + 2, size.height / 2), dashPaint);
    }

    final path = Path();
    // Le "Seed" garantit que le dessin reste le même pour un prix donné
    final rand = Random(seed);
    int segments = 6;
    double step = size.width / segments;
    List<Offset> pts = [];
    
    for (int i = 0; i <= segments; i++) {
      double x = i * step;
      double noise = rand.nextDouble() * 12;
      double trend = isPositive 
          ? (size.height * 0.75) - (i * 4) // Monte
          : (size.height * 0.25) + (i * 4); // Descend
      pts.add(Offset(x, (trend + noise).clamp(2, size.height - 2)));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    // Courbe de Bézier pour l'effet fluide
    for (int i = 0; i < pts.length - 1; i++) {
      path.quadraticBezierTo(pts[i].dx + (pts[i+1].dx - pts[i].dx) / 2, pts[i].dy, pts[i+1].dx, pts[i+1].dy);
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(CustomPainter old) => true;
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
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      }
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
            Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(45),
                boxShadow: [BoxShadow(color: darkGreen.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 90),
            ),
            const SizedBox(height: 40),
            const Text('PROPRICE', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: darkGreen, letterSpacing: 2)),
            const Spacer(),
            const CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(darkGreen)),
            const Spacer(),
            Text('“Slogan de l’entreprise”', style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: darkGreen.withOpacity(0.6))),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

// --- 2. HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedGrain = "TRIGO";
  bool _isLoading = true; // Pour attendre le chargement des favoris

  final List<Map<String, dynamic>> grainsData = [
    {"name": "TRIGO", "emoji": "🌾", "price": "515.00", "variation": "+4.09%", "isFav": false, "order": 0},
    {"name": "SOJA", "emoji": "🌱", "price": "420.50", "variation": "-1.20%", "isFav": false, "order": 1},
    {"name": "MAIZ", "emoji": "🌽", "price": "185.00", "variation": "+0.50%", "isFav": false, "order": 2},
    {"name": "CANOLA", "emoji": "🌿", "price": "610.00", "variation": "+2.15%", "isFav": false, "order": 3},
    {"name": "GIRASOL", "emoji": "🌻", "price": "390.00", "variation": "-0.75%", "isFav": false, "order": 4},
    {"name": "CEBADA", "emoji": "🪴", "price": "210.00", "variation": "+1.10%", "isFav": false, "order": 5},
    {"name": "ARROZ", "emoji": "🍚", "price": "12.40", "variation": "+0.25%", "isFav": false, "order": 6},
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // --- LOGIQUE DE SAUVEGARDE (AJOUTÉE) ---
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedFavs = prefs.getStringList('favorites') ?? [];
    
    setState(() {
      for (var grain in grainsData) {
        if (savedFavs.contains(grain['name'])) {
          grain['isFav'] = true;
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favList = grainsData
        .where((g) => g['isFav'] == true)
        .map((g) => g['name'] as String)
        .toList();
    await prefs.setStringList('favorites', favList);
  }

  void _toggleFavorite(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    setState(() {
      int idx = grainsData.indexWhere((g) => g["name"] == item["name"]);
      grainsData[idx]["isFav"] = !grainsData[idx]["isFav"];
      
      _saveFavorites(); // Sauvegarde immédiate

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(grainsData[idx]["isFav"] ? "${item['name']} Añadido" : "${item['name']} Eliminado"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF1B4D3E),
        ),
      );
    });
  }

  void _onSelectGrain(String name) {
    if (selectedGrain != name) {
      HapticFeedback.selectionClick();
      setState(() => selectedGrain = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    const Color darkGreen = Color(0xFF1B4D3E);

    // Tri dynamique : Favoris en haut
    List<Map<String, dynamic>> sortedList = List.from(grainsData);
    sortedList.sort((a, b) {
      if (a["isFav"] != b["isFav"]) return a["isFav"] ? -1 : 1;
      return a["order"].compareTo(b["order"]);
    });

    final currentData = grainsData.firstWhere((g) => g["name"] == selectedGrain);
    final bool isPositive = (currentData["variation"] as String).contains('+');
    final Color trendColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2EFE9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('PROPRICE', style: TextStyle(color: darkGreen, fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [IconButton(icon: const Icon(Icons.menu_open_rounded, color: darkGreen, size: 32), onPressed: () {})],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PRECIO ACTUAL DEL ${currentData["name"]}", 
                  style: TextStyle(color: darkGreen.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("\$ ", style: TextStyle(color: darkGreen.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("${currentData["price"]}", style: const TextStyle(color: darkGreen, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2)),
                    Text(" / Tn", style: TextStyle(color: darkGreen.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: darkGreen.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen, foregroundColor: Colors.white,
                          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        child: const Text("VER GRAFICO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: trendColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: trendColor.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: trendColor, size: 22),
                          const SizedBox(width: 8),
                          Text(currentData["variation"], style: TextStyle(color: trendColor, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                    ),
                    RealMiniChart(variation: currentData["variation"], color: trendColor, price: double.tryParse(currentData["price"]) ?? 0),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  itemCount: sortedList.length,
                  itemBuilder: (context, index) {
                    final item = sortedList[index];
                    final isSelected = selectedGrain == item["name"];
                    final isFav = item["isFav"];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Material(
                        color: isSelected ? darkGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _onSelectGrain(item["name"]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? darkGreen : Colors.grey.withOpacity(0.15), 
                                width: isSelected ? 2 : 1.5
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(item["emoji"], style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 14),
                                Text(item["name"], style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.w800, fontSize: 18)),
                                const Spacer(),
                                if (isSelected) ...[
                                  _whiteIconButton(isFav ? Icons.star_rounded : Icons.star_outline_rounded, isFav ? Colors.orange : darkGreen, () => _toggleFavorite(item)),
                                  const SizedBox(width: 8),
                                  _whiteIconButton(Icons.notifications_active_outlined, darkGreen, () {}),
                                  const SizedBox(width: 8),
                                  _whiteIconButton(Icons.bar_chart_rounded, darkGreen, () {}),
                                ] else ...[
                                  GestureDetector(
                                    onTap: () => _toggleFavorite(item),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        isFav ? Icons.star_rounded : Icons.star_outline_rounded, 
                                        color: isFav ? Colors.orange.withOpacity(0.8) : darkGreen.withOpacity(0.2), 
                                        size: 28
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: darkGreen,
          unselectedItemColor: darkGreen.withOpacity(0.3),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_max_rounded, size: 26), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.article_rounded, size: 26), label: 'NEWS'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_suggest_rounded, size: 26), label: 'SETTINGS'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 26), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }

  Widget _whiteIconButton(IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}