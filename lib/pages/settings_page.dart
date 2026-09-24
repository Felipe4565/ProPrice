import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_page_route.dart';
import '../theme/app_theme.dart';
import 'auth_page.dart';
import 'settings_subpages/currency_page.dart';
import 'settings_subpages/language_page.dart';
import 'settings_subpages/profile_page.dart';
import 'settings_subpages/security_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    // Les couleurs codées en dur (forestGreen / backgroundCream) sont
    // remplacées par AppColors. Le Scaffold récupère déjà sa couleur de fond
    // via AppTheme (scaffoldBackgroundColor), donc plus besoin de la répéter
    // ici, mais on la laisse explicite pour la clarté du fichier.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Avant : backgroundColor: backgroundCream (un bloc de couleur plein).
        // Le thème global gère déjà une AppBar transparente/immergée ;
        // on ne force donc plus aucune couleur ici.
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: AppColors.forest500),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // TITRE DE LA PAGE
            const Center(
              child: Text(
                "CONFIGURACIÓN DE LA\nCUENTA",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest500,
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
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
              label: const Text(
                "Cerrar Sesión",
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // BOUTON SUPPRESSION DE COMPTE
            TextButton.icon(
              onPressed: () => _confirmDeleteAccount(),
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 20),
              label: const Text(
                "Eliminar Cuenta",
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- MÉTHODES UTILITAIRES ---
  void _navigateTo(BuildContext context, Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      AppPageRoute(builder: (context) => page),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.forest500.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // Avant : Colors.black.withOpacity(0.03) — ombre grise générique.
        // Ombre teintée avec la couleur de marque, beaucoup plus subtile.
        boxShadow: AppTheme.softShadow().map((s) => s.scale(0.4)).toList(),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.forest500, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
      ),
    );
  }

  Widget _buildSettingSwitch(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.forest500, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        value: value,
        activeColor: AppColors.forest500,
        onChanged: (val) {
          HapticFeedback.mediumImpact();
          onChanged(val);
        },
      ),
    );
  }

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
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _performLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SALIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext dialogContext) async {
    // Ferme le dialogue de confirmation
    Navigator.pop(dialogContext);

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    // Vide toute la pile de navigation et repart sur AuthPage
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(builder: (context) => const AuthPage()),
          (route) => false,
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar cuenta?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Esta acción es irreversible. Todos tus datos serán eliminados permanentemente."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _performDeleteAccount(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(BuildContext dialogContext) async {
    Navigator.pop(dialogContext); // ferme le dialogue de confirmation

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status == 200) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          AppPageRoute(builder: (context) => const AuthPage()),
              (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression du compte.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }
}