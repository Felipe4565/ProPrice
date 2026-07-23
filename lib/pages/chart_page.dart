import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/data.dart';
import '../providers/user_data_provider.dart';
import '../services/auth_lock.dart';

class ChartPage extends StatefulWidget {
  final String commodityName;
  final ValueNotifier<bool> favoriteNotifier;

  const ChartPage({
    super.key,
    required this.commodityName,
    required this.favoriteNotifier,
  });

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  CandleData? selectedCandle; 
  String selectedPeriod = "1D";
  final List<String> periods = ["1D", "1W", "1M", "3M", "1Y"];
  bool isCandleView = false; // <-- Vue courbe par défaut
  DateTime lastUpdateTime = DateTime.now();

  // Configuration API et Domaines Actualités
  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410";
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,ambito.com,clarin.com";

  @override
  void initState() {
    super.initState();
    lastUpdateTime = DateTime.now();
  }

  String _getContractInfo() {
    switch (widget.commodityName.toUpperCase()) {
      case "BLÉ" || "TRIGO": return "Blé Meunier • Décembre 2026";
      case "MAÏS" || "MAIZ": return "Maïs Euronext • Novembre 2026";
      case "COLZA" || "CANOLA": return "Colza 00 • Février 2027";
      default: return "${widget.commodityName} • Echéance Proche";
    }
  }

  String _getSearchQuery() {
    switch (widget.commodityName.toUpperCase()) {
      case "BLÉ": return "trigo OR blé";
      case "MAÏS": return "maiz OR maíz OR maïs";
      case "COLZA": return "colza OR canola";
      default: return widget.commodityName;
    }
  }

  List<String> _getKeywordsForFiltering() {
    switch (widget.commodityName.toUpperCase()) {
      case "BLÉ": return ["trigo", "blé", "wheat"];
      case "MAÏS": return ["maiz", "maíz", "maïs", "corn"];
      case "COLZA": return ["colza", "canola", "rapeseed"];
      default: return [widget.commodityName.toLowerCase()];
    }
  }

