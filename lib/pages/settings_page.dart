import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color forestGreen = Color(0xFF1B4332);
    const Color backgroundCream = Color(0xFFF2EFE9); // J'ai ajusté pour matcher ton main.dart

    return Scaffold(
      backgroundColor: backgroundCream,
      // ON ENLÈVE L'APPBAR ICI car HomePage en a déjà une
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "CONFIGURACIÓN DE LA\nCUENTA",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: forestGreen,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            _buildSettingItem(Icons.person_outline, "Perfil Personal"),
            _buildSettingItem(Icons.notifications_active_outlined, "Alertas de Mercado"),
            _buildSettingItem(Icons.language_rounded, "Idioma (Español)"),
            _buildSettingItem(Icons.security_outlined, "Seguridad y Privacidad"),
            _buildSettingItem(Icons.account_balance_wallet_outlined, "Valores-Divisa-Balanza"),
            
            const SizedBox(height: 30),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
              label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 120), // Un peu plus d'espace pour le scroll
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B4332), size: 26),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}