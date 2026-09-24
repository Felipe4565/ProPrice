import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/chart_page.dart';
import '../pages/home_page.dart';
import '../providers/user_data_provider.dart';
import 'navigation_service.dart';

/// Centralise tout ce qui concerne les notifications push :
/// - demande de permission (obligatoire sur iOS et Android 13+)
/// - récupération et sauvegarde du token FCM dans Supabase
/// - ré-enregistrement automatique si le token change (rotation FCM)
/// - affichage de la notif quand l'app est au premier plan
/// - navigation au tap sur une notif (app ouverte, en arrière-plan, ou fermée)
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications importantes',
    description: 'Alertes de prix et actualités ProPrice',
    importance: Importance.high,
  );

  bool _handlersInitialized = false;

  /// À appeler une seule fois au démarrage de l'app (dans main.dart),
  /// que l'utilisateur soit connecté ou non. Met en place l'affichage
  /// au premier plan et la navigation au tap.
  Future<void> setupMessageHandlers() async {
    if (_handlersInitialized) return;
    _handlersInitialized = true;

    await _initLocalNotifications();

    // App au premier plan : Android n'affiche rien tout seul dans ce cas,
    // on doit le faire nous-mêmes via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // L'utilisateur tape sur la notif alors que l'app était en arrière-plan
    // (pas fermée, juste mise de côté).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    // L'app était complètement fermée et a été rouverte via un tap sur la notif.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      // Tap sur la notif pendant que l'app était au premier plan
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _handleNotificationTap(data);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[Push] Notification tapée, data: $data');

    final commodity = data['commodity'] as String?;
    if (commodity == null || commodity.isEmpty) {
      // Pas de matière première précisée (ex: notif d'article) -> page d'accueil
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
      return;
    }

    // On lit l'état "favori" actuel via le provider pour initialiser le
    // ValueNotifier attendu par ChartPage (le bouton favori dans le graphique
    // doit refléter le bon état dès l'ouverture).
    bool isFavorite = false;
    final context = navigatorKey.currentContext;
    if (context != null) {
      final provider = Provider.of<UserDataProvider>(context, listen: false);
      isFavorite = provider.isFavorite(commodity);
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChartPage(
          commodityName: commodity,
          favoriteNotifier: ValueNotifier<bool>(isFavorite),
        ),
      ),
    );
  }

  /// À appeler une fois qu'un utilisateur est connecté (juste après
  /// signIn/signUp réussi, ou au démarrage si une session existe déjà).
  Future<void> initForCurrentUser() async {
    debugPrint('[Push] initForCurrentUser() appelé');

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Push] Aucun utilisateur connecté, on arrête ici');
      return;
    }
    debugPrint('[Push] userId = $userId');

    try {
      final granted = await _requestPermission();
      debugPrint('[Push] Permission accordée ? $granted');
      if (!granted) return;

      final token = await _messaging.getToken();
      debugPrint('[Push] Token FCM récupéré : $token');

      if (token != null) {
        await _saveToken(userId, token);
        debugPrint('[Push] Token sauvegardé avec succès dans Supabase');
      } else {
        debugPrint('[Push] getToken() a renvoyé null !');
      }

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[Push] Token rafraîchi : $newToken');
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          _saveToken(currentUserId, newToken);
        }
      });
    } catch (e, stack) {
      debugPrint('[Push] ERREUR pendant initForCurrentUser: $e');
      debugPrint('[Push] Stack: $stack');
    }
  }

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] authorizationStatus = ${settings.authorizationStatus}');
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      final response = await Supabase.instance.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      ).select();
      debugPrint('[Push] Réponse Supabase upsert : $response');
    } catch (e, stack) {
      debugPrint('[Push] ERREUR upsert device_tokens : $e');
      debugPrint('[Push] Stack: $stack');
    }
  }

  /// À appeler lors de la déconnexion, pour ne pas continuer à notifier
  /// un appareil sur un compte dont il s'est déconnecté.
  Future<void> removeTokenOnLogout() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').delete().eq('token', token);
    } catch (e) {
      debugPrint('[Push] échec de suppression du token : $e');
    }
  }
}