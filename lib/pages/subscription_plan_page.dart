import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SubscriptionPlanPage extends StatefulWidget {
  const SubscriptionPlanPage({super.key});

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  static const Color forestGreen = AppColors.forest500;
  static const Color backgroundCream = AppColors.background;

  bool _isUpdating = false;

  Future<void> _selectPlan(String tier) async {
    final provider = context.read<UserDataProvider>();
    if (provider.subscriptionTier == tier) return;

    setState(() => _isUpdating = true);
    try {
      await provider.updateSubscriptionTier(tier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tier == 'premium'
                ? "¡Bienvenido a Agricultor Pro!"
                : "Has cambiado al Plan Gratuito.",
          ),
          backgroundColor: forestGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo cambiar de plan: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserDataProvider>();
    final currentTier = provider.subscriptionTier;

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: backgroundCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: forestGreen),
        title: const Text(
          "Mi Plan",
          style: TextStyle(color: forestGreen, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Elige el plan que mejor se adapte a tu explotación",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                _PlanCard(
                  title: "Plan Gratuito",
                  price: "Gratis",
                  isCurrent: currentTier == 'free',
                  accentColor: Colors.blueGrey,
                  features: const [
                    "Hasta ${UserDataProvider.freeFavoritesLimit} cultivos favoritos",
                    "Hasta ${UserDataProvider.freeAlertsLimit} alertas de precio",
                    "Acceso a las noticias generales",
                  ],
                  onSelect: () => _selectPlan('free'),
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  title: "Agricultor Pro",
                  price: "4,99 \$ / mes",
                  isCurrent: currentTier == 'premium',
                  accentColor: forestGreen,
                  highlighted: true,
                  features: const [
                    "Cultivos favoritos ilimitados",
                    "Alertas de precio ilimitadas",
                    "Notificaciones prioritarias",
                    "Acceso anticipado a artículos y análisis",
                  ],
                  onSelect: () => _selectPlan('premium'),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    "El pago aún no está conectado a un procesador real: "
                        "este botón cambia el plan directamente para pruebas.",
                    style: TextStyle(fontSize: 12, color: Colors.black45, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator(color: forestGreen)),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isCurrent;
  final bool highlighted;
  final Color accentColor;
  final List<String> features;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.isCurrent,
    required this.accentColor,
    required this.features,
    required this.onSelect,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? accentColor : Colors.grey.withValues(alpha: 0.15),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          if (highlighted)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: AppTheme.priceStyle(fontSize: 18, color: accentColor),
                  ),
                  if (highlighted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "POPULAR",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Plan actual",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ...features.map(
                (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: accentColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent ? null : onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.grey.shade200 : accentColor,
                foregroundColor: isCurrent ? Colors.black45 : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isCurrent ? "Plan actual" : "Elegir este plan",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}