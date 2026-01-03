import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<dynamic> _articles = [];
  bool _isLoading = true;
  String _selectedFilter = "TODOS";
  
  // TA CLÉ API NewsAPI.org ICI
  final String _apiKey = "TA_CLE_API_ICI"; 

  @override
  void initState() {
    super.initState();
    _fetchNews(); // Chargement initial
  }

  // Fonction pour charger les news selon le filtre sélectionné
  Future<void> _fetchNews() async {
    setState(() { _isLoading = true; });

    // On adapte la recherche selon le filtre
    String query = "agricultura"; // Par défaut
    if (_selectedFilter == "TRIGO") query = "trigo OR wheat";
    if (_selectedFilter == "SOJA") query = "soja OR soybean";
    if (_selectedFilter == "CLIMA") query = "clima agricultura";
    if (_selectedFilter == "TECH") query = "agrotech";
    if (_selectedFilter == "MERCADO") query = "mercado granos";

    final url = 'https://newsapi.org/v2/everything?q=$query&language=es&sortBy=relevancy&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedArticles = data['articles'];

        // SIMULATION DE CLICS : Comme l'API ne donne pas les clics, 
        // on récupère nos clics locaux sauvegardés pour le tri "TOP"
        final prefs = await SharedPreferences.getInstance();
        for (var art in fetchedArticles) {
          art['localClicks'] = prefs.getInt('clicks_${art['title']}') ?? 0;
        }

        setState(() {
          _articles = fetchedArticles;
          // Si le filtre est "🔥 TOP", on trie par clics locaux
          if (_selectedFilter == "🔥 TOP") {
            _articles.sort((a, b) => b['localClicks'].compareTo(a['localClicks']));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleArticleClick(dynamic article) async {
    final prefs = await SharedPreferences.getInstance();
    int currentClicks = prefs.getInt('clicks_${article['title']}') ?? 0;
    await prefs.setInt('clicks_${article['title']}', currentClicks + 1);
    // On peut ajouter une navigation vers le lien de l'article ici
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);
    
    // L'article à la une est le premier de la liste actuelle
    final featuredArticle = _articles.isNotEmpty ? _articles[0] : null;

    return Column(
      children: [
        const SizedBox(height: 20),
        _buildFilterBar(darkGreen), // Ta barre de filtres est de retour !
        const SizedBox(height: 10),
        
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: darkGreen))
            : RefreshIndicator(
                onRefresh: _fetchNews,
                color: darkGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _articles.length,
                  itemBuilder: (context, index) {
                    final art = _articles[index];
                    if (index == 0) return _buildFeaturedCard(art, darkGreen);
                    return _buildSmallArticle(art, darkGreen);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(Color darkGreen) {
    final filters = ["TODOS", "🔥 TOP", "TRIGO", "SOJA", "CLIMA", "TECH", "MERCADO"];
    return SizedBox(
      height: 40,
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
              _fetchNews(); // On recharge avec le nouveau mot-clé !
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? darkGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? darkGreen : Colors.grey.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: Text(filter, style: TextStyle(color: isSelected ? Colors.white : darkGreen, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard(dynamic art, Color darkGreen) {
    return GestureDetector(
      onTap: () => _handleArticleClick(art),
      child: Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          image: DecorationImage(
            image: NetworkImage(art['urlToImage'] ?? "https://via.placeholder.com/400"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(art['title'] ?? "Sin título", 
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 2),
              const SizedBox(height: 10),
              Text(art['source']['name'] ?? "Noticia", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallArticle(dynamic art, Color darkGreen) {
    return GestureDetector(
      onTap: () => _handleArticleClick(art),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                art['urlToImage'] ?? "https://via.placeholder.com/100", 
                width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.grey[300]),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(art['title'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(art['source']['name'] ?? "", style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}