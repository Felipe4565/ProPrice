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

class _NewsPageState extends State<NewsPage> {
  List<dynamic> _articles = [];
  bool _isLoading = true;
  String _selectedFilter = "TODOS";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410"; 

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews({String? searchQuery}) async {
    setState(() => _isLoading = true);

    // Ciblage géographique et thématique strict
    String regionQuery = "(Uruguay OR Argentina OR CBOT OR Chicago)";
    String mandatoryTerms = "(precio OR mercado OR exportacion OR granos OR zafra)";
    String query = "";

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = "$mandatoryTerms AND ($searchQuery)";
    } else {
      switch (_selectedFilter) {
        case "TRIGO":
          query = "trigo AND $mandatoryTerms AND $regionQuery";
          break;
        case "SOJA":
          query = "soja AND $mandatoryTerms AND $regionQuery";
          break;
        case "CLIMA":
          query = "(sequia OR lluvias OR clima) AND (agricultura OR campo) AND Uruguay";
          break;
        case "TECH":
          query = "(agrotech OR precision OR maquinaria) AND agricultura";
          break;
        case "MERCADO":
          query = "(dolar OR bolsa OR commodities) AND $mandatoryTerms AND $regionQuery";
          break;
        default:
          query = "agricultura AND $mandatoryTerms AND $regionQuery";
      }
    }

    // On utilise 'relevancy' pour avoir les news les plus "Agro" et non les plus "récentes inutiles"
    final url = 'https://newsapi.org/v2/everything?q=$query&language=es&sortBy=relevancy&pageSize=30&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> rawArticles = data['articles'];

        setState(() {
          _articles = rawArticles.where((a) => 
            a['urlToImage'] != null && 
            a['title'] != null &&
            !a['title'].toString().contains("REMOVED")
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fond gris très clair "App Pro"
      body: Column(
        children: [
          _buildHeader(darkGreen),
          _buildFilterBar(darkGreen),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchNews(),
              color: darkGreen,
              child: _isLoading ? _buildShimmerEffect() : _buildList(darkGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color darkGreen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
      color: Colors.white,
      child: Row(
        children: [
          if (!_isSearching)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MONITOR AGRO", style: TextStyle(color: Color(0xFF1B4D3E), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                Text("Precios y Mercados", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
              ],
            )
          else
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(hintText: "Buscar mercado, puerto...", border: InputBorder.none),
                  onSubmitted: (val) => _fetchNews(searchQuery: val),
                ),
              ),
            ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) { _searchController.clear(); _fetchNews(); }
              });
            },
            child: CircleAvatar(
              backgroundColor: darkGreen.withOpacity(0.1),
              child: Icon(_isSearching ? Icons.close : Icons.search, color: darkGreen, size: 20),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterBar(Color darkGreen) {
    final filters = ["TODOS", "MERCADO", "SOJA", "TRIGO", "CLIMA", "TECH"];
    return Container(
      height: 55,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedFilter = filter);
                _fetchNews();
              },
              selectedColor: darkGreen,
              backgroundColor: Colors.grey[50],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : darkGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isSelected ? darkGreen : Colors.grey[200]!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(Color darkGreen) {
    if (_articles.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: Text("No hay noticias específicas para este rubro ahora.", textAlign: TextAlign.center),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final art = _articles[index];
        return _buildNewsCard(art, darkGreen);
      },
    );
  }

  Widget _buildNewsCard(dynamic art, Color darkGreen) {
    return GestureDetector(
      onTap: () => _launchURL(art['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                art['urlToImage'], 
                height: 160, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(height: 160, color: Colors.grey[100]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(art['source']['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 9)),
                      const Spacer(),
                      Text(DateFormat('dd MMM').format(DateTime.parse(art['publishedAt'])), style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    art['title'] ?? "", 
                    style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
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

  Widget _buildShimmerEffect() {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          height: 220,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}