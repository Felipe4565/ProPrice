import 'package:flutter/material.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
        elevation: 0,
        title: const Text(
          "SEGURIDAD Y PRIVACIDAD",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle("Acceso"),
          _buildSecurityItem(
            icon: Icons.lock_outline,
            title: "Cambiar contraseña",
            subtitle: "Actualiza tu clave regularmente",
            onTap: () {
              // Action pour changer le MDP
            },
          ),
          _buildSecurityItem(
            icon: Icons.fingerprint,
            title: "Biometría",
            subtitle: "Huella digital o Face ID",
            isSwitch: true,
            switchValue: true, // À lier avec une variable d'état
            onChanged: (val) {},
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle("Privacidad"),
          _buildSecurityItem(
            icon: Icons.visibility_off_outlined,
            title: "Perfil público",
            subtitle: "Permitir que otros vean mi actividad",
            isSwitch: true,
            switchValue: false,
            onChanged: (val) {},
          ),
          _buildSecurityItem(
            icon: Icons.description_outlined,
            title: "Términos y condiciones",
            onTap: () {},
          ),

          const SizedBox(height: 40),
          _buildDangerZone(context),
        ],
      ),
    );
  }

  // Widget pour les titres de section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1B4332),
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Widget pour chaque ligne de réglage
  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool isSwitch = false,
    bool switchValue = false,
    Function(bool)? onChanged,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4332).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1B4332)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
        trailing: isSwitch 
          ? Switch(
              value: switchValue, 
              onChanged: onChanged,
              activeColor: const Color(0xFF1B4332),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: isSwitch ? null : onTap,
      ),
    );
  }

  // Zone critique : Suppression du compte
  Widget _buildDangerZone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text("ZONA PELIGROSA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Card(
          elevation: 0,
          color: const Color(0xFFFFEBEE),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Eliminar cuenta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              // Afficher un dialogue de confirmation
            },
          ),
        ),
      ],
    );
  }
}