  Future<List<dynamic>> _fetchNews() async {
    final query = _getSearchQuery();
    final url = Uri.parse(
      'https://newsapi.org/v2/everything?q=${Uri.encodeComponent(query)}&domains=$_domains&apiKey=$_apiKey&sortBy=publishedAt&pageSize=15',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          List articles = data['articles'] ?? [];
          final keywords = _getKeywordsForFiltering();
          
          return articles.where((article) {
            final title = (article['title'] ?? '').toLowerCase();
            final description = (article['description'] ?? '').toLowerCase();
            return keywords.any((kw) => title.contains(kw) || description.contains(kw));
          }).take(5).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  TextAnchor _getHorizontalAlignment(double price, List<CandleData> data) {
    if (data.isEmpty) return TextAnchor.start;
    
    List<int> crossingIndices = [];
    for (int i = 0; i < data.length; i++) {
      if (price >= data[i].low && price <= data[i].high) {
        crossingIndices.add(i);
      }
    }

    if (crossingIndices.isNotEmpty) {
      double avgIndex = crossingIndices.reduce((a, b) => a + b) / crossingIndices.length;
      return avgIndex >= data.length / 2 ? TextAnchor.start : TextAnchor.end;
    } else {
      int closestIndex = 0;
      double minDistance = double.infinity;
      for (int i = 0; i < data.length; i++) {
        double midCandle = (data[i].high + data[i].low) / 2;
        double dist = (midCandle - price).abs();
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }
      return closestIndex >= data.length / 2 ? TextAnchor.start : TextAnchor.end;
    }
  }

  void _showAlertDialog(BuildContext mainContext, double defaultPrice, UserDataProvider provider, List<Map<String, dynamic>> commodityAlerts) {
    final TextEditingController priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );

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
                'Entrez le seuil de prix pour ${widget.commodityName} :',
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
                                provider.addAlert(widget.commodityName, parsedPrice);
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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
                    provider.addAlert(widget.commodityName, parsedPrice);
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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
    final provider = context.watch<UserDataProvider>();
    final commodityAlerts = provider.alerts
        .where((a) => a['commodity'].toString().toUpperCase() == widget.commodityName.toUpperCase())
        .toList();
    final activeAlertPrices = commodityAlerts.map((a) => a['price'] as double).toList();

    final rawData = generateMarketData(widget.commodityName, selectedPeriod);
    final displayCandle = selectedCandle ?? rawData.last;
    final firstPrice = rawData.first.open;
    final diff = ((displayCandle.close - firstPrice) / firstPrice) * 100;

    // --- AUTO-SCALE INTELLIGENT SELON LA PÉRIODE ---
    double yMin = rawData.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    double yMax = rawData.map((e) => e.high).reduce((a, b) => a > b ? a : b);

    for (var price in activeAlertPrices) {
      if (price < yMin) yMin = price;
      if (price > yMax) yMax = price;
    }

    double priceRange = yMax - yMin;
    double padding = priceRange == 0 ? 2.0 : priceRange * 0.08;

    final double chartMin = yMin - padding;
    final double chartMax = yMax + padding;
    final double midPrice = (chartMin + chartMax) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B4332)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.commodityName, 
            style: const TextStyle(color: Color(0xFF1B4332), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Text('⛶', style: TextStyle(fontSize: 22, color: Color(0xFF1B4332), fontWeight: FontWeight.bold)),
            tooltip: "Plein écran paysage",
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenChartPage(
                    commodityName: widget.commodityName,
                    initialPeriod: selectedPeriod,
                    favoriteNotifier: widget.favoriteNotifier,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF1B4332), size: 26),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await Share.share('Regarde l\'évolution du cours pour : ${widget.commodityName}');
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.favoriteNotifier,
            builder: (context, isFavorite, _) {
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? Colors.amber : const Color(0xFF1B4332),
                  size: 28,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.favoriteNotifier.value = !isFavorite;
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildContractInfo(),
            _buildPriceHeader(displayCandle.close, diff, provider, commodityAlerts),
            _buildViewToggle(),
            _buildPeriodSelector(),

            // Zone du graphique
            Container(
              height: 420,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SfCartesianChart(
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    lineColor: Colors.blueGrey.withValues(alpha: 0.5), 
                    lineWidth: 1.5, 
                    lineDashArray: const [5, 5], 
                    markerSettings: const TrackballMarkerSettings(
                      markerVisibility: TrackballVisibilityMode.visible,
                      color: Colors.white,
                      borderColor: Colors.blueGrey,
                      borderWidth: 2,
                      height: 8,
                      width: 8,
                    ),
                    tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
                  ),

                  primaryXAxis: DateTimeAxis(
                    majorGridLines: const MajorGridLines(width: 0), 
                    axisLine: const AxisLine(width: 1, color: Colors.grey),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: chartMin,
                    maximum: chartMax,
                    majorGridLines: const MajorGridLines(width: 0.5, color: Colors.black12), 
                    axisLine: const AxisLine(width: 0), 
                    plotBands: activeAlertPrices.map((price) {
                      return PlotBand(
                        start: price,
                        end: price,
                        borderColor: Colors.grey.shade500,
                        borderWidth: 1.5,
                        dashArray: const [3, 3],
                        text: '${price.toStringAsFixed(2)} \$',
                        textStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        horizontalTextAlignment: _getHorizontalAlignment(price, rawData),
                        verticalTextAlignment: price >= midPrice ? TextAnchor.end : TextAnchor.start,
                      );
                    }).toList(),
                  ),

                  series: isCandleView
                      ? <CartesianSeries<CandleData, DateTime>>[
                          CandleSeries<CandleData, DateTime>(
                            dataSource: rawData,
                            bearColor: const Color(0xFFE53935), 
                            bullColor: const Color(0xFF43A047), 
                            enableSolidCandles: true,
                            xValueMapper: (data, _) => data.date,
                            lowValueMapper: (data, _) => data.low,
                            highValueMapper: (data, _) => data.high,
                            openValueMapper: (data, _) => data.open,
                            closeValueMapper: (data, _) => data.close,
                            onPointTap: (ChartPointDetails details) {
                              if (details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                setState(() {
                                  selectedCandle = rawData[details.pointIndex!];
                                });
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ]
                      : <CartesianSeries<CandleData, DateTime>>[
                          FastLineSeries<CandleData, DateTime>(
                            dataSource: rawData,
                            xValueMapper: (data, _) => data.date,
                            yValueMapper: (data, _) => data.close,
                            color: const Color(0xFF1B4332),
                            width: 2,
                            markerSettings: MarkerSettings(
                              isVisible: selectedPeriod == "1D" || selectedPeriod == "1W",
                              height: 5,
                              width: 5,
                              color: const Color(0xFF1B4332),
                              borderColor: Colors.white,
                              borderWidth: 1,
                            ),
                            onPointTap: (ChartPointDetails details) {
                              if (details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                setState(() {
                                  selectedCandle = rawData[details.pointIndex!];
                                });
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ],
                ),
              ),
            ),

            if (selectedCandle != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Stack(
                  children: [
                    _buildStatsGrid(selectedCandle!),
                    Positioned(
                      right: 0, top: 0,
                      child: IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => selectedCandle = null),
                      ),
                    )
                  ],
                ),
              ),

            _buildAlertSection(provider, commodityAlerts),
            _buildNewsSection(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertSection(UserDataProvider provider, List<Map<String, dynamic>> commodityAlerts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'ALERTES ACTIVES (${commodityAlerts.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B4332).withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (commodityAlerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
              ),
              child: Text(
                'Aucune alerte active pour le moment.',
                style: TextStyle(
                  color: const Color(0xFF1B4332).withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...commodityAlerts.map((alertMap) {
              final alertPrice = alertMap['price'] as double;
              final globalIndex = provider.alerts.indexOf(alertMap);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF1B4332)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.commodityName.toUpperCase()} > ${alertPrice.toStringAsFixed(2)} \$',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B4332),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade400),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (globalIndex != -1) {
                          provider.removeAlert(globalIndex);
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('📰', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'ACTUALITÉS - ${widget.commodityName.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B4332).withValues(alpha: 0.6),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<dynamic>>(
            future: _fetchNews(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 220,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: const CircularProgressIndicator(color: Color(0xFF1B4332)),
                );
              }
              
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: Text(
                    'Aucune actualité récente trouvée pour ${widget.commodityName}.',
                    style: TextStyle(
                      color: const Color(0xFF1B4332).withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final articles = snapshot.data!;

              return SizedBox(
                height: 310,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: articles.length,
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    final title = article['title'] ?? 'Sans titre';
                    final description = article['description'] ?? title;
                    final imageUrl = article['urlToImage'];
                    final sourceName = article['source']?['name'] ?? 'Source inconnue';
                    final url = article['url'] ?? '';
                    final publishedAtStr = article['publishedAt'];
                    String formattedDate = '';
                    if (publishedAtStr != null) {
                      try {
                        final dt = DateTime.parse(publishedAtStr);
                        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                      } catch (_) {}
                    }

                    return Container(
                      width: 280,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            if (url.isNotEmpty) {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 120,
                                          color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                                          child: const Center(
                                            child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF1B4332)),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 120,
                                        color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                                        child: const Center(
                                          child: Icon(Icons.article_outlined, color: Color(0xFF1B4332), size: 30),
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  sourceName,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1B4332),
                                                  ),
                                                ),
                                              ),
                                              if (formattedDate.isNotEmpty)
                                                Text(
                                                  formattedDate,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: const Color(0xFF1B4332).withValues(alpha: 0.4),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1B4332),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF1B4332).withValues(alpha: 0.7),
                                          fontSize: 11,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContractInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 20, color: Color(0xFF1B4332)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CONTRAT SÉLECTIONNÉ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1B4332).withValues(alpha: 0.5))),
                  Text(_getContractInfo(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1B4332))),
                ],
              ),
            ],
          ),
          Text(
            "Màj: ${DateFormat('HH:mm').format(lastUpdateTime)}",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1B4332).withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        height: 45,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Row(
          children: [
            _toggleOption("Bougies", Icons.candlestick_chart_rounded, true),
            _toggleOption("Courbe", Icons.show_chart_rounded, false),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption(String label, IconData icon, bool isCandleOption) {
    bool isSelected = isCandleView == isCandleOption;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isCandleView = isCandleOption),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF1B4332)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF1B4332))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHeader(double price, double diff, UserDataProvider provider, List<Map<String, dynamic>> commodityAlerts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$${price.toStringAsFixed(2)}", 
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1B4332)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: diff >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}%", 
                  style: TextStyle(
                    color: diff >= 0 ? Colors.green.shade700 : Colors.red.shade700, 
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              final rawData = generateMarketData(widget.commodityName, selectedPeriod);
              final displayCandle = selectedCandle ?? rawData.last;
              _showAlertDialog(context, displayCandle.close, provider, commodityAlerts);
            },
            icon: const Text('🔔', style: TextStyle(fontSize: 14)),
            label: const Text('Alerte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: periods.map((p) => _buildPeriodButton(p)).toList(),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    bool isSelected = selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            selectedPeriod = period;
            lastUpdateTime = DateTime.now();
            selectedCandle = null; 
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(period, style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSelected ? Colors.white : const Color(0xFF1B4332).withValues(alpha: 0.5)
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(CandleData c) {
    return Column(
      children: [
        Text(
          DateFormat('dd MMM yyyy HH:mm').format(c.date),
          style: TextStyle(color: const Color(0xFF1B4332).withValues(alpha: 0.6), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem("OPEN", c.open.toStringAsFixed(2)),
            _statItem("HIGH", c.high.toStringAsFixed(2)),
            _statItem("LOW", c.low.toStringAsFixed(2)),
            _statItem("CLOSE", c.close.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: const Color(0xFF1B4332).withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Color(0xFF1B4332), fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ==========================================
// PAGE PLEIN ÉCRAN PAYSAGE ENRICHIE
// ==========================================
class FullScreenChartPage extends StatefulWidget {
  final String commodityName;
  final String initialPeriod;
  final ValueNotifier<bool> favoriteNotifier;

  const FullScreenChartPage({
    super.key,
    required this.commodityName,
    required this.initialPeriod,
    required this.favoriteNotifier,
  });

  @override
  State<FullScreenChartPage> createState() => _FullScreenChartPageState();
}

class _FullScreenChartPageState extends State<FullScreenChartPage> {
  late String selectedPeriod;
  bool isCandleView = false; // <-- Vue courbe par défaut en plein écran aussi
  CandleData? selectedCandle;
  final List<String> periods = ["1D", "1W", "1M", "3M", "1Y"];

  @override
  void initState() {
    super.initState();
    selectedPeriod = widget.initialPeriod;
    
    AuthLock.isFullScreenActive = true;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    AuthLock.skipUntil = DateTime.now().add(const Duration(seconds: 1));
    AuthLock.isFullScreenActive = false;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  TextAnchor _getHorizontalAlignment(double price, List<CandleData> data) {
    if (data.isEmpty) return TextAnchor.start;
    
    List<int> crossingIndices = [];
    for (int i = 0; i < data.length; i++) {
      if (price >= data[i].low && price <= data[i].high) {
        crossingIndices.add(i);
      }
    }

    if (crossingIndices.isNotEmpty) {
      double avgIndex = crossingIndices.reduce((a, b) => a + b) / crossingIndices.length;
      return avgIndex >= data.length / 2 ? TextAnchor.start : TextAnchor.end;
    } else {
      int closestIndex = 0;
      double minDistance = double.infinity;
      for (int i = 0; i < data.length; i++) {
        double midCandle = (data[i].high + data[i].low) / 2;
        double dist = (midCandle - price).abs();
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }
      return closestIndex >= data.length / 2 ? TextAnchor.start : TextAnchor.end;
    }
  }

  void _showFullScreenAlertDialog(BuildContext mainContext, double defaultPrice, UserDataProvider provider, List<Map<String, dynamic>> commodityAlerts) {
    final TextEditingController priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );

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
                'Entrez le seuil de prix pour ${widget.commodityName} :',
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
                                provider.addAlert(widget.commodityName, parsedPrice);
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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
                    provider.addAlert(widget.commodityName, parsedPrice);
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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

  Widget _buildCompactPeriodButton(String period) {
    bool isSelected = selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          selectedPeriod = period;
          selectedCandle = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          period,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF1B4332),
          ),
        ),
      ),
    );
  }

  Widget _compactToggleOption(String label, bool isCandleOption) {
    bool isSelected = isCandleView == isCandleOption;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => isCandleView = isCandleOption);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF1B4332),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserDataProvider>();
    final commodityAlerts = provider.alerts
        .where((a) => a['commodity'].toString().toUpperCase() == widget.commodityName.toUpperCase())
        .toList();
    final activeAlertPrices = commodityAlerts.map((a) => a['price'] as double).toList();

    final rawData = generateMarketData(widget.commodityName, selectedPeriod);

    // --- AUTO-SCALE PLEIN ÉCRAN SELON LA PÉRIODE ---
    double yMin = rawData.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    double yMax = rawData.map((e) => e.high).reduce((a, b) => a > b ? a : b);

    for (var price in activeAlertPrices) {
      if (price < yMin) yMin = price;
      if (price > yMax) yMax = price;
    }

    double priceRange = yMax - yMin;
    double padding = priceRange == 0 ? 2.0 : priceRange * 0.08;

    final double chartMin = yMin - padding;
    final double chartMax = yMax + padding;
    final double midPrice = (chartMin + chartMax) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_fullscreen_rounded, color: Color(0xFF1B4332), size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.commodityName,
                        style: const TextStyle(
                          color: Color(0xFF1B4332),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: periods.map((p) => _buildCompactPeriodButton(p)).toList(),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: 32,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _compactToggleOption("Bougies", true),
                            _compactToggleOption("Courbe", false),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(Icons.insights_rounded, color: Color(0xFF1B4332), size: 20),
                        tooltip: "Indicateurs techniques",
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Indicateurs techniques : Bientôt disponible'),
                              backgroundColor: const Color(0xFF1B4332),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Text('🔔', style: TextStyle(fontSize: 16)),
                        tooltip: "Définir une alerte",
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showFullScreenAlertDialog(context, rawData.last.close, provider, commodityAlerts);
                        },
                      ),
                      const SizedBox(width: 4),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.favoriteNotifier,
                        builder: (context, isFavorite, _) {
                          return IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            icon: Icon(
                              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFavorite ? Colors.amber : const Color(0xFF1B4332),
                              size: 22,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.favoriteNotifier.value = !isFavorite;
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SfCartesianChart(
                    trackballBehavior: TrackballBehavior(
                      enable: true,
                      activationMode: ActivationMode.singleTap,
                      lineColor: Colors.blueGrey.withValues(alpha: 0.5),
                      lineWidth: 1.5,
                      lineDashArray: const [5, 5],
                      markerSettings: const TrackballMarkerSettings(
                        markerVisibility: TrackballVisibilityMode.visible,
                        color: Colors.white,
                        borderColor: Colors.blueGrey,
                        borderWidth: 2,
                        height: 8,
                        width: 8,
                      ),
                      tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
                    ),
                    primaryXAxis: DateTimeAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 1, color: Colors.grey),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: chartMin,
                      maximum: chartMax,
                      majorGridLines: const MajorGridLines(width: 0.5, color: Colors.black12),
                      axisLine: const AxisLine(width: 0),
                      plotBands: activeAlertPrices.map((price) {
                        return PlotBand(
                          start: price,
                          end: price,
                          borderColor: Colors.grey.shade500,
                          borderWidth: 1.5,
                          dashArray: const [3, 3],
                          text: '${price.toStringAsFixed(2)} \$',
                          textStyle: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          horizontalTextAlignment: _getHorizontalAlignment(price, rawData),
                          verticalTextAlignment: price >= midPrice ? TextAnchor.end : TextAnchor.start,
                        );
                      }).toList(),
                    ),
                    series: isCandleView
                        ? <CartesianSeries<CandleData, DateTime>>[
                            CandleSeries<CandleData, DateTime>(
                              dataSource: rawData,
                              bearColor: const Color(0xFFE53935),
                              bullColor: const Color(0xFF43A047),
                              enableSolidCandles: true,
                              xValueMapper: (data, _) => data.date,
                              lowValueMapper: (data, _) => data.low,
                              highValueMapper: (data, _) => data.high,
                              openValueMapper: (data, _) => data.open,
                              closeValueMapper: (data, _) => data.close,
                              onPointTap: (ChartPointDetails details) {
                                if (details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                  setState(() {
                                    selectedCandle = rawData[details.pointIndex!];
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                            ),
                          ]
                        : <CartesianSeries<CandleData, DateTime>>[
                            FastLineSeries<CandleData, DateTime>(
                              dataSource: rawData,
                              xValueMapper: (data, _) => data.date,
                              yValueMapper: (data, _) => data.close,
                              color: const Color(0xFF1B4332),
                              width: 2,
                              markerSettings: MarkerSettings(
                                isVisible: selectedPeriod == "1D" || selectedPeriod == "1W",
                                height: 5,
                                width: 5,
                                color: const Color(0xFF1B4332),
                                borderColor: Colors.white,
                                borderWidth: 1,
                              ),
                              onPointTap: (ChartPointDetails details) {
                                if (details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                  setState(() {
                                    selectedCandle = rawData[details.pointIndex!];
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                            ),
                          ],
                  ),
                ),
              ),
            ),
            if (selectedCandle != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(selectedCandle!.date),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B4332)),
                    ),
                    Text('O: ${selectedCandle!.open.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('H: ${selectedCandle!.high.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('L: ${selectedCandle!.low.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('C: ${selectedCandle!.close.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    InkWell(
                      onTap: () => setState(() => selectedCandle = null),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF1B4332)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}