import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/reset_password_page.dart';
import 'providers/app_settings.dart';
import 'providers/user_data_provider.dart';
import 'services/navigation_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_page_route.dart';
import 'theme/app_theme.dart';

// Gère les messages FCM reçus alors que l'app est totalement fermée ou en
// arrière-plan. Doit être une fonction top-level (pas une méthode de classe),
// car elle s'exécute dans un isolate séparé.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Push] Message reçu en arrière-plan : ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Initialisation Firebase (nécessaire pour les notifications push) ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://jmesahlrugcxrjygzcbn.supabase.co',
    publishableKey: 'sb_publishable_cWXJ69n7Ja0i90DSb3IAUQ_7JvfSzjX',
  );

  // Enregistre le handler pour les messages reçus app fermée/en arrière-plan,
  // et met en place l'affichage au premier plan + la navigation au tap.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.setupMessageHandlers();

  // Écoute globale des événements d'authentification.
  // Dès qu'un lien "mot de passe oublié" est ouvert (type: recovery),
  // on force la navigation vers l'écran de réinitialisation, peu importe
  // où l'utilisateur se trouve dans l'appli à ce moment-là.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        AppPageRoute(builder: (context) => const ResetPasswordPage()),
      );
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ],
      child: const PropriceApp(),
    ),
  );
}

class PropriceApp extends StatelessWidget {
  const PropriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      // Le thème vient maintenant entièrement de lib/theme/app_theme.dart.
      // On y ajoute juste le scrollbarTheme, spécifique à cette app, via copyWith.
      theme: AppTheme.light.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(
            AppColors.forest500.withValues(alpha: 0.5),
          ),
          radius: const Radius.circular(10),
          thickness: WidgetStateProperty.all(6.0),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
      ),
      // Vérifie bien que ce nom correspond à la classe du dessous
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _startAppSequence();
  }

  Future<void> _startAppSequence() async {
    await Future.delayed(const Duration(seconds: 2));
    _navigateNext();
  }

  void _navigateNext() {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    // Si l'utilisateur est déjà connecté (pas besoin de repasser par AuthPage),
    // on (ré)enregistre son token FCM au cas où il aurait changé.
    if (session != null) {
      PushNotificationService.instance.initForCurrentUser();
    }

    Navigator.pushReplacement(
      context,
      AppPageRoute(
        builder: (context) => session != null ? const HomePage() : const AuthPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Avant : Color(0xFF1B4D3E), une nuance différente de AppColors.forest500
    // (0xFF1B4332) utilisée partout ailleurs dans l'app. On aligne les deux.
    const Color darkGreen = AppColors.forest500;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(45),
                boxShadow: AppTheme.softShadow(darkGreen),
              ),
              child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 90),
            ),
            const SizedBox(height: 40),
            Text(
              'PROPRICE',
              style: AppTheme.brandTitle(fontSize: 42, color: darkGreen, letterSpacing: 2),
            ),
            const Spacer(),
            const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(darkGreen)
            ),
            const Spacer(),
            Text(
                '"Slogan de l\'entreprise"',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: darkGreen.withValues(alpha: 0.6))
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}