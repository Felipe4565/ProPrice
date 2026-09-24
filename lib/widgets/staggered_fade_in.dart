import 'package:flutter/material.dart';

/// Fait apparaître [child] avec un fondu + une légère translation vers le
/// haut, décalée selon [index] — utilisé pour donner un effet "cascade" à
/// une liste qui vient de se charger, au lieu que tout apparaisse d'un coup.
///
/// Usage typique (à l'intérieur d'un .map ou .builder) :
///   items.asMap().entries.map((entry) => StaggeredFadeIn(
///     index: entry.key,
///     child: _buildListTile(entry.value),
///   ))
class StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;

  /// Décalage entre chaque élément. 50-70ms donne un effet fluide sans
  /// ralentir l'affichage sur une longue liste.
  final Duration stagger;
  final Duration baseDuration;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.stagger = const Duration(milliseconds: 60),
    this.baseDuration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    // On plafonne le délai pour qu'une liste de 50 éléments ne mette pas
    // 5 secondes à finir d'apparaître : au-delà du 8e élément, tout le
    // monde démarre en même temps.
    final cappedIndex = index.clamp(0, 8);
    final delay = stagger * cappedIndex;

    return TweenAnimationBuilder<double>(
      key: ValueKey('staggered_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: baseDuration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}