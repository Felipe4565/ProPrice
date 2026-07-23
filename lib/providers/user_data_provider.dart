import 'dart:convert'; // Nécessaire pour jsonEncode et jsonDecode

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDataProvider extends ChangeNotifier {
  // 1. La source de vérité (les données)
  final List<Map<String, dynamic>> _grainsData = [
    {"name": "TRIGO", "emoji": "🌾", "price": "515.00", "variation": "+4.09%", "order": 0},
    {"name": "SOJA", "emoji": "🌱", "price": "420.50", "variation": "-1.20%", "order": 1},
    {"name": "MAIZ", "emoji": "🌽", "price": "185.00", "variation": "+0.50%", "order": 2},
    {"name": "CANOLA", "emoji": "🌿", "price": "610.00", "variation": "+2.15%", "order": 3},
    {"name": "GIRASOL", "emoji": "🌻", "price": "390.00", "variation": "-0.75%", "order": 4},
    {"name": "CEBADA", "emoji": "🪴", "price": "210.00", "variation": "+1.10%", "order": 5},
    {"name": "ARROZ", "emoji": "🍚", "price": "12.40", "variation": "+0.25%", "order": 6},
  ];

  List<String> _favorites = [];
  Map<String, dynamic>? _lastArticle; 
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  // Getters
  List<Map<String, dynamic>> get grainsData => _grainsData;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get lastArticle => _lastArticle;
  List<Map<String, dynamic>> get alerts => _alerts;

  UserDataProvider() {
    _loadAllData();
  }

  // Chargement de toutes les données au démarrage
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Chargement des favoris
    _favorites = prefs.getStringList('favorites') ?? [];
    
    // Chargement de l'article complet
    final articleString = prefs.getString('last_article');
    if (articleString != null) {
      try {
        _lastArticle = jsonDecode(articleString);
      } catch (e) {
        _lastArticle = null;
        await prefs.remove('last_article'); 
        debugPrint("Ancienne donnée d'article supprimée : $e");
      }
    }

    // Chargement des alertes
    final alertsString = prefs.getString('alerts');
    if (alertsString != null) {
      try {
        final decoded = jsonDecode(alertsString) as List;
        _alerts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        _alerts = [];
        await prefs.remove('alerts');
        debugPrint("Données d'alertes corrompues supprimées : $e");
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // --- LOGIQUE FAVORIS ---
  bool isFavorite(String name) => _favorites.contains(name);

  Future<void> toggleFavorite(String name) async {
    if (_favorites.contains(name)) {
      _favorites.remove(name);
    } else {
      _favorites.add(name);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites);
    notifyListeners(); 
  }

  // --- LOGIQUE DERNIER ARTICLE ---
  Future<void> setLastArticle(Map<String, dynamic> article) async {
    _lastArticle = article;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_article', jsonEncode(article));
    
    notifyListeners(); 
  }

  // --- LOGIQUE ALERTES ---
  Future<void> addAlert(String commodity, double price) async {
    _alerts.add({
      'commodity': commodity,
      'price': price,
      'status': 'Activa',
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alerts', jsonEncode(_alerts));
    
    notifyListeners();
  }

  Future<void> removeAlert(int index) async {
    if (index >= 0 && index < _alerts.length) {
      _alerts.removeAt(index);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alerts', jsonEncode(_alerts));
      
      notifyListeners();
    }
  }
}