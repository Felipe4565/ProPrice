import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDataProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Données de marché (statiques pour l'instant, pas liées à un utilisateur)
  final List<Map<String, dynamic>> _grainsData = [
    {"name": "TRIGO", "emoji": "🌾", "price": "515.00", "variation": "+4.09%", "order": 0},
    {"name": "SOJA", "emoji": "🌱", "price": "420.50", "variation": "-1.20%", "order": 1},
    {"name": "MAIZ", "emoji": "🌽", "price": "185.00", "variation": "+0.50%", "order": 2},
    {"name": "CANOLA", "emoji": "🌿", "price": "610.00", "variation": "+2.15%", "order": 3},
    {"name": "GIRASOL", "emoji": "🌻", "price": "390.00", "variation": "-0.75%", "order": 4},
  ];

  List<String> _favorites = [];
  Map<String, dynamic>? _lastArticle;
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  // --- Getters marché / favoris / alertes / article ---
  List<Map<String, dynamic>> get grainsData => _grainsData;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get lastArticle => _lastArticle;
  List<Map<String, dynamic>> get alerts => _alerts;

  // --- Getters profil (utilisés par ProfilePage) ---
  Map<String, dynamic>? get profile => _profile;
  String get firstName => (_profile?['first_name'] ?? '') as String;
  String get lastName => (_profile?['last_name'] ?? '') as String;
  String get fullName {
    final name = "$firstName $lastName".trim();
    return name.isNotEmpty ? name : "Usuario";
  }

  String? get avatarUrl => _profile?['avatar_url'] as String?;
  String get subscriptionTier => (_profile?['subscription_tier'] ?? 'free') as String;
  bool get isPremium => subscriptionTier == 'premium';
  String get tierLabel => isPremium ? "Agricultor Pro" : "Plan Gratuito";

  // Limites du plan gratuit (illimité en Premium)
  static const int freeFavoritesLimit = 3;
  static const int freeAlertsLimit = 3;

  bool get canAddMoreFavorites => isPremium || _favorites.length < freeFavoritesLimit;
  bool get canAddMoreAlerts => isPremium || _alerts.length < freeAlertsLimit;

  // --- Restrictions Chart (chart_page.dart) ---
  // Périodes accessibles gratuitement (les autres nécessitent le Premium).
  static const List<String> freeChartPeriods = ["1D", "1W"];
  bool canUsePeriod(String period) => isPremium || freeChartPeriods.contains(period);

  // Indicateurs techniques (EMA + Retracements de Fibonacci) : Premium uniquement.
  bool get canUseIndicators => isPremium;

  // Vue "Bougies" (candlestick) : Premium uniquement, "Courbe" reste toujours libre.
  bool get canUseCandleView => isPremium;

  // --- Restrictions News (news_page.dart) ---
  // Toutes les matières suivies dans l'appli (mêmes noms que grainsData) +
  // CLIMA sont accessibles gratuitement ; ECONOMÍA et TECH sont Premium.
  static const List<String> freeNewsCategories = ["TRIGO", "SOJA", "MAIZ", "CANOLA", "GIRASOL", "CLIMA"];
  bool canAccessCategory(String category) => isPremium || freeNewsCategories.contains(category);

  // Nombre d'articles distincts que le plan gratuit peut lire par jour.
  // Le compteur est stocké localement (SharedPreferences) et remis à zéro
  // chaque jour civil (voir _todayKey()).
  static const int freeNewsArticlesLimit = 5;

  Set<String> _articlesReadToday = {};
  bool _dailyReadCountLoaded = false;

  int get articlesReadToday => _articlesReadToday.length;
  int get articlesRemainingToday =>
      (freeNewsArticlesLimit - _articlesReadToday.length).clamp(0, freeNewsArticlesLimit);
  bool get canReadMoreArticlesToday =>
      isPremium || _articlesReadToday.length < freeNewsArticlesLimit;

  String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Charge (ou réinitialise si on a changé de jour) le compteur d'articles
  /// lus aujourd'hui. Appelé une fois au démarrage du provider.
  Future<void> _loadDailyReadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString('news_read_date');
      final todayKey = _todayKey();

      if (storedDate == todayKey) {
        _articlesReadToday = (prefs.getStringList('news_read_ids') ?? []).toSet();
      } else {
        _articlesReadToday = {};
        await prefs.setString('news_read_date', todayKey);
        await prefs.setStringList('news_read_ids', []);
      }
    } catch (e) {
      debugPrint("Erreur chargement compteur d'articles : $e");
    }
    _dailyReadCountLoaded = true;
    notifyListeners();
  }

  /// Enregistre la lecture d'un article (identifié par son URL, unique par
  /// article) pour le plan gratuit. Retourne `true` si la lecture est
  /// autorisée (Premium, article déjà lu aujourd'hui, ou limite non
  /// atteinte), `false` si la limite quotidienne est atteinte.
  Future<bool> registerArticleRead(String articleId) async {
    if (isPremium) return true;
    if (!_dailyReadCountLoaded) await _loadDailyReadCount();
    if (_articlesReadToday.contains(articleId)) return true; // déjà comptabilisé aujourd'hui

    if (_articlesReadToday.length >= freeNewsArticlesLimit) {
      return false; // Limite quotidienne atteinte
    }

    _articlesReadToday.add(articleId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('news_read_date', _todayKey());
      await prefs.setStringList('news_read_ids', _articlesReadToday.toList());
    } catch (e) {
      debugPrint("Erreur sauvegarde compteur d'articles : $e");
    }
    return true;
  }

  UserDataProvider() {
    _loadAllData();
    _loadDailyReadCount();

    // Recharge / vide les données utilisateur selon l'état de connexion
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _loadAllData();
      } else if (event == AuthChangeEvent.signedOut) {
        _favorites = [];
        _alerts = [];
        _lastArticle = null;
        _profile = null;
        notifyListeners();
      }
    });
  }

  /// Permet de déclencher un rechargement manuel (ex: pull-to-refresh).
  Future<void> refresh() => _loadAllData();

  // Chargement de toutes les données utilisateur depuis Supabase
  Future<void> _loadAllData() async {
    _isLoading = true;
    notifyListeners();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _favorites = [];
      _alerts = [];
      _lastArticle = null;
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Appels séquentiels : les requêtes Supabase renvoient des types
      // différents (Map pour .single(), List pour les autres), donc on évite
      // Future.wait sur une liste littérale qui pose un problème d'inférence.
      final profileData =
      await _supabase.from('profiles').select().eq('id', userId).single();

      final favoritesData =
      await _supabase.from('favorites').select('grain_name').eq('user_id', userId);

      final alertsData = await _supabase
          .from('alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final historyData = await _supabase
          .from('reading_history')
          .select()
          .eq('user_id', userId)
          .order('read_at', ascending: false)
          .limit(1);

      _profile = Map<String, dynamic>.from(profileData);
      _favorites = (favoritesData as List)
          .map((f) => f['grain_name'] as String)
          .toList();
      _alerts = (alertsData as List)
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
      _lastArticle = (historyData as List).isNotEmpty
          ? Map<String, dynamic>.from(historyData.first)
          : null;
    } catch (e) {
      debugPrint("Erreur chargement des données utilisateur : $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- LOGIQUE ABONNEMENT (colonne "subscription_tier" sur "profiles") ---
  /// Met à jour le plan de l'utilisateur. Pour l'instant ceci change
  /// directement la valeur en base (pas de vrai paiement branché) :
  /// quand un système de paiement (Stripe, RevenueCat...) sera en place,
  /// cet appel devra se faire seulement après confirmation du paiement.
  Future<void> updateSubscriptionTier(String tier) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final previousProfile = _profile;
    _profile = {...?_profile, 'subscription_tier': tier};
    notifyListeners();

    try {
      await _supabase
          .from('profiles')
          .update({'subscription_tier': tier})
          .eq('id', userId);
    } catch (e) {
      _profile = previousProfile;
      notifyListeners();
      debugPrint("Erreur mise à jour du plan : $e");
      rethrow;
    }
  }

  // --- LOGIQUE FAVORIS (table "favorites") ---
  bool isFavorite(String name) => _favorites.contains(name);

  /// Bascule un favori. Retourne `false` sans rien faire si l'utilisateur
  /// est en plan gratuit et a déjà atteint sa limite de favoris (on ne
  /// bloque jamais le retrait d'un favori existant).
  bool toggleFavorite(String name) {
    final wasFavorite = _favorites.contains(name);

    if (!wasFavorite && !canAddMoreFavorites) {
      return false; // Limite du plan gratuit atteinte
    }

    if (wasFavorite) {
      _favorites.remove(name);
    } else {
      _favorites.add(name);
    }
    notifyListeners();
    _syncFavorite(name, add: !wasFavorite);
    return true;
  }

  Future<void> _syncFavorite(String name, {required bool add}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (add) {
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'grain_name': name,
        });
      } else {
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('grain_name', name);
      }
    } catch (e) {
      // Rollback si la synchronisation échoue
      if (add) {
        _favorites.remove(name);
      } else {
        _favorites.add(name);
      }
      notifyListeners();
      debugPrint("Erreur synchronisation favori : $e");
    }
  }

  // --- LOGIQUE DERNIER ARTICLE (table "reading_history") ---
  Future<void> setLastArticle(Map<String, dynamic> article) async {
    _lastArticle = article;
    notifyListeners();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('reading_history').insert({
        'user_id': userId,
        'article_id': article['id']?.toString(),
        'title': article['title'] ?? 'Sin título',
      });
    } catch (e) {
      debugPrint("Erreur enregistrement dernier article : $e");
    }
  }

  // --- LOGIQUE ALERTES (table "alerts") ---
  /// Retourne `false` sans rien faire si la limite du plan gratuit est
  /// atteinte.
  Future<bool> addAlert(String commodity, double price) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    if (!canAddMoreAlerts) {
      return false; // Limite du plan gratuit atteinte
    }

    // Ajout optimiste avec un id temporaire, remplacé une fois la ligne
    // réellement créée en base.
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final newAlert = {
      'id': tempId,
      'commodity': commodity,
      'price': price,
      'status': 'Activa',
    };
    _alerts.add(newAlert);
    notifyListeners();

    try {
      final inserted = await _supabase
          .from('alerts')
          .insert({
        'user_id': userId,
        'commodity': commodity,
        'price': price,
        'status': 'Activa',
      })
          .select()
          .single();

      final index = _alerts.indexWhere((a) => a['id'] == tempId);
      if (index != -1) {
        _alerts[index] = Map<String, dynamic>.from(inserted);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _alerts.removeWhere((a) => a['id'] == tempId);
      notifyListeners();
      debugPrint("Erreur ajout alerte : $e");
      return false;
    }
  }

  Future<void> removeAlert(int index) async {
    if (index < 0 || index >= _alerts.length) return;

    final removed = _alerts[index];
    _alerts.removeAt(index);
    notifyListeners();

    final id = removed['id'];
    // Rien à supprimer côté serveur si l'insertion n'a pas encore abouti.
    if (id == null || id.toString().startsWith('temp-')) return;

    try {
      await _supabase.from('alerts').delete().eq('id', id);
    } catch (e) {
      _alerts.insert(index, removed);
      notifyListeners();
      debugPrint("Erreur suppression alerte : $e");
    }
  }
}