import 'package:flutter/material.dart';
import 'package:proprice/services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'terms_conditions.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final biometricService = BiometricService();
  bool _isBiometricEnabled = false; // Valeur initiale

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
        elevation: 0,
        title: const Text(
          "SEGURIDAD Y PRIVACIDAD",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle("Cuenta"),
          _buildSecurityItem(
            icon: Icons.email_outlined,
            title: "Modificar Email",
            subtitle: "jean.dupont@email.com", // À remplacer par l'email réel
            onTap: () => _showEditEmailDialog(context),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle("Acceso"),
          _buildSecurityItem(
            icon: Icons.lock_outline,
            title: "Cambiar contraseña",
            subtitle: "Actualiza tu clave regularmente",
            onTap: () => _showChangePasswordDialog(context), 
          ),
          _buildSecurityItem(
            icon: Icons.fingerprint,
            title: "Biometría",
            subtitle: "Huella digital o Face ID",
            isSwitch: true,
            switchValue: _isBiometricEnabled, // CHANGE : utilise la variable au lieu de 'true'
            onChanged: (val) => _handleBiometricToggle(val), // CHANGE : appelle la fonction
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle("Privacidad"),
          _buildSecurityItem(
            icon: Icons.visibility_off_outlined,
            title: "Perfil público",
            subtitle: "Permitir que otros vean mi actividad",
            isSwitch: true,
            switchValue: false,
            onChanged: (val) {
              // Logique pour le profil public
            },
          ),
          _buildSecurityItem(
            icon: Icons.description_outlined,
            title: "Términos y condiciones",
            onTap: () {
              Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
                  );   
           },
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
        subtitle: subtitle != null 
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) 
            : null,
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
          child: Text(
            "ZONA PELIGROSA", 
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)
          ),
        ),
        Card(
          elevation: 0,
          color: const Color(0xFFFFEBEE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
            side: const BorderSide(color: Colors.redAccent, width: 0.5)
          ),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Eliminar cuenta", 
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
            ),
            // --- MODIFICATION ICI ---
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ),
      ],
    );
  }

  // Dialogue de modification d'email
  // Dialogue de modification d'email avec option mot de passe oublié
void _showEditEmailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2EFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Modificar Email",
          style: TextStyle(color: Color(0xFF1B4332), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Introduce tu nuevo email y confirma con tu contraseña actual.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Nuevo Email",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Contraseña actual",
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // On ferme d'abord le dialogue de modification d'email
                  Navigator.pop(context);
                  // On ouvre le dialogue de récupération
                  _showForgotPasswordConfirmation(context);
                },
                child: const Text(
                  "¿Olvidaste tu contraseña?",
                  style: TextStyle(
                    color: Color(0xFF1B4332),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Logique de mise à jour de l'email ici
              Navigator.pop(context);
            },
            child: const Text("ACTUALIZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- NOUVELLE FONCTION POUR L'ENVOI DE L'EMAIL ---
  void _showForgotPasswordConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2EFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Restablecer contraseña",
          style: TextStyle(color: Color(0xFF1B4332), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Enviaremos un enlace de recuperación a tu dirección de correo electrónico actual para que puedas crear una nueva contraseña.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // ICI : Appelle ta fonction Firebase ou API pour envoyer le mail
              // Exemple : await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Email de recuperación enviado con éxito"),
                  backgroundColor: Color(0xFF1B4332),
                ),
              );
            },
            child: const Text("ENVIAR EMAIL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2EFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Cambiar contraseña",
          style: TextStyle(color: Color(0xFF1B4332), fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ingresa tu clave actual y la nueva para actualizarla.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña actual",
                  prefixIcon: const Icon(Icons.lock_open),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              // --- LIEN MOT DE PASSE OUBLIÉ ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Ferme le dialogue actuel
                    _showForgotPasswordConfirmation(context); // Ouvre la confirmation d'envoi d'email
                  },
                  child: const Text(
                    "¿Olvidaste tu contraseña?",
                    style: TextStyle(
                      color: Color(0xFF1B4332),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Nueva contraseña",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirmar nueva contraseña",
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4332),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Logique de validation (vérifier si les deux nouveaux MDP sont identiques)
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Contraseña actualizada con éxito"),
                  backgroundColor: Color(0xFF1B4332),
                ),
              );
            },
            child: const Text("GUARDAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBiometricToggle(bool targetValue) async {
    final prefs = await SharedPreferences.getInstance();

    if (!targetValue) {
      setState(() => _isBiometricEnabled = false);
      await prefs.setBool('bio_enabled', false);
      return;
    }

    final ok = await biometricService.authenticate(
      reason: 'Identifícate para entrar en Proprice',
    );

    if (ok) {
      setState(() => _isBiometricEnabled = true);
      await prefs.setBool('bio_enabled', true);
    }
  }

    @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  // Fonction pour lire la mémoire du téléphone
  Future<void> _loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Si 'bio_enabled' n'existe pas encore, on met false par défaut
      _isBiometricEnabled = prefs.getBool('bio_enabled') ?? false;
    });
  }


  void _showDeleteAccountDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2EFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Eliminar cuenta",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Esta acción es irreversible. Confirma tus credenciales para proceder."),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Contraseña",
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                // Petit message d'erreur si vide
                return; 
              }
              // ICI : Ajoute ta logique d'appel API ou Firebase Auth
              // Exemple : await _authService.deleteUser(email: emailController.text, password: passwordController.text);
              
              debugPrint("Suppression demandée pour: ${emailController.text}");
              Navigator.pop(context);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}