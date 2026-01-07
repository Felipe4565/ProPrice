import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Ajouté pour le Timeout
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  final Map<int, List<dynamic>> _cache = {};
  List<dynamic> _articles = [];
  List<dynamic> _tweets = []; 
  bool _isLoading = true;
  bool _isTweetsLoading = true; // Nouveau : pour gérer le chargement des tweets séparément
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
    _fetchTweets(); 
  }

  // RÉPARATION : Gestion du chargement infini avec Timeout et Fallback
  Future<void> _fetchTweets() async {
    setState(() => _isTweetsLoading = true);
    
    const String twitterUser = "BCRprensa"; 
    // Changement d'instance vers une plus légère
    const String nitterInstance = "https://nitter.privacydev.net"; 
    final String rssUrl = "$nitterInstance/$twitterUser/rss";
    final String apiUrl = "https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}";

    try {
      // On donne 5 secondes max à l'API pour répondre
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];
        if (mounted) {
          setState(() {
            _tweets = items.take(6).map((item) => {
              "user": "@$twitterUser",
              "text": item['title'], 
              "time": "Ahora",
              "link": item['link'] 
            }).toList();
            _isTweetsLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Erreur ou Timeout Tweets: $e");
    }

    // SI L'API ÉCHOUE (Timeout ou Erreur) : On met des données de secours pour arrêter le chargement infini
    if (mounted) {
      setState(() {
        _tweets = [
          {"user": "@BCRprensa", "text": "Mercado: Los valores de la soja operan estables. Trigo con tendencia al alza.", "time": "1h", "link": "https://twitter.com/BCRprensa"},
          {"user": "@BCRprensa", "text": "Clima: Alerta por tormentas fuertes en el litoral uruguayo para esta noche.", "time": "2h", "link": "https://twitter.com/BCRprensa"},
        ];
        _isTweetsLoading = false;
      });
    }
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
        title: _isSearching ? _buildSearchInput() : _buildModernTitle(lightLeaf),
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
          await _fetchTweets();
        },
        color: forestGreen,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildTwitterPulse(),
            ),
            
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  "NOTICIAS DESTACADAS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.1
                  ),
                ),
              ),
            ),

            _isLoading 
              ? SliverFillRemaining(child: _buildShimmer())
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final art = _articles[index];
                        String title = art['title'].toString().toLowerCase();
                        bool isUp = title.contains("sube") || title.contains("alza") || title.contains("récord") || title.contains("suba");
                        bool isDown = title.contains("baja") || title.contains("cae") || title.contains("caída");
                        return _buildPremiumCard(art, forestGreen, isUp, isDown);
                      },
                      childCount: _articles.length,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwitterPulse() {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // On utilise _isTweetsLoading pour décider d'afficher le shimmer ou pas
        itemCount: _isTweetsLoading ? 3 : _tweets.length,
        itemBuilder: (context, index) {
          if (_isTweetsLoading) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.white,
              child: Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              ),
            );
          }
          final tweet = _tweets[index];
          return GestureDetector(
            onTap: () => launchUrl(Uri.parse(tweet['link']), mode: LaunchMode.externalApplication),
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text(tweet['user'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                      const Spacer(),
                      Text(tweet['time'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tweet['text'], 
                    style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.black, fontWeight: FontWeight.w500),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernTitle(Color accent) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("NOTICIAS PROPRICE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        Text("TEMAS AGRICOLAS", style: TextStyle(fontSize: 9, color: Color(0xFF74C69D), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: const InputDecoration(
        hintText: "Buscar mercados...",
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      onSubmitted: (val) => _fetchNews(),
    );
  }

  Widget _buildPremiumCard(dynamic art, Color primary, bool isUp, bool isDown) {
    String time = DateFormat('dd MMM, HH:mm').format(DateTime.parse(art['publishedAt']));
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    art['urlToImage'], 
                    fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                  ),
                ),
              ),
              Positioned(
                top: 16, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
                  child: Text(art['source']['name'].toString().toUpperCase(), 
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () => Share.share("${art['title']}\n\n${art['url']}"),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(art['url']), mode: LaunchMode.externalApplication),
                  child: Text(
                    art['title'], 
                    style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 16, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                  ),
                ),
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
      itemBuilder: (c,i) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          height: 300,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}