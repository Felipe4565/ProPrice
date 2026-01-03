import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'news_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  String selectedGrain = "TRIGO";
  bool _isLoading = true;

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
      _saveFavorites();
    });
  }

  void _onSelectGrain(String name) {
    if (selectedGrain != name) {
      HapticFeedback.selectionClick();
      setState(() => selectedGrain = name);
    }
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    const Color darkGreen = Color(0xFF1B4D3E);

    Widget bodyContent;
    switch (_selectedIndex) {
      case 0:
        bodyContent = _buildHomeContent(darkGreen);
        break;
      case 1:
        bodyContent = const NewsPage(); // NewsPage peut être const car elle est statique
        break;
      default:
        bodyContent = const Center(child: Text("Page en construction", style: TextStyle(color: darkGreen)));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2EFE9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('PROPRICE', style: TextStyle(color: darkGreen, fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_open_rounded, color: darkGreen, size: 32), 
            onPressed: () {}
          )
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: darkGreen,
          unselectedItemColor: darkGreen.withValues(alpha: 0.3),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
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

  Widget _buildHomeContent(Color darkGreen) {
    List<Map<String, dynamic>> sortedList = List.from(grainsData);
    sortedList.sort((a, b) {
      if (a["isFav"] != b["isFav"]) return a["isFav"] ? -1 : 1;
      return a["order"].compareTo(b["order"]);
    });

    final currentData = grainsData.firstWhere((g) => g["name"] == selectedGrain);
    final bool isPositive = (currentData["variation"] as String).contains('+');
    final Color trendColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(
                "PRECIO ACTUAL DEL ${currentData["name"]}", 
                style: TextStyle(color: darkGreen.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)
              ),
              const SizedBox(height: 8),
              Row(
                textBaseline: TextBaseline.alphabetic, 
                crossAxisAlignment: CrossAxisAlignment.baseline, 
                children: [
                  Text("\$ ", style: TextStyle(color: darkGreen.withValues(alpha: 0.5), fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("${currentData["price"]}", style: TextStyle(color: darkGreen, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2)),                  Text(" / Tn", style: TextStyle(color: darkGreen.withValues(alpha: 0.5), fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // CORRECTION : Pas de 'const' ici car darkGreen est une variable de build
                  ElevatedButton(
                    onPressed: () {}, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen, 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ), 
                    child: const Text("VER GRAFICO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                  ),
                ]
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12), 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: trendColor.withValues(alpha: 0.2), width: 1)
                    ), 
                    child: Row(
                      children: [
                        Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: trendColor, size: 22), 
                        const SizedBox(width: 8), 
                        Text(currentData["variation"], style: TextStyle(color: trendColor, fontWeight: FontWeight.w900, fontSize: 18))
                      ]
                    )
                  ),
                  RealMiniChart(variation: currentData["variation"], color: trendColor, price: double.tryParse(currentData["price"]) ?? 0),
                ]
              ),
            ]
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(30), 
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10))]
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
                              color: isSelected ? darkGreen : Colors.grey.withValues(alpha: 0.15), 
                              width: isSelected ? 2 : 1.5
                            )
                          ),
                          child: Row(
                            children: [
                              Text(item["emoji"], style: const TextStyle(fontSize: 24)), 
                              const SizedBox(width: 14),
                              Text(item["name"], style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.w800, fontSize: 18)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _toggleFavorite(item), 
                                child: Icon(
                                  isFav ? Icons.star_rounded : Icons.star_outline_rounded, 
                                  color: isFav ? Colors.orange : (isSelected ? Colors.white : darkGreen.withValues(alpha: 0.2)), 
                                  size: 28
                                )
                              )
                            ]
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
    );
  }
}

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
          child: CustomPaint(painter: _ChartPainter(color: color, isPositive: isPositive, seed: price.toInt()))
        ),
        const SizedBox(height: 4), 
        Text("LAST 24H", style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ]
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final rand = Random(seed);
    int segments = 6;
    double step = size.width / segments;
    List<Offset> pts = [];

    for (int i = 0; i <= segments; i++) {
      double x = i * step;
      double trend = isPositive ? (size.height * 0.75) - (i * 4) : (size.height * 0.25) + (i * 4);
      pts.add(Offset(x, (trend + (rand.nextDouble() * 12)).clamp(2, size.height - 2)));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      path.quadraticBezierTo(
        pts[i].dx + (pts[i + 1].dx - pts[i].dx) / 2, 
        pts[i].dy, 
        pts[i + 1].dx, 
        pts[i + 1].dy
      );
    }
    canvas.drawPath(path, paint);
  }

  @override 
  bool shouldRepaint(CustomPainter old) => true;
}