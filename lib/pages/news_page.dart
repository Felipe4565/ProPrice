import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  List<dynamic> _articles = [];
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _categories = ["MERCADO", "SOJA", "TRIGO", "CLIMA", "TECH"];
  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410";
  
  // Sources de confiance uniquement pour éviter le hors-sujet
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,clarin.com";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchNews(); 
      }
    });
    _fetchNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews({String? searchQuery}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String query = "";
    // On définit des termes métier obligatoires pour garantir la pertinence
    String agroContext = "(precio OR mercado OR exportacion OR Chicago OR cosecha OR zafra)";

    // LOGIQUE DE RECHERCHE AMÉLIORÉE
    if (_isSearching && _searchController.text.isNotEmpty) {
      // Si l'utilisateur cherche, on combine sa recherche avec le contexte agro
      query = "${_searchController.text} AND $agroContext";
    } else {
      // Sinon, on suit les onglets
      String filter = _categories[_tabController.index];
      switch (filter) {
        case "CLIMA":
          query = "(sequia OR lluvias OR pronostico OR clima) AND (campo OR agricultura) AND Uruguay";
          break;
        case "TECH":
          query = "(agrotech OR maquinaria OR " + '"agricultura de precision"' + ")";
          break;
        default:
          query = "$filter AND $agroContext";
      }
    }

    // On utilise 'sortBy=relevancy' pour la recherche et 'publishedAt' pour les onglets
    String sortBy = (_isSearching) ? "relevancy" : "publishedAt";
    
    final url = 'https://newsapi.org/v2/everything?q=$query&domains=$_domains&language=es&sortBy=$sortBy&pageSize=30&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            // Filtrage manuel pour s'assurer qu'il y a une image et que c'est pas un article supprimé
            _articles = (data['articles'] as List).where((a) => 
              a['urlToImage'] != null && 
              a['title'] != null && 
              !a['title'].toString().contains("REMOVED")
            ).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1B4332);
    const Color accent = Color(0xFF40916C);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: primary,
            flexibleSpace: FlexibleSpaceBar(
              title: _isSearching 
                ? _buildSearchInput() 
                : const Text("PROPRICE MONITOR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 65),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 50),
                child: IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _fetchNews(); // On recharge les news normales
                      }
                    });
                  },
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: accent,
                  indicatorWeight: 4,
                  labelColor: primary,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  tabs: _categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () => _fetchNews(),
          color: primary,
          child: _isLoading ? _buildShimmer() : _buildList(primary),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 40),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: "Escribe y pulsa enter...",
          hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
          border: InputBorder.none,
        ),
        onSubmitted: (val) => _fetchNews(), // Lance la recherche au clic sur "Enter"
      ),
    );
  }

  Widget _buildList(Color primary) {
    if (_articles.isEmpty) {
      return const Center(child: Text("No se encontraron noticias específicas."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final art = _articles[index];
        return _buildAgroCard(art, primary);
      },
    );
  }

  Widget _buildAgroCard(dynamic art, Color primary) {
    String date = DateFormat('dd MMM').format(DateTime.parse(art['publishedAt']));
    
    // Analyse de tendance simple pour les flèches
    String title = art['title'].toString().toLowerCase();
    bool isUp = title.contains("sube") || title.contains("alza") || title.contains("récord");
    bool isDown = title.contains("baja") || title.contains("cae");

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(art['url']), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 21 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  art['urlToImage'], 
                  fit: BoxFit.cover,
                  errorBuilder: (c,e,s) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(art['source']['name'].toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 9)),
                      ),
                      const Spacer(),
                      Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(width: 8),
                      if (isUp || isDown) Icon(isUp ? Icons.trending_up : Icons.trending_down, color: isUp ? Colors.green : Colors.red, size: 16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    art['title'], 
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (c, i) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}