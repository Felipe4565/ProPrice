import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:proprice/providers/user_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'article_detail_page.dart';
import 'subscription_plan_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_page_route.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/staggered_fade_in.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  final Map<int, List<dynamic>> _cache = {};
  List<dynamic> _articles = [];
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // --- NOUVELLES VARIABLES LOCALISATION ---
  String _userCountry = "Uruguay OR Argentina";
  String _locationDisplay = "MERCADO REGIONAL";

  // Catégories réorganisées : une par matière suivie dans l'appli (même
  // ordre que grainsData dans UserDataProvider), puis les catégories
  // transversales CLIMA / ECONOMÍA / TECH.
  final List<String> _categories = [
    "TRIGO",
    "SOJA",
    "MAIZ",
    "CANOLA",
    "GIRASOL",
    "CLIMA",
    "ECONOMÍA",
    "TECH",
  ];

  // Mots-clés utilisés en filtrage post-requête (pas dans la query elle-même)
  // pour vérifier que l'article est réellement pertinent pour la catégorie.
  // La query envoyée à l'API reste volontairement large (meilleur rappel),
  // et c'est ce filtre qui assure la précision.
  final Map<String, List<String>> _categoryKeywords = {
    "TRIGO": ["trigo"],
    "SOJA": ["soja", "poroto de soja"],
    "MAIZ": ["maiz", "maíz", "corn"],
    "CANOLA": ["canola", "colza"],
    "GIRASOL": ["girasol"],
    "CLIMA": ["sequia", "sequía", "lluvia", "lluvias", "pronostico", "pronóstico", "clima", "helada", "heladas"],
    "ECONOMÍA": ["dolar", "dólar", "retenciones", "exportacion", "exportación", "economia", "economía", "inflacion", "inflación"],
    "TECH": ["agrotech", "tecnologia", "tecnología", "drone", "drones", "riego", "maquinaria", "satelital"],
  };

  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410";
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,ambito.com,clarin.com";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);

    // Initialisation avec détection de pays
    _initLocationAndNews();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_cache.containsKey(_tabController.index) && !_isSearching) {
          setState(() {
            _articles = _cache[_tabController.index]!;
            _isLoading = false;
          });
        } else {
          _fetchNews();
        }
      }
    });
  }

  // --- LOGIQUE LOCALISATION ---
  Future<void> _initLocationAndNews() async {
    await _getUserLocation();
    _fetchNews();
  }

  Future<void> _getUserLocation() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateLocationState(data['country_name'] ?? "");
      }
    } catch (e) {
      debugPrint("Loc error: $e");
    }
  }

  void _updateLocationState(String country) {
    if (!mounted) return;
    setState(() {
      _cache.clear(); // Important : on vide le cache pour forcer la news locale
      if (country == "Uruguay") {
        _userCountry = "Uruguay";
        _locationDisplay = "NOTICIAS DE URUGUAY";
      } else if (country == "Argentina") {
        _userCountry = "Argentina";
        _locationDisplay = "NOTICIAS DE ARGENTINA";
      } else {
        _userCountry = "Uruguay OR Argentina";
        _locationDisplay = "MERCADO REGIONAL";
      }
    });
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Seleccionar Región", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.place, color: AppColors.forest500),
              title: const Text("Uruguay"),
              onTap: () { _updateLocationState("Uruguay"); Navigator.pop(context); _fetchNews(); },
            ),
            ListTile(
              leading: const Icon(Icons.place, color: AppColors.forest500),
              title: const Text("Argentina"),
              onTap: () { _updateLocationState("Argentina"); Navigator.pop(context); _fetchNews(); },
            ),
            ListTile(
              leading: const Icon(Icons.public, color: AppColors.forest500),
              title: const Text("Regional (Ambos)"),
              onTap: () { _updateLocationState("Global"); Navigator.pop(context); _fetchNews(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchNews() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String query = "";
    String filter = _categories[_tabController.index];
    // Mots-clés de pertinence appliqués APRÈS la requête (vide en mode
    // recherche libre : on ne restreint pas ce que l'utilisateur cherche).
    List<String> relevanceKeywords = [];

    if (_isSearching && _searchController.text.isNotEmpty) {
      query = "${_searchController.text} AND (agro OR mercado)";
    } else {
      relevanceKeywords = _categoryKeywords[filter] ?? [];
      // Requêtes volontairement plus larges qu'avant (on retire les AND
      // (mercado OR precios OR ...) qui excluaient beaucoup d'articles
      // pertinents) : le filtrage de pertinence ci-dessous se charge de la
      // précision, ce qui permet d'augmenter le volume d'articles obtenus
      // sans perdre en qualité.
      switch (filter) {
        case "TRIGO":
          query = "trigo AND (agro OR mercado OR precios OR cosecha OR exportacion)"; break;
        case "SOJA":
          query = "soja AND (agro OR mercado OR precios OR cosecha OR exportacion)"; break;
        case "MAIZ":
          query = "(maiz OR maíz OR corn) AND (agro OR mercado OR precios OR cosecha OR exportacion)"; break;
        case "CANOLA":
          query = "(canola OR colza) AND (agro OR mercado OR precios OR exportacion)"; break;
        case "GIRASOL":
          query = "girasol AND (agro OR mercado OR precios OR aceite OR cosecha)"; break;
        case "CLIMA":
          query = "(sequia OR sequía OR lluvias OR pronostico OR pronóstico OR clima OR helada OR heladas) AND $_userCountry"; break;
        case "ECONOMÍA":
          query = "(dolar OR dólar OR retenciones OR exportacion OR exportación OR economia OR economía OR inflacion OR inflación) AND agro"; break;
        case "TECH":
          query = "(agrotech OR drones OR riego OR maquinaria OR tecnologia OR tecnología) AND agro"; break;
        default:
          query = "agro mercado granos";
      }
    }

    // pageSize=100 : c'est le maximum autorisé par NewsAPI (plan Developer),
    // contre 20 auparavant, pour maximiser le nombre d'articles disponibles
    // en une seule requête.
    final url = 'https://newsapi.org/v2/everything?q=$query&domains=$_domains&language=es&sortBy=publishedAt&pageSize=100&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawArticles = (data['articles'] as List?) ?? [];
        final results = _filterAndDeduplicate(rawArticles, relevanceKeywords);

        if (mounted) {
          setState(() {
            _articles = results;
            if (!_isSearching) _cache[_tabController.index] = results;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Filtre et déduplique les articles bruts renvoyés par l'API :
  /// - écarte les articles retirés par NewsAPI ("[Removed]") ou incomplets
  ///   (sans titre, image ou description exploitable)
  /// - écarte les descriptions trop courtes (souvent du bruit / clickbait)
  /// - déduplique les dépêches reprises telles quelles par plusieurs médias
  ///   (comparaison sur un titre normalisé)
  /// - si des [keywords] sont fournies (catégorie thématique), ne garde que
  ///   les articles dont le titre ou la description en contient au moins un,
  ///   ce qui compense l'élargissement de la requête envoyée à l'API.
  List<dynamic> _filterAndDeduplicate(List<dynamic> articles, List<String> keywords) {
    final seenTitles = <String>{};
    final filtered = <dynamic>[];

    for (final a in articles) {
      final title = a['title']?.toString();
      final description = a['description']?.toString();
      final image = a['urlToImage']?.toString();
      final source = (a['source']?['name']?.toString() ?? '').toLowerCase();

      if (title == null || title.trim().isEmpty) continue;
      if (title.toLowerCase().contains('[removed]')) continue;
      if (source == 'removed.com' || source.isEmpty) continue;
      if (image == null || !image.startsWith('http')) continue;
      if (description == null || description.trim().length < 40) continue;

      final normalizedTitle = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9áéíóúñ ]'), '')
          .trim();
      if (seenTitles.contains(normalizedTitle)) continue;

      if (keywords.isNotEmpty) {
        final haystack = '$title $description'.toLowerCase();
        final isRelevant = keywords.any((k) => haystack.contains(k.toLowerCase()));
        if (!isRelevant) continue;
      }

      seenTitles.add(normalizedTitle);
      filtered.add(a);
    }

    return filtered;
  }

  /// Affiche le message "limite atteinte" avec un accès direct au plan Pro.
  void _showDailyLimitReached() {
    const limitSnackbarDuration = Duration(seconds: 4);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Alcanzaste el límite de ${UserDataProvider.freeNewsArticlesLimit} artículos gratis por hoy.",
        ),
        duration: limitSnackbarDuration,
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
    Future.delayed(limitSnackbarDuration, () {
      if (mounted) controller.close();
    });
  }

  /// Ouvre l'article si la limite quotidienne du plan gratuit le permet.
  Future<void> _openArticle(dynamic art) async {
    final provider = context.read<UserDataProvider>();
    final articleId = (art['url'] ?? art['title'] ?? '').toString();

    final allowed = await provider.registerArticleRead(articleId);
    if (!allowed) {
      HapticFeedback.lightImpact();
      _showDailyLimitReached();
      return;
    }

    provider.setLastArticle(art);
    if (!mounted) return;
    Navigator.push(
      context,
      AppPageRoute(builder: (context) => ArticleDetailPage(article: art)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color forestGreen = AppColors.forest500;
    const Color lightLeaf = Color(0xFF74C69D);

    final provider = context.watch<UserDataProvider>();
    final currentCategory = _categories[_tabController.index];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: forestGreen,
        elevation: 0,
        title: _isSearching ? _buildSearchInput() : _buildModernTitle(),
        actions: [
          // BOUTON LOCALISATION AJOUTÉ
          IconButton(
            icon: const Icon(Icons.location_on_outlined, color: Colors.white),
            onPressed: _showLocationPicker,
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _fetchNews();
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: lightLeaf,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: _categories.map((c) {
            final isLocked = !provider.canAccessCategory(c);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c),
                  if (isLocked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline_rounded, size: 12),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await _fetchNews();
        },
        color: forestGreen,
        child: _isLoading
            ? _buildShimmer()
            : !provider.canAccessCategory(currentCategory)
            ? _buildCategoryLockedState(forestGreen, currentCategory)
            : _articles.isEmpty
            ? _buildEmptyState(forestGreen)
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
                child: Text(
                  currentCategory == "CLIMA"
                      ? "CLIMA: $_userCountry".toUpperCase()
                      : "NOTICIAS ACTUALIZADAS",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                ),
              ),
            ),
            if (!provider.isPremium)
              SliverToBoxAdapter(
                child: _buildDailyLimitBanner(forestGreen, provider),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final art = _articles[index];
                    String title = art['title'].toString().toLowerCase();
                    bool isUp = title.contains("sube") || title.contains("alza") || title.contains("suba");
                    bool isDown = title.contains("baja") || title.contains("cae") || title.contains("caída");
                    return StaggeredFadeIn(
                      index: index,
                      child: _buildPremiumCard(art, forestGreen, isUp, isDown),
                    );
                  },
                  childCount: _articles.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyLimitBanner(Color primary, UserDataProvider provider) {
    final remaining = provider.articlesRemainingToday;
    final reached = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: reached ? Colors.orange.withOpacity(0.12) : primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 16,
              color: reached ? Colors.orange.shade800 : primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reached
                    ? "Límite diario de artículos alcanzado"
                    : "$remaining/${UserDataProvider.freeNewsArticlesLimit} artículos gratis restantes hoy",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: reached ? Colors.orange.shade800 : primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  AppPageRoute(builder: (context) => const SubscriptionPlanPage()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text("PRO", style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryLockedState(Color primary, String category) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 70, color: primary.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(
              "Categoría $category disponible en Pro",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              "Actualiza a Agricultor Pro para acceder a todas las categorías de noticias.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  AppPageRoute(builder: (context) => const SubscriptionPlanPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("VER PLANES", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text("No hay noticias recientes", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            Text("No encontramos artículos pour $_userCountry hoy.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => _fetchNews(),
              icon: Icon(Icons.refresh, color: primary),
              label: Text("Reintentar", style: TextStyle(color: primary)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModernTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PROPRICE NEWS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        Text(_locationDisplay, style: const TextStyle(fontSize: 9, color: Color(0xFF74C69D), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(hintText: "Buscar noticia...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
      onSubmitted: (val) => _fetchNews(),
    );
  }

  Widget _buildPremiumCard(dynamic art, Color primary, bool isUp, bool isDown) {
    String time = "Reciente";
    try {
      time = DateFormat('dd MMM, HH:mm').format(DateTime.parse(art['publishedAt']));
    } catch (e) {}

    return GestureDetector(
      onTap: () => _openArticle(art),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Hero(
                      tag: art['url'] ?? '',
                      child: Image.network(
                        art['urlToImage'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text(art['source']?['name']?.toString().toUpperCase() ?? "AGRO", style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (isUp || isDown)
                  Positioned(
                    top: 16, right: 16,
                    child: CircleAvatar(
                      backgroundColor: isUp ? Colors.green : Colors.red,
                      radius: 18,
                      child: Icon(isUp ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => Share.share("${art['title']}\n\n${art['url']}"),
                        child: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(art['title'] ?? '', style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 17, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Squelette d'une carte d'article : image 16/9 + bloc titre, dans le même
  /// conteneur (radius 24, ombre légère) que _buildPremiumCard, pour que le
  /// passage skeleton → contenu réel ne "saute" pas visuellement.
  Widget _buildNewsCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AppSkeleton(
              height: double.infinity,
              width: double.infinity,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(height: 11, width: 80),
                SizedBox(height: 14),
                AppSkeleton(height: 16, width: double.infinity),
                SizedBox(height: 8),
                AppSkeleton(height: 16, width: 180),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (c, i) => _buildNewsCardSkeleton(),
    );
  }
}