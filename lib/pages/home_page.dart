import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proprice/providers/app_settings.dart';
import 'package:proprice/providers/user_data_provider.dart';
import 'package:proprice/services/auth_lock.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/biometric_service.dart';
import 'chart_page.dart';
import 'news_page.dart';
import 'profile_page.dart';
import 'settings_page.dart'; 


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String selectedGrain = "TRIGO";


  final BiometricService _biometricService = BiometricService();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateOnStart();
    });
  }

  Future<void> _authenticateOnStart() async {
  final prefs = await SharedPreferences.getInstance();
  final bool isBioEnabled = prefs.getBool('bio_enabled') ?? false;

  if (!isBioEnabled) return;

  // évite double appel si déjà auth rapide
  if (AuthLock.isAuthenticating) return;
  if (AuthLock.lastSuccess != null &&
      DateTime.now().difference(AuthLock.lastSuccess!).inSeconds < 4) {
    return;
  }

  await _authenticate();
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si l'application revient au premier plan
    if (state == AppLifecycleState.resumed) {
      _checkBiometricOnResume();
    }
  }

  Future<void> _checkBiometricOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isBioEnabled = prefs.getBool('bio_enabled') ?? false;

    if (!isBioEnabled) return;

    final now = DateTime.now();

    if (AuthLock.isAuthenticating) return;
      if (AuthLock.lastSuccess != null &&
          DateTime.now().difference(AuthLock.lastSuccess!).inSeconds < 4) {
        return;
    }

    _authenticate();
  }

  Future<void> _authenticate() async {
    final ok = await _biometricService.authenticate(
      reason: 'Identifícate para acceder a Proprice',
    );

    if (ok) {
      debugPrint("OK AUTH");
    } else {
      debugPrint("AUTH FAILED");
    }
  }



  void _toggleFavorite(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    
    // 1. On utilise le provider pour gérer la logique
    final provider = context.read<UserDataProvider>();
    provider.toggleFavorite(item['name']);

    // 2. On vérifie le nouvel état pour afficher le bon message
    final isNowFav = provider.isFavorite(item['name']);

    // 3. Feedback visuel (SnackBar)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNowFav ? "${item['name']} Añadido" : "${item['name']} Eliminado"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1B4D3E),
      ),
    );
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

  // --- LOGIQUE POPUP ALERTE ---
  void _showAlertDialog(BuildContext mainContext, String grainName, double defaultPrice) {
    final TextEditingController priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );
    final provider = context.read<UserDataProvider>();
    final commodityAlerts = provider.alerts
        .where((a) => a['commodity'].toString().toUpperCase() == grainName.toUpperCase())
        .toList();

    showDialog(
      context: mainContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFF2EFE9),
          title: Row(
            children: const [
              Text('🔔', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text(
                'Définir une alerte',
                style: TextStyle(
                  color: Color(0xFF1B4332),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez le seuil de prix pour $grainName :',
                style: TextStyle(
                  color: const Color(0xFF1B4332).withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Seuil cible (\$)',
                  labelStyle: const TextStyle(color: Color(0xFF1B4332)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: const Color(0xFF1B4332).withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF1B4332), width: 2),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B4332),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Annuler',
                style: TextStyle(color: const Color(0xFF1B4332).withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4332),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final parsedPrice = double.tryParse(priceController.text.replaceAll(',', '.'));
                if (parsedPrice != null) {
                  Navigator.pop(dialogContext);

                  bool exists = commodityAlerts.any((a) => (a['price'] as double) == parsedPrice);

                  if (exists) {
                    showDialog(
                      context: mainContext,
                      builder: (confirmContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: const Color(0xFFF2EFE9),
                          title: const Text(
                            'Alerte existante',
                            style: TextStyle(
                              color: Color(0xFF1B4332),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          content: Text(
                            'Une alerte existe déjà au prix de ${parsedPrice.toStringAsFixed(2)} \$. Êtes-vous sûr de vouloir en placer une autre au même prix ?',
                            style: TextStyle(
                              color: const Color(0xFF1B4332).withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext),
                              child: Text(
                                'Annuler',
                                style: TextStyle(color: const Color(0xFF1B4332).withValues(alpha: 0.6)),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B4332),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(confirmContext);
                                provider.addAlert(grainName, parsedPrice);
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : $grainName > ${parsedPrice.toStringAsFixed(2)} \$'),
                                    backgroundColor: const Color(0xFF1B4332),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    provider.addAlert(grainName, parsedPrice);
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Alerte ajoutée : $grainName > ${parsedPrice.toStringAsFixed(2)} \$'),
                        backgroundColor: const Color(0xFF1B4332),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. On récupère les paramètres via le Provider
    final appSettings = context.watch<AppSettings>();



    const Color darkGreen = Color(0xFF1B4D3E);

    // 3. Définition du contenu du body selon l'index
    Widget bodyContent;
    if (_selectedIndex == 1) {
      bodyContent = const NewsPage();
    } else if (_selectedIndex == 0) {
      bodyContent = _buildHomeContent(darkGreen, appSettings);
    } else if (_selectedIndex == 2) {
      bodyContent = const SettingsPage();
    } else {
      bodyContent = const ProfilePage();
    }

    // 4. Retour du Scaffold
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2EFE9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('PROPRICE',
            style: TextStyle(
                color: darkGreen, fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [
          IconButton(
              icon: const Icon(Icons.menu_open_rounded,
                  color: darkGreen, size: 32),
              onPressed: () {})
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
        ]),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: darkGreen,
          unselectedItemColor: darkGreen.withValues(alpha: 0.3),
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_max_rounded, size: 26), label: 'HOME'),
            BottomNavigationBarItem(
                icon: Icon(Icons.article_rounded, size: 26), label: 'NEWS'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_suggest_rounded, size: 26),
                label: 'SETTINGS'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded, size: 26),
                label: 'PROFILE'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(Color darkGreen, AppSettings appSettings) { 
    final provider = context.watch<UserDataProvider>();
    final List<Map<String, dynamic>> grainsData = provider.grainsData;

    List<Map<String, dynamic>> sortedList = List.from(grainsData);
    sortedList.sort((a, b) {
      bool aFav = provider.isFavorite(a["name"]);
      bool bFav = provider.isFavorite(b["name"]);
      if (aFav != bFav) return aFav ? -1 : 1;
      return (a["order"] as int).compareTo(b["order"] as int);
    });


    final currentData = grainsData.firstWhere((g) => g["name"] == selectedGrain);
    final bool isPositive = (currentData["variation"] as String).contains('+');
    final Color trendColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Column(
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
                  Text(
                    appSettings.hideBalance ? "****" : "${currentData["price"]}",
                    style: TextStyle(
                      color: darkGreen, 
                      fontSize: appSettings.hideBalance ? 40 : 56, // Optionnel : on réduit la taille pour que les étoiles rendent bien
                      fontWeight: FontWeight.w900, 
                      letterSpacing: appSettings.hideBalance ? 0 : -2
                    )
                  ),
                  Text(" / Tn", style: TextStyle(color: darkGreen.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: darkGreen.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
                  child:ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();

                      // 1. On accède au provider pour lire l'état actuel
                      final provider = context.read<UserDataProvider>();
                      
                      // 2. On crée le notifier avec l'état initial du grain sélectionné
                      final favoriteNotifier = ValueNotifier<bool>(provider.isFavorite(selectedGrain));
                      
                      // 3. On crée un lien : si on change le favori dans ChartPage, le provider est mis à jour
                      favoriteNotifier.addListener(() {
                        if (favoriteNotifier.value != provider.isFavorite(selectedGrain)) {
                          provider.toggleFavorite(selectedGrain);
                        }
                      });

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // On passe maintenant les deux paramètres requis
                          builder: (context) => ChartPage(
                            commodityName: selectedGrain,
                            favoriteNotifier: favoriteNotifier,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
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
                  final isFav = context.watch<UserDataProvider>().isFavorite(item["name"]);               return AnimatedContainer(
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
                            border: Border.all(color: isSelected ? darkGreen : Colors.grey.withOpacity(0.15), width: isSelected ? 2 : 1.5),
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
                                _whiteIconButton(Icons.notifications_active_outlined, darkGreen, () {
                                  HapticFeedback.lightImpact();
                                  double defaultPrice = double.tryParse(item["price"].toString()) ?? 0.0;
                                  
                                  // 1. Navigation vers la page graphique (ChartPage)
                                  final provider = context.read<UserDataProvider>();
                                  final favoriteNotifier = ValueNotifier<bool>(provider.isFavorite(item["name"]));
                                  favoriteNotifier.addListener(() {
                                    if (favoriteNotifier.value != provider.isFavorite(item["name"])) {
                                      provider.toggleFavorite(item["name"]);
                                    }
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChartPage(
                                        commodityName: item["name"],
                                        favoriteNotifier: favoriteNotifier,
                                      ),
                                    ),
                                  );

                                  // 2. Affichage direct du popup d'alerte par-dessus la page graphique
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      _showAlertDialog(context, item["name"], defaultPrice);
                                    }
                                  });
                                }),
                                const SizedBox(width: 8),
                                _whiteIconButton(Icons.bar_chart_rounded, darkGreen, () {
                                  HapticFeedback.lightImpact();
                                  final provider = context.read<UserDataProvider>();
                                  final favoriteNotifier = ValueNotifier<bool>(provider.isFavorite(item["name"]));
                                  favoriteNotifier.addListener(() {
                                    if (favoriteNotifier.value != provider.isFavorite(item["name"])) {
                                      provider.toggleFavorite(item["name"]);
                                    }
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChartPage(
                                        commodityName: item["name"],
                                        favoriteNotifier: favoriteNotifier,
                                      ),
                                    ),
                                  );
                                }),
                              ] else ...[
                                GestureDetector(
                                  onTap: () => _toggleFavorite(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: isFav ? Colors.orange.withOpacity(0.8) : darkGreen.withOpacity(0.2),
                                      size: 28,
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
    );
  }

  Widget _whiteIconButton(IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

// --- LES CLASSES DE GRAPHIQUES RESTENT IDENTIQUES ---
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
    
    for (double i = 0; i < size.width; i += 5) {
      canvas.drawLine(Offset(i, size.height / 2), Offset(i + 2, size.height / 2), dashPaint);
    }

    final path = Path();
    final rand = Random(seed);
    int segments = 6;
    double step = size.width / segments;
    List<Offset> pts = [];
    
    for (int i = 0; i <= segments; i++) {
      double x = i * step;
      double noise = rand.nextDouble() * 12;
      double trend = isPositive ? (size.height * 0.75) - (i * 4) : (size.height * 0.25) + (i * 4);
      pts.add(Offset(x, (trend + noise).clamp(2, size.height - 2)));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      path.quadraticBezierTo(pts[i].dx + (pts[i+1].dx - pts[i].dx) / 2, pts[i].dy, pts[i+1].dx, pts[i+1].dy);
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}