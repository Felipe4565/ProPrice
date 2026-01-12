import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'article_detail_page.dart';

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

  final List<String> _categories = ["MERCADO", "SOJA", "TRIGO", "CLIMA", "TECH"];
  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410";
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,ambito.com,clarin.com";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
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
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String agroScope = "+(agro OR mercado OR precios)";
    String query = "";

    if (_isSearching && _searchController.text.isNotEmpty) {
      query = "${_searchController.text} AND $agroScope";
    } else {
      String filter = _categories[_tabController.index];
      switch (filter) {
        case "SOJA": query = "+soja AND $agroScope"; break;
        case "TRIGO": query = "+trigo AND $agroScope"; break;
        case "CLIMA": query = "+(sequia OR lluvias OR pronostico) AND Uruguay"; break;
        case "TECH": query = "+(agrotech OR machinery)"; break;
        default: query = "+(granos OR commodities) AND $agroScope";
      }
    }

    final url = 'https://newsapi.org/v2/everything?q=$query&domains=$_domains&language=es&sortBy=publishedAt&pageSize=20&apiKey=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['articles'] as List).where((a) => 
          a['urlToImage'] != null && a['title'] != null && !a['title'].toString().contains("REMOVED")
        ).toList();

        if (mounted) {
          setState(() {
            _articles = results;
            if (!_isSearching) _cache[_tabController.index] = results;
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
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: forestGreen,
        elevation: 0,
        title: _isSearching ? _buildSearchInput() : _buildModernTitle(),
        actions: [
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
          tabs: _categories.map((c) => Tab(text: c)).toList(),
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
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                    child: Text(
                      "NOTICIAS DESTACADAS",
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.grey, 
                        letterSpacing: 1.2
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final art = _articles[index];
                        String title = art['title'].toString().toLowerCase();
                        
                        // Analyse des tendances (Prix)
                        bool isUp = title.contains("sube") || title.contains("alza") || 
                                   title.contains("récord") || title.contains("suba");
                        bool isDown = title.contains("baja") || title.contains("cae") || 
                                     title.contains("caída");

                        return _buildPremiumCard(art, forestGreen, isUp, isDown);
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

  Widget _buildModernTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("NOTICIAS PROPRICE", 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        Text("TEMAS AGRÍCOLAS", 
          style: TextStyle(fontSize: 9, color: Color(0xFF74C69D), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Buscar noticia...", 
        hintStyle: TextStyle(color: Colors.white54), 
        border: InputBorder.none
      ),
      onSubmitted: (val) => _fetchNews(),
    );
  }

  Widget _buildPremiumCard(dynamic art, Color primary, bool isUp, bool isDown) {
    String time = "Hoy";
    try {
      time = DateFormat('dd MMM, HH:mm').format(DateTime.parse(art['publishedAt']));
    } catch (e) {
      time = "Reciente";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ArticleDetailPage(article: art)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), 
              blurRadius: 15, 
              offset: const Offset(0, 8)
            )
          ],
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
                        errorBuilder: (c, e, s) => Container(
                          color: Colors.grey[100], 
                          child: const Icon(Icons.image_not_supported, color: Colors.grey)
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge Source
                Positioned(
                  top: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7), 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text(
                      art['source']?['name']?.toString().toUpperCase() ?? "NEWS", 
                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                // Indicateur de tendance
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
                  Text(
                    art['title'] ?? '', 
                    style: TextStyle(
                      color: primary, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 17, 
                      height: 1.3
                    ), 
                    maxLines: 3, 
                    overflow: TextOverflow.ellipsis
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
      itemCount: 4, 
      itemBuilder: (c,i) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          height: 280,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}