import 'dart:math';

import 'package:candlesticks/candlesticks.dart';

// --- 1. Classes et Structures ---

class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class CommodityProfile {
  final double basePrice;
  final double volatility; 
  final String emoji;

  CommodityProfile({required this.basePrice, required this.volatility, required this.emoji});
}

// --- 2. Configuration des matières ---

final Map<String, CommodityProfile> marketProfiles = {
  "TRIGO":   CommodityProfile(basePrice: 515.0, volatility: 0.015, emoji: "🌾"),
  "SOJA":    CommodityProfile(basePrice: 420.5, volatility: 0.020, emoji: "🌱"),
  "MAIZ":    CommodityProfile(basePrice: 185.0, volatility: 0.008, emoji: "🌽"),
  "CANOLA":  CommodityProfile(basePrice: 610.0, volatility: 0.025, emoji: "🌿"),
  "GIRASOL": CommodityProfile(basePrice: 390.0, volatility: 0.012, emoji: "🌻"),
  "CEBADA":  CommodityProfile(basePrice: 210.0, volatility: 0.010, emoji: "🪴"),
  "ARROZ":   CommodityProfile(basePrice: 12.4,  volatility: 0.005, emoji: "🍚"),
};

// --- 3. Gestion du Cache (Master Data) ---

final Map<String, List<CandleData>> _masterHistoryCache = {};

// Fonction rendue PUBLIQUE (plus d'underscore au début)
List<CandleData> generateMasterHistory(String commodityName) {
  if (_masterHistoryCache.containsKey(commodityName)) {
    return _masterHistoryCache[commodityName]!;
  }

  final seed = commodityName.hashCode;
  final random = Random(seed);
  final profile = marketProfiles[commodityName] ?? CommodityProfile(basePrice: 100.0, volatility: 0.01, emoji: "");
  
  double price = profile.basePrice;
  List<CandleData> data = [];
  DateTime now = DateTime.now();

  for (int i = 0; i < 365; i++) {
    double volatility = price * profile.volatility;
    double open = price;
    double move = (random.nextDouble() * volatility * 2 - (volatility * 0.9));
    double close = open + move;
    
    double high = max(open, close) + random.nextDouble() * (volatility * 0.5);
    double low = min(open, close) - random.nextDouble() * (volatility * 0.5);
    
    data.add(CandleData(
      date: now.subtract(Duration(days: 365 - i)),
      open: open, 
      high: high, 
      low: low, 
      close: close,
    ));
    price = close;
  }

  _masterHistoryCache[commodityName] = data;
  return data;
}

// --- 4. Fonction principale appelée par l'UI ---

List<CandleData> generateMarketData(String commodityName, String period) {
  // On appelle la fonction publique maintenant
  final masterData = generateMasterHistory(commodityName);
  
  switch (period) {
    case "1D": return masterData.sublist(masterData.length - 24);
    case "1W": return masterData.sublist(masterData.length - 7);
    case "1M": return masterData.sublist(masterData.length - 30);
    case "3M": return masterData.sublist(masterData.length - 90);
    case "1Y": return masterData;
    default: return masterData.sublist(masterData.length - 20);
  }
}

// --- 5. Utilitaires ---

List<Candle> mapToCandlesticks(List<CandleData> data) {
  return data.map((d) => Candle(
    date: d.date,
    high: d.high,
    low: d.low,
    open: d.open,
    close: d.close,
    volume: 1000, 
  )).toList();
}