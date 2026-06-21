// lib/providers/user_data_provider.dart
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
  bool _isLoading = true;

  List<Map<String, dynamic>> get grainsData => _grainsData;
  bool get isLoading => _isLoading;

  UserDataProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList('favorites') ?? [];
    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(String name) => _favorites.contains(name);

  void toggleFavorite(String name) async {
    if (_favorites.contains(name)) {
      _favorites.remove(name);
    } else {
      _favorites.add(name);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites);
    notifyListeners(); 
  }
}