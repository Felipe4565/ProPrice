import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_subpages/currency_page.dart';
import 'settings_subpages/language_page.dart';
// Importation des fichiers séparés (Assure-toi de les avoir créés dans le dossier settings_subpages)
import 'settings_subpages/profile_page.dart';
import 'settings_subpages/security_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // État local pour l'interrupteur rapide des notifications
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    const Color forestGreen = Color(0xFF1B4332);
    const Color backgroundCream = Color(0xFFF2EFE9);

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // TITRE DE LA PAGE
            const Center(
              child: Text(
                "CONFIGURACIÓN DE LA\nCUENTA",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: forestGreen, 
                  height: 1.2,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            
            const SizedBox(height: 40),

            // --- SECTION : COMPTE ---
            _buildSectionTitle("COMPTE"),
            _buildSettingItem(
              Icons.person_outline_rounded, 
              "Perfil Personal", 
              onTap: () => _navigateTo(context, const ProfilePage()),
            ),
            _buildSettingItem(
              Icons.security_outlined, 
              "Seguridad y Privacidad",
              onTap: () => _navigateTo(context, const SecurityPage()),
            ),

            const SizedBox(height: 25),

            // --- SECTION : PRÉFÉRENCES ---
            _buildSectionTitle("PRÉFÉRENCES"),
            _buildSettingSwitch(
              Icons.notifications_active_outlined,
              "Alertas de Mercado",
              _notificationsEnabled,
              (val) => setState(() => _notificationsEnabled = val),
            ),
            _buildSettingItem(
              Icons.language_rounded, 
              "Idioma", 
              onTap: () => _navigateTo(context, const LanguagePage()),
            ),

            _buildSettingItem(
              Icons.account_balance_wallet_outlined, 
              "Valores-Divisa-Balanza",
              onTap: () => _navigateTo(context, const CurrencyPage()),
            ),

            const SizedBox(height: 40),

            // BOUTON DÉCONNEXION
            TextButton.icon(
              onPressed: () => _confirmLogout(),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              label: const Text(
                "Cerrar Sesión", 
                style: TextStyle(
                  color: Colors.redAccent, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                ),
              ),
            ),
            
            const SizedBox(height: 120), // Espace pour le scroll au-dessus de la barre de navigation
          ],
        ),
      ),
    );
  }

  // --- FONCTION DE NAVIGATION GÉNÉRIQUE ---
  void _navigateTo(BuildContext context, Widget page) {
    HapticFeedback.lightImpact(); // Vibration légère pour le feeling
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // --- WIDGET : TITRE DE SECTION ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title, 
          style: TextStyle(
            color: const Color(0xFF1B4332).withOpacity(0.5), 
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.5
          ),
        ),
      ),
    );
  }

  // --- WIDGET : ÉLÉMENT DE LISTE (BOUTON) ---
  Widget _buildSettingItem(IconData icon, String title, {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(
            color: const Color(0xFFF2EFE9), 
            borderRadius: BorderRadius.circular(12)
          ), 
          child: Icon(icon, color: const Color(0xFF1B4332), size: 22)
        ),
        title: Text(
          title, 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
      ),
    );
  }

  // --- WIDGET : ÉLÉMENT AVEC INTERRUPTEUR ---
  Widget _buildSettingSwitch(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20)
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(
            color: const Color(0xFFF2EFE9), 
            borderRadius: BorderRadius.circular(12)
          ), 
          child: Icon(icon, color: const Color(0xFF1B4332), size: 22)
        ),
        title: Text(
          title, 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
        ),
        value: value,
        activeColor: const Color(0xFF1B4332),
        onChanged: (val) {
          HapticFeedback.mediumImpact();
          onChanged(val);
        },
      ),
    );
  }

  // --- DIALOGUE DE CONFIRMATION ---
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cerrar Sesión?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Tu sesión se cerrará y tendrás que volver a ingresar tus datos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ), 
            child: const Text("SALIR", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}