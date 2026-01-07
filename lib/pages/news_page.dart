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
  
  // Sources professionnelles uniquement
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,ambito.com,clarin.com";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _fetchNews();
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

    // Contextualisation forcée pour éviter le hors-sujet (NewsAPI logic)
    String agroScope = "+(precio OR mercado OR exportacion OR Chicago OR CBOT OR cosecha OR zafra)";
    String query = "";

    if (_isSearching && _searchController.text.isNotEmpty) {
      query = "${_searchController.text} AND $agroScope";
    } else {
      String filter = _categories[_tabController.index];
      switch (filter) {
        case "SOJA": query = "+soja AND $agroScope"; break;
        case "TRIGO": query = "+trigo AND $agroScope"; break;
        case "CLIMA": query = "+(sequia OR lluvias OR pronostico OR Niño OR Niña) AND Uruguay"; break;
        case "TECH": query = "+(agrotech OR maquinaria OR " + '"agricultura de precision"' + ")"; break;
        default: query = "+(granos OR commodities OR cereales) AND $agroScope";
      }
    }

    final url = 'https://newsapi.org/v2/everything?q=$query&domains=$_domains&language=es&sortBy=publishedAt&pageSize=40&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
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
    const Color forestGreen = Color(0xFF1B4332);
    const Color lightLeaf = Color(0xFF74C69D);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      appBar: AppBar(
        backgroundColor: forestGreen,
        elevation: 0,
        title: _isSearching 
          ? _buildSearchInput() 
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PROPRICE MONITOR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text("INTELIGENCIA AGRO", style: TextStyle(fontSize: 9, color: lightLeaf, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ],
            ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNews(),
        color: forestGreen,
        child: _isLoading ? _buildShimmer() : _buildContent(forestGreen),
      ),
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Buscar mercados, puertos...",
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      onSubmitted: (val) => _fetchNews(),
    );
  }

  Widget _buildContent(Color primary) {
    if (_articles.isEmpty) return const Center(child: Text("Sin noticias para este criterio."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final art = _articles[index];
        // Analyse automatique de tendance
        String title = art['title'].toString().toLowerCase();
        bool isUp = title.contains("sube") || title.contains("alza") || title.contains("récord") || title.contains("incremento");
        bool isDown = title.contains("baja") || title.contains("cae") || title.contains("caída") || title.contains("retrocede");

        return _buildPremiumCard(art, primary, isUp, isDown);
      },
    );
  }

  Widget _buildPremiumCard(dynamic art, Color primary, bool isUp, bool isDown) {
    String time = DateFormat('dd MMM, HH:mm').format(DateTime.parse(art['publishedAt']));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(art['url']), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 8,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(art['urlToImage'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[200])),
                  ),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                    child: Text(art['source']['name'].toString().toUpperCase(), 
                      style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ),
                if (isUp || isDown)
                  Positioned(
                    bottom: 12, right: 12,
                    child: CircleAvatar(
                      backgroundColor: isUp ? Colors.green : Colors.red,
                      radius: 18,
                      child: Icon(isUp ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    art['title'], 
                    style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 15, height: 1.3),
                    maxLines: 3,
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
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: 3, 
      itemBuilder: (c,i) => Container(margin: const EdgeInsets.only(bottom: 20), height: 240, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))));
  }
}