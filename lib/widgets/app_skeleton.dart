import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Un rectangle animé (effet "shimmer") à utiliser à la place d'un
/// CircularProgressIndicator nu pendant un chargement — donne une idée de
/// la forme du contenu à venir plutôt qu'une simple roue qui tourne.
///
/// Usage :
///   AppSkeleton(height: 18, width: 140)                 // une ligne de texte
///   AppSkeleton.circle(size: 50)                         // un avatar
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  const AppSkeleton.circle({super.key, double size = 48})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral200,
      highlightColor: AppColors.neutral50,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Une "carte" de skeleton prête à l'emploi, pour remplacer un ListTile
/// pendant son chargement (icône + deux lignes de texte). Reprend les
/// dimensions habituelles des cartes de l'app (radius 15-20, padding).
class AppSkeletonTile extends StatelessWidget {
  const AppSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const AppSkeleton.circle(size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(height: 14, width: 140),
                SizedBox(height: 8),
                AppSkeleton(height: 12, width: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une colonne de [count] AppSkeletonTile, pour remplacer une liste entière
/// pendant son chargement.
class AppSkeletonList extends StatelessWidget {
  final int count;

  const AppSkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const AppSkeletonTile()),
    );
  }
}