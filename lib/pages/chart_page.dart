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
import 'subscription_plan_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_page_route.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/staggered_fade_in.dart';

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
  bool isCandleView = false;
  DateTime lastUpdateTime = DateTime.now();
  late ZoomPanBehavior _zoomPanBehavior;

  double? _manualYMin;
  double? _manualYMax;
  double? _lastYDragPosition;

  // États pour les indicateurs techniques
  bool showEMA = false;
  bool showFibonacci = false;
  int emaPeriod = 20;
  Color emaColor = Colors.blue;

  // États et configurations pour le Fibonacci personnalisé (Glissé-déposé, Clics, Pourcentages & Couleurs)
  CandleData? fibStartCandle;
  CandleData? fibEndCandle;
  List<double> fibPercentages = [0.0, 0.236, 0.382, 0.5, 0.618, 1.0];
  Color fibColor = Colors.orange;

  // Configuration API et Domaines Actualités
  final String _apiKey = "ebfe0c0a67ca4acab293895eca1c5410";
  final String _domains = "elpais.com.uy,elobservador.com.uy,agrofy.com.ar,lanacion.com.ar,infocampo.com.ar,bcr.com.ar,ambito.com,clarin.com";

  @override
  void initState() {
    super.initState();
    lastUpdateTime = DateTime.now();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: !showFibonacci, // Désactive le pan si Fibo actif pour dessiner
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x,
    );
  }

  /// Affiche un message incitant à passer au plan Premium, avec un bouton
  /// direct vers la page de sélection de plan. (même pattern que home_page.dart)
  void _showUpgradeSnackbar(String featureLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Función Premium ($featureLabel)."),
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

  void _updateZoomPanBehavior() {
    setState(() {
      _zoomPanBehavior = ZoomPanBehavior(
        enablePinching: true,
        enablePanning: !showFibonacci,
        enableDoubleTapZooming: true,
        enableSelectionZooming: true,
        zoomMode: ZoomMode.x,
      );
    });
  }

  void _handleYAxisDrag(double delta, double chartHeight, double chartMinVal, double chartMaxVal) {
    setState(() {
      if (_manualYMin == null || _manualYMax == null) {
        _manualYMin = chartMinVal;
        _manualYMax = chartMaxVal;
      }
      double range = _manualYMax! - _manualYMin!;
      double center = (_manualYMin! + _manualYMax!) / 2;

      double scaleFactor = 1.0 + (delta * 0.005);
      double newRange = range * scaleFactor;

      double baseRange = chartMaxVal - chartMinVal;
      if (newRange > 0.1 && newRange < baseRange * 15) {
        _manualYMin = center - newRange / 2;
        _manualYMax = center + newRange / 2;
      }
    });
  }

  // Génération des PlotBands pour les Retracements de Fibonacci personnalisés (Pourcentages, Couleurs & Recalcul)
  List<PlotBand> _getFibonacciPlotBands(List<CandleData> data) {
    if (!showFibonacci || data.isEmpty || fibStartCandle == null) return [];

    // Si seul le point de départ est défini, on affiche uniquement la barre de référence
    if (fibStartCandle != null && fibEndCandle == null) {
      double refPrice = fibStartCandle!.close;
      return [
        PlotBand(
          start: refPrice,
          end: refPrice,
          borderColor: fibColor,
          borderWidth: 1.5,
          dashArray: const [3, 3],
          text: 'Référence (${refPrice.toStringAsFixed(2)} \$)',
          textStyle: TextStyle(
            color: fibColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          horizontalTextAlignment: TextAnchor.end,
        ),
      ];
    }

    // Si les deux points sont définis, on trace le Fibonacci complet selon les pourcentages choisis
    double p1 = fibStartCandle!.close;
    double p2 = fibEndCandle!.close;
    double high = p1 > p2 ? p1 : p2;
    double low = p1 > p2 ? p2 : p1;

    double diff = high - low;

    List<PlotBand> bands = [];
    for (var p in fibPercentages) {
      double val = high - diff * p;
      String label = p == 0.0
          ? 'Fibo 0% (${high.toStringAsFixed(2)})'
          : p == 1.0
          ? 'Fibo 100% (${low.toStringAsFixed(2)})'
          : 'Fibo ${(p * 100).toStringAsFixed(1)}%';
      bands.add(
        PlotBand(
          start: val,
          end: val,
          borderColor: fibColor,
          borderWidth: 1.2,
          dashArray: const [4, 4],
          text: label,
          textStyle: TextStyle(
            color: fibColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          horizontalTextAlignment: TextAnchor.end,
        ),
      );
    }
    return bands;
  }

  // Bloc de contrôle et réglage rapide avec rouage sous le graphique (EMA & Fibonacci)
  Widget _buildIndicatorControlBlock() {
    if (!showEMA && !showFibonacci) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest500.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, size: 18, color: AppColors.forest500),
                  const SizedBox(width: 8),
                  const Text(
                    'Réglages Indicateurs Actifs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.forest500,
                    ),
                  ),
                ],
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.tune, size: 18, color: AppColors.forest500),
                tooltip: 'Paramètres avancés',
                onPressed: () => _showAdvancedIndicatorSettingsDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showEMA) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EMA Période : $emaPeriod',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forest500),
                ),
                Row(
                  children: [
                    for (var p in [9, 20, 50, 200])
                      GestureDetector(
                        onTap: () {
                          final currentData = generateMarketData(widget.commodityName, selectedPeriod);
                          setState(() {
                            emaPeriod = p;
                            if (currentData.length < emaPeriod) {
                              showEMA = false;
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: emaPeriod == p ? AppColors.forest500 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: emaPeriod == p ? Colors.white : AppColors.forest500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
          if (showEMA && showFibonacci) const Divider(height: 14),
          if (showFibonacci) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fibStartCandle == null
                        ? '✨ Cliquez sur le graphique pour placer le départ Fibo.'
                        : fibEndCandle == null
                        ? '✨ Cliquez ou glissez pour définir l\'arrivée Fibo.'
                        : 'Fibo actif (${fibPercentages.length} niveaux)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fibStartCandle != null || fibEndCandle != null)
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.refresh, size: 16, color: Colors.orange.shade900),
                    tooltip: "Réinitialiser les points Fibo",
                    onPressed: () {
                      setState(() {
                        fibStartCandle = null;
                        fibEndCandle = null;
                      });
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Boîte de dialogue pour les réglages avancés (Couleurs & Pourcentages Fibonacci / EMA)
  void _showAdvancedIndicatorSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.background,
              title: const Row(
                children: [
                  Icon(Icons.settings, color: AppColors.forest500),
                  SizedBox(width: 10),
                  Text(
                    'Configuration Avancée',
                    style: TextStyle(
                      color: AppColors.forest500,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEMA) ...[
                      const Text(
                        'Moyenne Mobile Exponentielle (EMA)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Période :', style: TextStyle(fontSize: 12)),
                          DropdownButton<int>(
                            value: emaPeriod,
                            items: [9, 14, 20, 50, 100, 200].map((val) {
                              return DropdownMenuItem(value: val, child: Text('$val'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final currentData = generateMarketData(widget.commodityName, selectedPeriod);
                                setDialogState(() {
                                  emaPeriod = val;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                                setState(() {
                                  emaPeriod = val;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Couleur de la ligne EMA :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [Colors.blue, Colors.indigo, Colors.purple, Colors.teal, Colors.green].map((c) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() => emaColor = c);
                              setState(() => emaColor = c);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: emaColor == c ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 20),
                    ],
                    if (showFibonacci) ...[
                      const Text(
                        'Retracements de Fibonacci',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const Text('Pourcentages à afficher :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0].map((p) {
                          bool isSelected = fibPercentages.contains(p);
                          String label = p == 0.0 ? '0%' : p == 1.0 ? '100%' : '${(p * 100).toStringAsFixed(1)}%';
                          return FilterChip(
                            label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.forest500)),
                            selected: isSelected,
                            selectedColor: Colors.orange.shade700,
                            backgroundColor: Colors.white,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (!fibPercentages.contains(p)) {
                                    fibPercentages.add(p);
                                    fibPercentages.sort();
                                  }
                                } else {
                                  if (fibPercentages.length > 2) {
                                    fibPercentages.remove(p);
                                  }
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('Couleur des lignes Fibonacci :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [Colors.orange, Colors.red, Colors.amber, Colors.deepOrange, Colors.pink].map((c) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() => fibColor = c);
                              setState(() => fibColor = c);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: fibColor == c ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (!showEMA && !showFibonacci)
                      const Text('Aucun indicateur actif (EMA ou Fibonacci). Activez-les via l\'icône en haut de l\'écran.'),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Valider', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // BottomSheet pour activer/désactiver les indicateurs
  void _showIndicatorsBottomSheet(BuildContext context) {
    final rawData = generateMarketData(widget.commodityName, selectedPeriod);
    bool hasEnoughCandles = rawData.length >= emaPeriod;

    if (!hasEnoughCandles && showEMA) {
      setState(() => showEMA = false);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final currentData = generateMarketData(widget.commodityName, selectedPeriod);
            bool modalHasEnough = currentData.length >= emaPeriod;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indicateurs Techniques',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forest500,
                    ),
                  ),
                  const SizedBox(height: 15),

                  SwitchListTile(
                    title: Text(
                      'Moyenne Mobile Exponentielle (EMA $emaPeriod)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: modalHasEnough ? AppColors.forest500 : Colors.grey,
                      ),
                    ),
                    subtitle: !modalHasEnough
                        ? Text(
                      'Indisponible : nécessite au moins $emaPeriod bougies (actuellement ${currentData.length}).',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    )
                        : null,
                    value: modalHasEnough ? showEMA : false,
                    activeThumbColor: AppColors.forest500,
                    onChanged: modalHasEnough ? (bool value) {
                      setModalState(() => showEMA = value);
                      setState(() => showEMA = value);
                    } : null,
                  ),

                  if (showEMA || !modalHasEnough) ...[
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Période de l\'EMA :',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest500,
                              fontSize: 14,
                            ),
                          ),
                          DropdownButton<int>(
                            value: emaPeriod,
                            dropdownColor: AppColors.background,
                            items: [9, 14, 20, 50, 100, 200].map((int val) {
                              return DropdownMenuItem<int>(
                                value: val,
                                child: Text(
                                  '$val',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.forest500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                setModalState(() {
                                  emaPeriod = newValue;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                                setState(() {
                                  emaPeriod = newValue;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const Divider(height: 20),

                  SwitchListTile(
                    title: const Text(
                      'Retracements de Fibonacci',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500),
                    ),
                    value: showFibonacci,
                    activeThumbColor: AppColors.forest500,
                    onChanged: (bool value) {
                      setModalState(() => showFibonacci = value);
                      setState(() {
                        showFibonacci = value;
                        _updateZoomPanBehavior();
                        if (!value) {
                          fibStartCandle = null;
                          fibEndCandle = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

  // Boîte de dialogue pour ajouter une alerte
  void _showAlertDialog(BuildContext mainContext, double defaultPrice, UserDataProvider provider, List<Map<String, dynamic>> commodityAlerts) {
    final TextEditingController priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );

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
                'Entrez le seuil de prix pour ${widget.commodityName} :',
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
                              onPressed: () {
                                Navigator.pop(confirmContext);
                                provider.addAlert(widget.commodityName, parsedPrice);
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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
                    provider.addAlert(widget.commodityName, parsedPrice);
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
                        backgroundColor: AppColors.forest500,
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

  // Boîte de dialogue pour modifier une alerte existante
  void _showEditAlertDialog(BuildContext mainContext, int globalIndex, double currentPrice, UserDataProvider provider) {
    final TextEditingController priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );

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
                'Modifier l\'alerte',
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
                'Modifiez le seuil de prix pour ${widget.commodityName} :',
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
                  provider.removeAlert(globalIndex);
                  provider.addAlert(widget.commodityName, parsedPrice);
                  ScaffoldMessenger.of(mainContext).showSnackBar(
                    SnackBar(
                      content: Text('Alerte modifiée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
                      backgroundColor: AppColors.forest500,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.forest500),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.commodityName,
            style: const TextStyle(color: AppColors.forest500, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: AppColors.forest500, size: 24),
            tooltip: "Indicadores técnicos",
            onPressed: () {
              HapticFeedback.lightImpact();
              if (!provider.canUseIndicators) {
                _showUpgradeSnackbar("indicadores técnicos (EMA / Fibonacci)");
                return;
              }
              _showIndicatorsBottomSheet(context);
            },
          ),
          IconButton(
            icon: const Text('⛶', style: TextStyle(fontSize: 22, color: AppColors.forest500, fontWeight: FontWeight.bold)),
            tooltip: "Plein écran paysage",
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                AppPageRoute(
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
            icon: const Icon(Icons.share_rounded, color: AppColors.forest500, size: 26),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await SharePlus.instance.share(
                ShareParams(text: 'Regarde l\'évolution du cours pour : ${widget.commodityName}'),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.favoriteNotifier,
            builder: (context, isFavorite, _) {
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? Colors.amber : AppColors.forest500,
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
            _buildViewToggle(provider),
            _buildPeriodSelector(provider),
            _buildIndicatorControlBlock(), // Bloc avec rouage sous le graphique pour gérer EMA / Fibonacci

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double plotWidth = constraints.maxWidth - 70; // Déduction des marges axes

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) {
                        if (!showFibonacci) return;
                        double localX = details.localPosition.dx - 50;
                        double t = (localX / plotWidth).clamp(0.0, 1.0);
                        int index = (t * (rawData.length - 1)).round();
                        if (index >= 0 && index < rawData.length) {
                          setState(() {
                            if (fibStartCandle == null) {
                              fibStartCandle = rawData[index];
                              fibEndCandle = null;
                            } else if (fibEndCandle == null) {
                              fibEndCandle = rawData[index];
                            } else {
                              fibStartCandle = rawData[index];
                              fibEndCandle = null;
                            }
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                      onPanStart: (details) {
                        if (!showFibonacci) return;
                        double localX = details.localPosition.dx - 50;
                        double t = (localX / plotWidth).clamp(0.0, 1.0);
                        int index = (t * (rawData.length - 1)).round();
                        if (index >= 0 && index < rawData.length) {
                          setState(() {
                            if (fibStartCandle == null) {
                              fibStartCandle = rawData[index];
                              fibEndCandle = null;
                            } else {
                              fibEndCandle = rawData[index];
                            }
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                      onPanUpdate: (details) {
                        if (!showFibonacci || fibStartCandle == null) return;
                        double localX = details.localPosition.dx - 50;
                        double t = (localX / plotWidth).clamp(0.0, 1.0);
                        int index = (t * (rawData.length - 1)).round();
                        if (index >= 0 && index < rawData.length) {
                          setState(() {
                            fibEndCandle = rawData[index];
                          });
                        }
                      },
                      onPanEnd: (_) {
                        if (showFibonacci && fibStartCandle != null && fibEndCandle != null) {
                          HapticFeedback.mediumImpact();
                        }
                      },
                      child: Stack(
                        children: [
                          SfCartesianChart(
                            zoomPanBehavior: _zoomPanBehavior,
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
                              minimum: _manualYMin ?? chartMin,
                              maximum: _manualYMax ?? chartMax,
                              majorGridLines: const MajorGridLines(width: 0.5, color: Colors.black12),
                              axisLine: const AxisLine(width: 0),
                              plotBands: [
                                ...activeAlertPrices.map((price) {
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
                                }),
                                ..._getFibonacciPlotBands(rawData),
                              ],
                            ),
                            indicators: showEMA && rawData.length >= emaPeriod
                                ? <TechnicalIndicator<CandleData, DateTime>>[
                              EmaIndicator<CandleData, DateTime>(
                                dataSource: rawData,
                                xValueMapper: (CandleData data, _) => data.date,
                                closeValueMapper: (CandleData data, _) => data.close,
                                period: emaPeriod,
                                isVisible: true,
                                animationDuration: 0,
                                name: 'EMA',
                                signalLineColor: emaColor,
                                signalLineWidth: 2,
                              ),
                            ]
                                : [],
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
                                  if (!showFibonacci && details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
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
                                color: AppColors.forest500,
                                width: 2,
                                markerSettings: MarkerSettings(
                                  isVisible: selectedPeriod == "1D" || selectedPeriod == "1W",
                                  height: 5,
                                  width: 5,
                                  color: AppColors.forest500,
                                  borderColor: Colors.white,
                                  borderWidth: 1,
                                ),
                                onPointTap: (ChartPointDetails details) {
                                  if (!showFibonacci && details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                    setState(() {
                                      selectedCandle = rawData[details.pointIndex!];
                                    });
                                    HapticFeedback.selectionClick();
                                  }
                                },
                              ),
                            ],
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 50,
                            child: GestureDetector(
                              onVerticalDragStart: (details) {
                                _lastYDragPosition = details.localPosition.dy;
                              },
                              onVerticalDragUpdate: (details) {
                                if (_lastYDragPosition != null) {
                                  double delta = details.localPosition.dy - _lastYDragPosition!;
                                  _lastYDragPosition = details.localPosition.dy;
                                  _handleYAxisDrag(delta, 420, chartMin, chartMax);
                                }
                              },
                              onVerticalDragEnd: (_) {
                                _lastYDragPosition = null;
                              },
                              onDoubleTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _manualYMin = null;
                                  _manualYMax = null;
                                });
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                  color: AppColors.forest500.withValues(alpha: 0.6),
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
                  color: AppColors.forest500.withValues(alpha: 0.5),
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
                            color: AppColors.forest500.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.forest500),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.commodityName.toUpperCase()} > ${alertPrice.toStringAsFixed(2)} \$',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.forest500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Bouton Modifier
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.forest500.withValues(alpha: 0.7)),
                          tooltip: 'Modifier l\'alerte',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (globalIndex != -1) {
                              _showEditAlertDialog(context, globalIndex, alertPrice, provider);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        // Bouton Supprimer
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade400),
                          tooltip: 'Supprimer l\'alerte',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (globalIndex != -1) {
                              provider.removeAlert(globalIndex);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Alerte supprimée : ${widget.commodityName} > ${alertPrice.toStringAsFixed(2)} \$'),
                                  backgroundColor: AppColors.forest500,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          },
                        ),
                      ],
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
                    color: AppColors.forest500.withValues(alpha: 0.6),
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
                return _buildRelatedNewsSkeleton();
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
                      color: AppColors.forest500.withValues(alpha: 0.5),
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

                    return StaggeredFadeIn(
                      index: index,
                      child: Container(
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
                                      color: AppColors.forest500.withValues(alpha: 0.1),
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported_outlined, color: AppColors.forest500),
                                      ),
                                    ),
                                  )
                                      : Container(
                                    height: 120,
                                    color: AppColors.forest500.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: Icon(Icons.article_outlined, color: AppColors.forest500, size: 30),
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
                                                    color: AppColors.forest500.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    sourceName,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.forest500,
                                                    ),
                                                  ),
                                                ),
                                                if (formattedDate.isNotEmpty)
                                                  Text(
                                                    formattedDate,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: AppColors.forest500.withValues(alpha: 0.4),
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
                                                color: AppColors.forest500,
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
                                            color: AppColors.forest500.withValues(alpha: 0.7),
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

  /// Skeleton horizontal pendant le chargement des actualités liées à la
  /// matière première, dans le même format (280×310, image 120 + texte)
  /// que les vraies cartes, pour éviter le "saut" visuel à l'arrivée des
  /// données.
  Widget _buildRelatedNewsSkeleton() {
    return SizedBox(
      height: 310,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  height: 120,
                  width: double.infinity,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppSkeleton(height: 10, width: 70),
                        SizedBox(height: 10),
                        AppSkeleton(height: 12, width: double.infinity),
                        SizedBox(height: 8),
                        AppSkeleton(height: 11, width: 200),
                        SizedBox(height: 4),
                        AppSkeleton(height: 11, width: 140),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
              const Icon(Icons.description_outlined, size: 20, color: AppColors.forest500),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CONTRAT SÉLECTIONNÉ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.forest500.withValues(alpha: 0.5))),
                  Text(_getContractInfo(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.forest500)),
                ],
              ),
            ],
          ),
          Text(
            "Màj: ${DateFormat('HH:mm').format(lastUpdateTime)}",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forest500.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(UserDataProvider provider) {
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
            _toggleOption("Bougies", Icons.candlestick_chart_rounded, true, provider),
            _toggleOption("Courbe", Icons.show_chart_rounded, false, provider),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption(String label, IconData icon, bool isCandleOption, UserDataProvider provider) {
    bool isSelected = isCandleView == isCandleOption;
    bool isLocked = isCandleOption && !provider.canUseCandleView;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isLocked) {
            _showUpgradeSnackbar("vista de velas (candlestick)");
            return;
          }
          setState(() => isCandleView = isCandleOption);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.forest500 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : (isLocked ? AppColors.forest500.withValues(alpha: 0.3) : AppColors.forest500)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isLocked ? AppColors.forest500.withValues(alpha: 0.3) : AppColors.forest500))),
              if (isLocked) ...[
                const SizedBox(width: 4),
                Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.forest500.withValues(alpha: 0.3)),
              ],
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
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.forest500),
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
              backgroundColor: AppColors.forest500,
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

  Widget _buildPeriodSelector(UserDataProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: periods.map((p) => _buildPeriodButton(p, provider)).toList(),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period, UserDataProvider provider) {
    bool isSelected = selectedPeriod == period;
    bool isLocked = !provider.canUsePeriod(period);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isLocked) {
            HapticFeedback.lightImpact();
            _showUpgradeSnackbar("período $period");
            return;
          }
          HapticFeedback.selectionClick();
          setState(() {
            selectedPeriod = period;
            lastUpdateTime = DateTime.now();
            selectedCandle = null;
            _manualYMin = null;
            _manualYMax = null;
            fibStartCandle = null;
            fibEndCandle = null;

            final newData = generateMarketData(widget.commodityName, selectedPeriod);
            if (showEMA && newData.length < emaPeriod) {
              showEMA = false;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.forest500 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(period, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isLocked
                      ? AppColors.forest500.withValues(alpha: 0.25)
                      : AppColors.forest500.withValues(alpha: 0.5)),
                )),
                if (isLocked) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.lock_outline_rounded, size: 10, color: AppColors.forest500.withValues(alpha: 0.25)),
                ],
              ],
            ),
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
          style: TextStyle(color: AppColors.forest500.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
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
        Text(label, style: TextStyle(color: AppColors.forest500.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.forest500, fontSize: 14, fontWeight: FontWeight.w800)),
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
  bool isCandleView = false;
  CandleData? selectedCandle;
  final List<String> periods = ["1D", "1W", "1M", "3M", "1Y"];
  late ZoomPanBehavior _zoomPanBehavior;

  double? _manualYMin;
  double? _manualYMax;
  double? _lastYDragPosition;

  // États pour les indicateurs techniques
  bool showEMA = false;
  bool showFibonacci = false;
  int emaPeriod = 20;
  Color emaColor = Colors.blue;

  // États pour le Fibonacci personnalisé en plein écran
  CandleData? fibStartCandle;
  CandleData? fibEndCandle;
  List<double> fibPercentages = [0.0, 0.236, 0.382, 0.5, 0.618, 1.0];
  Color fibColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    selectedPeriod = widget.initialPeriod;

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: !showFibonacci,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x,
    );

    AuthLock.isFullScreenActive = true;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Même logique de restriction que dans ChartPage (voir _ChartPageState).
  void _showUpgradeSnackbar(String featureLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Función Premium ($featureLabel)."),
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

  void _updateZoomPanBehavior() {
    setState(() {
      _zoomPanBehavior = ZoomPanBehavior(
        enablePinching: true,
        enablePanning: !showFibonacci,
        enableDoubleTapZooming: true,
        enableSelectionZooming: true,
        zoomMode: ZoomMode.x,
      );
    });
  }

  void _handleYAxisDrag(double delta, double chartHeight, double chartMinVal, double chartMaxVal) {
    setState(() {
      if (_manualYMin == null || _manualYMax == null) {
        _manualYMin = chartMinVal;
        _manualYMax = chartMaxVal;
      }
      double range = _manualYMax! - _manualYMin!;
      double center = (_manualYMin! + _manualYMax!) / 2;

      double factor = delta / chartHeight;
      double newRange = range * (1 + factor * 2);

      if (newRange > 0.01) {
        _manualYMin = center - newRange / 2;
        _manualYMax = center + newRange / 2;
      }
    });
  }

  List<PlotBand> _getFibonacciPlotBands(List<CandleData> data) {
    if (!showFibonacci || data.isEmpty || fibStartCandle == null) return [];

    if (fibStartCandle != null && fibEndCandle == null) {
      double refPrice = fibStartCandle!.close;
      return [
        PlotBand(
          start: refPrice,
          end: refPrice,
          borderColor: fibColor,
          borderWidth: 1.5,
          dashArray: const [3, 3],
          text: 'Référence (${refPrice.toStringAsFixed(2)} \$)',
          textStyle: TextStyle(
            color: fibColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          horizontalTextAlignment: TextAnchor.end,
        ),
      ];
    }

    double p1 = fibStartCandle!.close;
    double p2 = fibEndCandle!.close;
    double high = p1 > p2 ? p1 : p2;
    double low = p1 > p2 ? p2 : p1;

    double diff = high - low;

    List<PlotBand> bands = [];
    for (var p in fibPercentages) {
      double val = high - diff * p;
      String label = p == 0.0
          ? 'Fibo 0% (${high.toStringAsFixed(2)})'
          : p == 1.0
          ? 'Fibo 100% (${low.toStringAsFixed(2)})'
          : 'Fibo ${(p * 100).toStringAsFixed(1)}%';
      bands.add(
        PlotBand(
          start: val,
          end: val,
          borderColor: fibColor,
          borderWidth: 1.2,
          dashArray: const [4, 4],
          text: label,
          textStyle: TextStyle(
            color: fibColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          horizontalTextAlignment: TextAnchor.end,
        ),
      );
    }
    return bands;
  }

  Widget _buildFullScreenIndicatorControlBlock() {
    if (!showEMA && !showFibonacci) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.forest500.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, size: 14, color: AppColors.forest500),
              const SizedBox(width: 6),
              Text(
                showEMA && showFibonacci
                    ? 'EMA: $emaPeriod | Fibo actif'
                    : showEMA
                    ? 'EMA Période: $emaPeriod'
                    : fibStartCandle == null
                    ? 'Cliquez pour placer le départ Fibo'
                    : 'Fibo actif (${fibPercentages.length} niveaux)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.forest500),
              ),
            ],
          ),
          Row(
            children: [
              if (showFibonacci && (fibStartCandle != null || fibEndCandle != null))
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.refresh, size: 14, color: Colors.orange.shade900),
                  tooltip: "Réinitialiser Fibo",
                  onPressed: () {
                    setState(() {
                      fibStartCandle = null;
                      fibEndCandle = null;
                    });
                  },
                ),
              const SizedBox(width: 6),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.tune, size: 14, color: AppColors.forest500),
                tooltip: 'Paramètres',
                onPressed: () => _showAdvancedIndicatorSettingsDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAdvancedIndicatorSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.background,
              title: const Row(
                children: [
                  Icon(Icons.settings, color: AppColors.forest500),
                  SizedBox(width: 10),
                  Text(
                    'Configuration Avancée',
                    style: TextStyle(
                      color: AppColors.forest500,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEMA) ...[
                      const Text(
                        'Moyenne Mobile Exponentielle (EMA)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Période :', style: TextStyle(fontSize: 12)),
                          DropdownButton<int>(
                            value: emaPeriod,
                            items: [9, 14, 20, 50, 100, 200].map((val) {
                              return DropdownMenuItem(value: val, child: Text('$val'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final currentData = generateMarketData(widget.commodityName, selectedPeriod);
                                setDialogState(() {
                                  emaPeriod = val;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                                setState(() {
                                  emaPeriod = val;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Couleur de la ligne EMA :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [Colors.blue, Colors.indigo, Colors.purple, Colors.teal, Colors.green].map((c) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() => emaColor = c);
                              setState(() => emaColor = c);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: emaColor == c ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 20),
                    ],
                    if (showFibonacci) ...[
                      const Text(
                        'Retracements de Fibonacci',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const Text('Pourcentages à afficher :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0].map((p) {
                          bool isSelected = fibPercentages.contains(p);
                          String label = p == 0.0 ? '0%' : p == 1.0 ? '100%' : '${(p * 100).toStringAsFixed(1)}%';
                          return FilterChip(
                            label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.forest500)),
                            selected: isSelected,
                            selectedColor: Colors.orange.shade700,
                            backgroundColor: Colors.white,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (!fibPercentages.contains(p)) {
                                    fibPercentages.add(p);
                                    fibPercentages.sort();
                                  }
                                } else {
                                  if (fibPercentages.length > 2) {
                                    fibPercentages.remove(p);
                                  }
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('Couleur des lignes Fibonacci :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [Colors.orange, Colors.red, Colors.amber, Colors.deepOrange, Colors.pink].map((c) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() => fibColor = c);
                              setState(() => fibColor = c);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: fibColor == c ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (!showEMA && !showFibonacci)
                      const Text('Aucun indicateur actif (EMA ou Fibonacci). Activez-les via l\'icône en haut de l\'écran.'),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Valider', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIndicatorsBottomSheet(BuildContext context) {
    final rawData = generateMarketData(widget.commodityName, selectedPeriod);
    bool hasEnoughCandles = rawData.length >= emaPeriod;

    if (!hasEnoughCandles && showEMA) {
      setState(() => showEMA = false);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final currentData = generateMarketData(widget.commodityName, selectedPeriod);
            bool modalHasEnough = currentData.length >= emaPeriod;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indicateurs Techniques',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forest500,
                    ),
                  ),
                  const SizedBox(height: 15),

                  SwitchListTile(
                    title: Text(
                      'Moyenne Mobile Exponentielle (EMA $emaPeriod)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: modalHasEnough ? AppColors.forest500 : Colors.grey,
                      ),
                    ),
                    subtitle: !modalHasEnough
                        ? Text(
                      'Indisponible : nécessite au moins $emaPeriod bougies (actuellement ${currentData.length}).',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    )
                        : null,
                    value: modalHasEnough ? showEMA : false,
                    activeThumbColor: AppColors.forest500,
                    onChanged: modalHasEnough ? (bool value) {
                      setModalState(() => showEMA = value);
                      setState(() => showEMA = value);
                    } : null,
                  ),

                  if (showEMA || !modalHasEnough) ...[
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Période de l\'EMA :',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest500,
                              fontSize: 14,
                            ),
                          ),
                          DropdownButton<int>(
                            value: emaPeriod,
                            dropdownColor: AppColors.background,
                            items: [9, 14, 20, 50, 100, 200].map((int val) {
                              return DropdownMenuItem<int>(
                                value: val,
                                child: Text(
                                  '$val',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.forest500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                setModalState(() {
                                  emaPeriod = newValue;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                                setState(() {
                                  emaPeriod = newValue;
                                  if (currentData.length < emaPeriod) {
                                    showEMA = false;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const Divider(height: 20),

                  SwitchListTile(
                    title: const Text(
                      'Retracements de Fibonacci',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest500),
                    ),
                    value: showFibonacci,
                    activeThumbColor: AppColors.forest500,
                    onChanged: (bool value) {
                      setModalState(() => showFibonacci = value);
                      setState(() {
                        showFibonacci = value;
                        _updateZoomPanBehavior();
                        if (!value) {
                          fibStartCandle = null;
                          fibEndCandle = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                'Entrez le seuil de prix pour ${widget.commodityName} :',
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
                              onPressed: () {
                                Navigator.pop(confirmContext);
                                provider.addAlert(widget.commodityName, parsedPrice);
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
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
                    provider.addAlert(widget.commodityName, parsedPrice);
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Alerte ajoutée : ${widget.commodityName} > ${parsedPrice.toStringAsFixed(2)} \$'),
                        backgroundColor: AppColors.forest500,
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

  Widget _buildCompactPeriodButton(String period, UserDataProvider provider) {
    bool isSelected = selectedPeriod == period;
    bool isLocked = !provider.canUsePeriod(period);
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showUpgradeSnackbar("período $period");
          return;
        }
        HapticFeedback.selectionClick();
        setState(() {
          selectedPeriod = period;
          selectedCandle = null;
          _manualYMin = null;
          _manualYMax = null;
          fibStartCandle = null;
          fibEndCandle = null;

          final newData = generateMarketData(widget.commodityName, selectedPeriod);
          if (showEMA && newData.length < emaPeriod) {
            showEMA = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forest500 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              period,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isLocked ? AppColors.forest500.withValues(alpha: 0.3) : AppColors.forest500),
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 2),
              Icon(Icons.lock_outline_rounded, size: 9, color: AppColors.forest500.withValues(alpha: 0.3)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactToggleOption(String label, bool isCandleOption, UserDataProvider provider) {
    bool isSelected = isCandleView == isCandleOption;
    bool isLocked = isCandleOption && !provider.canUseCandleView;
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showUpgradeSnackbar("vista de velas (candlestick)");
          return;
        }
        HapticFeedback.selectionClick();
        setState(() => isCandleView = isCandleOption);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forest500 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isLocked ? AppColors.forest500.withValues(alpha: 0.3) : AppColors.forest500),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_fullscreen_rounded, color: AppColors.forest500, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.commodityName,
                        style: const TextStyle(
                          color: AppColors.forest500,
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
                          children: periods.map((p) => _buildCompactPeriodButton(p, provider)).toList(),
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
                            _compactToggleOption("Bougies", true, provider),
                            _compactToggleOption("Courbe", false, provider),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(Icons.insights_rounded, color: AppColors.forest500, size: 20),
                        tooltip: "Indicadores técnicos",
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (!provider.canUseIndicators) {
                            _showUpgradeSnackbar("indicadores técnicos (EMA / Fibonacci)");
                            return;
                          }
                          _showIndicatorsBottomSheet(context);
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
                              color: isFavorite ? Colors.amber : AppColors.forest500,
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
            _buildFullScreenIndicatorControlBlock(), // Bloc avec rouage plein écran
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double plotWidth = constraints.maxWidth - 70;

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          if (!showFibonacci) return;
                          double localX = details.localPosition.dx - 50;
                          double t = (localX / plotWidth).clamp(0.0, 1.0);
                          int index = (t * (rawData.length - 1)).round();
                          if (index >= 0 && index < rawData.length) {
                            setState(() {
                              if (fibStartCandle == null) {
                                fibStartCandle = rawData[index];
                                fibEndCandle = null;
                              } else if (fibEndCandle == null) {
                                fibEndCandle = rawData[index];
                              } else {
                                fibStartCandle = rawData[index];
                                fibEndCandle = null;
                              }
                            });
                            HapticFeedback.selectionClick();
                          }
                        },
                        onPanStart: (details) {
                          if (!showFibonacci) return;
                          double localX = details.localPosition.dx - 50;
                          double t = (localX / plotWidth).clamp(0.0, 1.0);
                          int index = (t * (rawData.length - 1)).round();
                          if (index >= 0 && index < rawData.length) {
                            setState(() {
                              if (fibStartCandle == null) {
                                fibStartCandle = rawData[index];
                                fibEndCandle = null;
                              } else {
                                fibEndCandle = rawData[index];
                              }
                            });
                            HapticFeedback.selectionClick();
                          }
                        },
                        onPanUpdate: (details) {
                          if (!showFibonacci || fibStartCandle == null) return;
                          double localX = details.localPosition.dx - 50;
                          double t = (localX / plotWidth).clamp(0.0, 1.0);
                          int index = (t * (rawData.length - 1)).round();
                          if (index >= 0 && index < rawData.length) {
                            setState(() {
                              fibEndCandle = rawData[index];
                            });
                          }
                        },
                        onPanEnd: (_) {
                          if (showFibonacci && fibStartCandle != null && fibEndCandle != null) {
                            HapticFeedback.mediumImpact();
                          }
                        },
                        child: Stack(
                          children: [
                            SfCartesianChart(
                              zoomPanBehavior: _zoomPanBehavior,
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
                                minimum: _manualYMin ?? chartMin,
                                maximum: _manualYMax ?? chartMax,
                                majorGridLines: const MajorGridLines(
                                  width: 0.5,
                                  color: Colors.black12,
                                ),
                                axisLine: const AxisLine(width: 0),
                                plotBands: [
                                  ...activeAlertPrices.map((price) {
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
                                      horizontalTextAlignment:
                                      _getHorizontalAlignment(price, rawData),
                                      verticalTextAlignment:
                                      price >= midPrice
                                          ? TextAnchor.end
                                          : TextAnchor.start,
                                    );
                                  }),
                                  ..._getFibonacciPlotBands(rawData),
                                ],
                              ),
                              indicators: showEMA && rawData.length >= emaPeriod
                                  ? <TechnicalIndicator<CandleData, DateTime>>[
                                EmaIndicator<CandleData, DateTime>(
                                  dataSource: rawData,
                                  xValueMapper: (CandleData data, _) => data.date,
                                  closeValueMapper: (CandleData data, _) => data.close,
                                  period: emaPeriod,
                                  isVisible: true,
                                  animationDuration: 0,
                                  name: 'EMA',
                                  signalLineColor: emaColor,
                                  signalLineWidth: 2,
                                ),
                              ]
                                  : [],
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
                                    if (!showFibonacci && details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
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
                                  color: AppColors.forest500,
                                  width: 2,
                                  markerSettings: MarkerSettings(
                                    isVisible: selectedPeriod == "1D" || selectedPeriod == "1W",
                                    height: 5,
                                    width: 5,
                                    color: AppColors.forest500,
                                    borderColor: Colors.white,
                                    borderWidth: 1,
                                  ),
                                  onPointTap: (ChartPointDetails details) {
                                    if (!showFibonacci && details.pointIndex != null && details.pointIndex! >= 0 && details.pointIndex! < rawData.length) {
                                      setState(() {
                                        selectedCandle = rawData[details.pointIndex!];
                                      });
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                ),
                              ],
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 50,
                              child: GestureDetector(
                                onVerticalDragStart: (details) {
                                  _lastYDragPosition = details.localPosition.dy;
                                },
                                onVerticalDragUpdate: (details) {
                                  if (_lastYDragPosition != null) {
                                    double delta = details.localPosition.dy - _lastYDragPosition!;
                                    _lastYDragPosition = details.localPosition.dy;
                                    _handleYAxisDrag(delta, constraints.maxHeight, chartMin, chartMax);
                                  }
                                },
                                onVerticalDragEnd: (_) {
                                  _lastYDragPosition = null;
                                },
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forest500),
                    ),
                    Text('O: ${selectedCandle!.open.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('H: ${selectedCandle!.high.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('L: ${selectedCandle!.low.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('C: ${selectedCandle!.close.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    InkWell(
                      onTap: () => setState(() => selectedCandle = null),
                      child: const Icon(Icons.close, size: 14, color: AppColors.forest500),
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