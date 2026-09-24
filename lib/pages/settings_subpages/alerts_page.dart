import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Avant : backgroundColor: Color(0xFF1B4332) (bandeau vert plein).
        // Le thème global fournit déjà une AppBar transparente immergée.
        title: const Text(
          "ALERTAS DE MERCADO",
          style: TextStyle(color: AppColors.forest700, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.forest700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text("Configuración de notificaciones de precios...")),
    );
  }
}