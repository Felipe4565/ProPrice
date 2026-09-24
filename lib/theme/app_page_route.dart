import 'package:flutter/material.dart';

/// Transition de page uniforme pour ProPrice : fondu + léger glissement
/// depuis la droite, à utiliser à la place de MaterialPageRoute qui fait
/// un glissement plein écran sec, sans fondu.
///
/// Usage :
///   Navigator.push(context, AppPageRoute(builder: (context) => const MaPage()));
/// au lieu de :
///   Navigator.push(context, MaterialPageRoute(builder: (context) => const MaPage()));
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}