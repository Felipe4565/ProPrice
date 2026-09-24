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
import 'subscription_plan_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_page_route.dart';
import '../widgets/app_skeleton.dart';
import '../theme/app_theme.dart';
import '../widgets/staggered_fade_in.dart';
import '../widgets/app_bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String selectedGrain = "TRIGO";

  final BiometricService _biometricService = BiometricService();
  // Contrôle le PageView du body : permet à la fois le swipe manuel et la
  // navigation programmatique quand on tape sur la barre du bas.
  late final PageController _pageController = PageController(initialPage: _selectedIndex);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateOnStart();
      _checkWelcomePaywall(); // Vérifie et affiche le pop-up au lancement pour les comptes gratuits
    });
  }

  Future<void> _authenticateOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isBioEnabled = prefs.getBool('bio_enabled') ?? false;

    if (!isBioEnabled) return;

    if (AuthLock.isAuthenticating) return;
    if (AuthLock.lastSuccess != null &&
        DateTime.now().difference(AuthLock.lastSuccess!).inSeconds < 4) {
      return;
    }

    await _authenticate();
  }

  /// Affiche le pop-up de promotion du plan Pro au lancement (pour les utilisateurs gratuits)
  Future<void> _checkWelcomePaywall() async {
    // Petit délai pour laisser le temps au UserDataProvider de charger les données de Supabase
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final provider = context.read<UserDataProvider>();

    // Si l'utilisateur est en plan gratuit
    if (!provider.isPremium) {
      final prefs = await SharedPreferences.getInstance();
      // Optionnel : Si vous voulez l'afficher à *chaque* lancement, ou une seule fois par session/jour.
      // Ici, on utilise un flag de session pour qu'il apparaisse à chaque ouverture de l'app si gratuit.
      bool hasShownThisSession = prefs.getBool('welcome_popup_shown_session') ?? false;

      if (!hasShownThisSession) {
        _showUpgradeDialog(context);
        await prefs.setBool('welcome_popup_shown_session', true);
      }
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.background,
          title: Row(
            children: const [
              Text('🌾 ', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plan Gratuito',
                  style: TextStyle(
                    color: AppColors.forest500,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Desbloquea análisis avanzados, gráficos interactivos completos y límites ilimitados pasando al plan Agricultor Pro.',
            style: TextStyle(
              color: AppColors.forest500.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Más tarde',
                style: TextStyle(color: AppColors.forest500.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  AppPageRoute(builder: (context) => const SubscriptionPlanPage()),
                );
              },
              child: const Text('Ver Planes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricOnResume();
    }
  }

  Future<void> _checkBiometricOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isBioEnabled = prefs.getBool('bio_enabled') ?? false;

    if (!isBioEnabled) return;

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

  /// Affiche un message incitant à passer au plan Premium, avec un bouton
  /// direct vers la page de sélection de plan.
  void _showUpgradeSnackbar(String featureLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Límite del plan gratuito alcanzado ($featureLabel)."),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.orange.shade800,
        action: SnackBarAction(
          label: "VER PLANES",
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              AppPageRoute(builder: (context) => const SubscriptionPlanPage()),
            );
          },
        ),
      ),
    );
  }

  void _toggleFavorite(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();

    final provider = context.read<UserDataProvider>();
    final wasApplied = provider.toggleFavorite(item['name']);

    if (!wasApplied) {
      _showUpgradeSnackbar("máximo ${UserDataProvider.freeFavoritesLimit} favoritos");
      return;
    }

    final isNowFav = provider.isFavorite(item['name']);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNowFav ? "${item['name']} Añadido" : "${item['name']} Eliminado"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.forest600,
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
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    // setState n'est pas appelé ici directement : onPageChanged du PageView
    // s'en charge une fois l'animation de glissement terminée, pour que
    // _selectedIndex reste synchronisé qu'on arrive ici par un tap ou par
    // un swipe manuel sur le contenu.
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _showAlertDialog(BuildContext mainContext, String grainName, double defaultPrice) {
    final provider = context.read<UserDataProvider>();

    // Vérifie la limite du plan gratuit AVANT même d'ouvrir le formulaire.
    if (!provider.canAddMoreAlerts) {
      _showUpgradeSnackbar("máximo ${UserDataProvider.freeAlertsLimit} alertas");
      return;
    }

    final TextEditingController priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );
    final commodityAlerts = provider.alerts
        .where((a) => a['commodity'].toString().toUpperCase() == grainName.toUpperCase())
        .toList();

    showDialog(
      context: mainContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.background,
          title: Row(
            children: const [
              Text('🔔', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text(
                'Définir une alerte',
                style: TextStyle(
                  color: AppColors.forest500,
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
                  color: AppColors.forest500.withValues(alpha: 0.8),
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
                  labelStyle: const TextStyle(color: AppColors.forest500),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: AppColors.forest500.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.forest500, width: 2),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.forest500,
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
                style: TextStyle(color: AppColors.forest500.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest500,
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
                          backgroundColor: AppColors.background,
                          title: const Text(
                            'Alerte existante',
                            style: TextStyle(
                              color: AppColors.forest500,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          content: Text(
                            'Une alerte existe déjà au prix de ${parsedPrice.toStringAsFixed(2)} \$. Êtes-vous sûr de vouloir en placer une autre au même prix ?',
                            style: TextStyle(
                              color: AppColors.forest500.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext),
                              child: Text(
                                'Annuler',
                                style: TextStyle(color: AppColors.forest500.withValues(alpha: 0.6)),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.forest500,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                Navigator.pop(confirmContext);
                                final added = await provider.addAlert(grainName, parsedPrice);
                                if (!mounted) return;
                                if (!added) {
                                  _showUpgradeSnackbar("máximo ${UserDataProvider.freeAlertsLimit} alertas");
                                  return;
                                }
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : $grainName > ${parsedPrice.toStringAsFixed(2)} \$'),
                                    backgroundColor: AppColors.forest500,
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
                    provider.addAlert(grainName, parsedPrice).then((added) {
                      if (!mounted) return;
                      if (!added) {
                        _showUpgradeSnackbar("máximo ${UserDataProvider.freeAlertsLimit} alertas");
                        return;
                      }
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        SnackBar(
                          content: Text('Alerte ajoutée : $grainName > ${parsedPrice.toStringAsFixed(2)} \$'),
                          backgroundColor: AppColors.forest500,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    });
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
    final appSettings = context.watch<AppSettings>();
    const Color darkGreen = AppColors.forest600;

    // Seul l'onglet Profil garde un titre différent dans l'AppBar.
    final String appBarTitle = _selectedIndex == 3 ? 'Mi Perfil' : 'PROPRICE';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          if (_selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: darkGreen),
              onPressed: () {
                Navigator.push(
                  context,
                  AppPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: darkGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: darkGreen,
                        size: 18,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        // Le swipe met à jour _selectedIndex, ce qui fait glisser la
        // pastille de la barre de nav en même temps que le contenu change.
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildHomeContent(darkGreen, appSettings),
          const NewsPage(),
          const SettingsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          AppNavItem(icon: Icons.home_max_rounded, label: 'HOME'),
          AppNavItem(icon: Icons.article_rounded, label: 'NEWS'),
          AppNavItem(icon: Icons.settings_suggest_rounded, label: 'SETTINGS'),
          AppNavItem(icon: Icons.person_rounded, label: 'PROFILE'),
        ],
      ),
    );
  }

  /// Skeletons affichés tant que UserDataProvider n'a pas encore reçu les
  /// données de Supabase (grainsData vide), à la place d'un écran vide.
  Widget _buildHomeSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(height: 12, width: 180),
          const SizedBox(height: 14),
          const AppSkeleton(height: 48, width: 220),
          const SizedBox(height: 30),
          const Expanded(child: AppSkeletonList(count: 5)),
        ],
      ),
    );
  }

  Widget _buildHomeContent(Color darkGreen, AppSettings appSettings) {
    final provider = context.watch<UserDataProvider>();
    final List<Map<String, dynamic>> grainsData = provider.grainsData;

    if (grainsData.isEmpty) {
      return _buildHomeSkeleton();
    }

    List<Map<String, dynamic>> sortedList = List.from(grainsData);
    sortedList.sort((a, b) {
      bool aFav = provider.isFavorite(a["name"]);
      bool bFav = provider.isFavorite(b["name"]);
      if (aFav != bFav) return aFav ? -1 : 1;
      return (a["order"] as int).compareTo(b["order"] as int);
    });

    final currentData = grainsData.firstWhere((g) => g["name"] == selectedGrain);
    final bool isPositive = (currentData["variation"] as String).contains('+');
    final Color trendColor = isPositive ? AppColors.priceUp : AppColors.priceDown;

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 340;
                  final double availableForPrice = isNarrow
                      ? constraints.maxWidth
                      : constraints.maxWidth - 130;

                  final String priceText = appSettings.hideBalance ? "****" : "${currentData["price"]}";

                  double priceFontSize = appSettings.hideBalance ? 40 : 56;
                  final double estimatedCharWidth = priceFontSize * 0.6;
                  final double estimatedTextWidth = (priceText.length * estimatedCharWidth) + 75;
                  if (estimatedTextWidth > availableForPrice) {
                    final double scale = availableForPrice / estimatedTextWidth;
                    priceFontSize = (priceFontSize * scale).clamp(30, priceFontSize);
                  }

                  final priceRow = Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text("\$ ", style: TextStyle(color: darkGreen.withOpacity(0.5), fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        priceText,
                        style: AppTheme.priceStyle(
                          color: darkGreen,
                          fontSize: priceFontSize,
                          letterSpacing: appSettings.hideBalance ? 0 : -2,
                          height: 1.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(" / Tn", style: TextStyle(color: darkGreen.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );

                  final graphButton = Container(
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: darkGreen.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final provider = context.read<UserDataProvider>();
                        final favoriteNotifier = ValueNotifier<bool>(provider.isFavorite(selectedGrain));
                        favoriteNotifier.addListener(() {
                          if (favoriteNotifier.value != provider.isFavorite(selectedGrain)) {
                            provider.toggleFavorite(selectedGrain);
                          }
                        });

                        Navigator.push(
                          context,
                          AppPageRoute(
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
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        priceRow,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: graphButton),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: priceRow),
                      const SizedBox(width: 10),
                      graphButton,
                    ],
                  );
                },
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 30),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: sortedList.asMap().entries.map((entry) {
                            return StaggeredFadeIn(
                              index: entry.key,
                              child: _buildGrainCard(context, entry.value, darkGreen),
                            );
                          }).toList(),
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

  Widget _buildGrainCard(BuildContext context, Map<String, dynamic> item, Color darkGreen) {
    final isSelected = selectedGrain == item["name"];
    final isFav = context.watch<UserDataProvider>().isFavorite(item["name"]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: isSelected ? darkGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onSelectGrain(item["name"]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? darkGreen : Colors.grey.withOpacity(0.15), width: isSelected ? 2 : 1.5),
            ),
            child: Row(
              children: [
                Text(item["emoji"], style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item["name"],
                    style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.w800, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  _whiteIconButton(isFav ? Icons.star_rounded : Icons.star_outline_rounded, isFav ? Colors.orange : darkGreen, () => _toggleFavorite(item)),
                  const SizedBox(width: 8),
                  _whiteIconButton(Icons.notifications_active_outlined, darkGreen, () {
                    HapticFeedback.lightImpact();
                    double defaultPrice = double.tryParse(item["price"].toString()) ?? 0.0;

                    final provider = context.read<UserDataProvider>();
                    final favoriteNotifier = ValueNotifier<bool>(provider.isFavorite(item["name"]));
                    favoriteNotifier.addListener(() {
                      if (favoriteNotifier.value != provider.isFavorite(item["name"])) {
                        provider.toggleFavorite(item["name"]);
                      }
                    });
                    Navigator.push(
                      context,
                      AppPageRoute(
                        builder: (context) => ChartPage(
                          commodityName: item["name"],
                          favoriteNotifier: favoriteNotifier,
                        ),
                      ),
                    );

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
                      AppPageRoute(
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