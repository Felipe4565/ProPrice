import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart'; // Pour l'effet de chargement pro
import 'package:url_launcher/url_launcher.dart'; // Pour ouvrir l'article
import 'package:intl/intl.dart'; // Pour les dates

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<dynamic> _articles = [];
  bool _isLoading = true;
  String _selectedFilter = "TODOS";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410"; // <--- METS TA CLÉ ICI

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews({String? searchQuery}) async {
    setState(() => _isLoading = true);

    String query = searchQuery ?? "agricultura";
    if (searchQuery == null) {
      if (_selectedFilter == "TRIGO") query = "trigo OR wheat";
      else if (_selectedFilter == "SOJA") query = "soja OR soybean";
      else if (_selectedFilter == "CLIMA") query = "clima agricultura";
      else if (_selectedFilter == "TECH") query = "agrotech";
      else if (_selectedFilter == "MERCADO") query = "mercado granos";
    }

    final url = 'https://newsapi.org/v2/everything?q=$query&language=es&sortBy=publishedAt&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _articles = data['articles'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Fonction pour ouvrir le lien de l'article
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);

    return Column(
      children: [
        _buildHeader(darkGreen),
        if (!_isSearching) _buildFilterBar(darkGreen),
        Expanded(
          child: _isLoading ? _buildShimmerEffect() : _buildList(darkGreen),
        ),
      ],
    );
  }

  // --- BARRE DE RECHERCHE & TITRE ---
  Widget _buildHeader(Color darkGreen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          if (!_isSearching)
            const Text("NOTICIAS", style: TextStyle(color: Color(0xFF1B4D3E), fontWeight: FontWeight.w900, fontSize: 22))
          else
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Buscar noticias...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: darkGreen.withOpacity(0.4)),
                ),
                onSubmitted: (val) {
                  if (val.isNotEmpty) _fetchNews(searchQuery: val);
                },
              ),
            ),
          const Spacer(),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: darkGreen),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _fetchNews();
                }
              });
            },
          )
        ],
      ),
    );
  }

  // --- FILTRES ---
  Widget _buildFilterBar(Color darkGreen) {
    final filters = ["TODOS", "TRIGO", "SOJA", "CLIMA", "TECH", "MERCADO"];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = filter);
              _fetchNews();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? darkGreen : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isSelected ? [BoxShadow(color: darkGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                border: Border.all(color: isSelected ? darkGreen : Colors.grey.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: Text(filter, style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          );
        },
      ),
    );
  }

  // --- LISTE DES ARTICLES ---
  Widget _buildList(Color darkGreen) {
    return RefreshIndicator(
      onRefresh: _fetchNews,
      color: darkGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final art = _articles[index];
          if (index == 0 && !_isSearching) return _buildFeatured(art, darkGreen);
          return _buildTile(art, darkGreen);
        },
      ),
    );
  }

  // --- ARTICLE À LA UNE ---
  Widget _buildFeatured(dynamic art, Color darkGreen) {
    return GestureDetector(
      onTap: () => _launchURL(art['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 25),
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(art['urlToImage'] ?? "https://via.placeholder.com/400", fit: BoxFit.cover, 
                errorBuilder: (c,e,s) => Container(color: Colors.grey[300])),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)]),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(art['source']['name'].toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10)),
                    const SizedBox(height: 8),
                    Text(art['title'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2), maxLines: 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PETIT ARTICLE ---
  Widget _buildTile(dynamic art, Color darkGreen) {
    String timeAgo = "";
    if (art['publishedAt'] != null) {
      DateTime date = DateTime.parse(art['publishedAt']);
      timeAgo = DateFormat('dd/MM HH:mm').format(date);
    }

    return GestureDetector(
      onTap: () => _launchURL(art['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(art['urlToImage'] ?? "https://via.placeholder.com/100", width: 85, height: 85, fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(width: 85, height: 85, color: Colors.grey[200])),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(art['source']['name'] ?? "", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(art['title'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
                  const SizedBox(height: 8),
                  Text(timeAgo, style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- EFFET DE CHARGEMENT SHIMMER ---
  Widget _buildShimmerEffect() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}