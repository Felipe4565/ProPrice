import 'dart:async';

import 'package:flutter/material.dart';
import 'package:proprice/services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_page.dart';
import 'terms_conditions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_page_route.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final biometricService = BiometricService();
  final supabase = Supabase.instance.client;

  bool _isBiometricEnabled = false;
  String? _currentEmail;

  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
    _currentEmail = supabase.auth.currentUser?.email;

    // Écoute les changements d'auth (ex: email confirmé via le lien reçu par mail)
    // pour rafraîchir automatiquement l'affichage sans avoir à relancer l'appli.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentEmail = supabase.auth.currentUser?.email;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // Fonction pour lire la mémoire du téléphone
  Future<void> _loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('bio_enabled') ?? false;
    });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.forest500,
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
            subtitle: _currentEmail ?? "Cargando...",
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
            switchValue: _isBiometricEnabled,
            onChanged: (val) => _handleBiometricToggle(val),
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
              // Logique pour el profil público
            },
          ),
          _buildSecurityItem(
            icon: Icons.description_outlined,
            title: "Términos y condiciones",
            onTap: () {
              Navigator.push(
                context,
                AppPageRoute(builder: (context) => const TermsAndConditionsPage()),
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
          color: AppColors.forest500,
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
            color: AppColors.forest500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.forest500),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
            : null,
        trailing: isSwitch
            ? Switch(
          value: switchValue,
          onChanged: onChanged,
          activeColor: AppColors.forest500,
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
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Card(
          elevation: 0,
          color: const Color(0xFFFFEBEE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.redAccent, width: 0.5),
          ),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Eliminar cuenta",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ),
      ],
    );
  }

  // --- MODIFIER EMAIL (réel, avec réauthentification) ---
  void _showEditEmailDialog(BuildContext context) {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isLoading = false;
          String? errorText;

          return StatefulBuilder(
            builder: (context, setState2) => AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Modificar Email",
                style: TextStyle(color: AppColors.forest500, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Introduce tu nuevo email y confirma con tu contraseña actual.",
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Nuevo Email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña actual",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    final newEmail = newEmailController.text.trim();
                    final password = passwordController.text;

                    if (newEmail.isEmpty || !newEmail.contains('@')) {
                      setState2(() => errorText = "Introduce un email válido.");
                      return;
                    }
                    if (password.isEmpty) {
                      setState2(() => errorText = "Introduce tu contraseña actual.");
                      return;
                    }

                    setState2(() {
                      isLoading = true;
                      errorText = null;
                    });

                    try {
                      // Réauthentification pour confirmer l'identité
                      await supabase.auth.signInWithPassword(
                        email: _currentEmail!,
                        password: password,
                      );

                      // Changement d'email (Supabase envoie un email de confirmation
                      // avec un lien qui rouvre directement l'appli)
                      await supabase.auth.updateUser(
                        UserAttributes(email: newEmail),
                        emailRedirectTo: 'proprice://login-callback',
                      );

                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Revisa tu bandeja de entrada para confirmar el nuevo email.",
                            ),
                            backgroundColor: AppColors.forest500,
                          ),
                        );
                      }
                    } on AuthException catch (e) {
                      setState2(() {
                        isLoading = false;
                        errorText = e.message;
                      });
                    } catch (e) {
                      setState2(() {
                        isLoading = false;
                        errorText = "Error inesperado.";
                      });
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text("ACTUALIZAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CHANGER MOT DE PASSE (réel, avec réauthentification) ---
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState2) {
          bool isLoading = false;
          String? errorText;

          return StatefulBuilder(
            builder: (context, setState3) => AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Cambiar contraseña",
                style: TextStyle(color: AppColors.forest500, fontWeight: FontWeight.bold),
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
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña actual",
                        prefixIcon: const Icon(Icons.lock_open),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                          Navigator.pop(context);
                          _showForgotPasswordConfirmation(context);
                        },
                        child: const Text(
                          "¿Olvidaste tu contraseña?",
                          style: TextStyle(
                            color: AppColors.forest500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Nueva contraseña",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Confirmar nueva contraseña",
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    final currentPassword = currentPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirmPassword = confirmPasswordController.text;

                    if (currentPassword.isEmpty) {
                      setState3(() => errorText = "Introduce tu contraseña actual.");
                      return;
                    }
                    if (newPassword.length < 6) {
                      setState3(() => errorText = "La nueva contraseña debe tener al menos 6 caracteres.");
                      return;
                    }
                    if (newPassword != confirmPassword) {
                      setState3(() => errorText = "Las contraseñas no coinciden.");
                      return;
                    }

                    setState3(() {
                      isLoading = true;
                      errorText = null;
                    });

                    try {
                      // Réauthentification pour confirmer l'identité
                      await supabase.auth.signInWithPassword(
                        email: _currentEmail!,
                        password: currentPassword,
                      );

                      await supabase.auth.updateUser(
                        UserAttributes(password: newPassword),
                      );

                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text("Contraseña actualizada con éxito"),
                            backgroundColor: AppColors.forest500,
                          ),
                        );
                      }
                    } on AuthException catch (e) {
                      setState3(() {
                        isLoading = false;
                        errorText = e.message;
                      });
                    } catch (e) {
                      setState3(() {
                        isLoading = false;
                        errorText = "Error inesperado.";
                      });
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text("GUARDAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MOT DE PASSE OUBLIÉ (réel) ---
  void _showForgotPasswordConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Restablecer contraseña",
          style: TextStyle(color: AppColors.forest500, fontWeight: FontWeight.bold),
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
              backgroundColor: AppColors.forest500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (_currentEmail == null) return;
              try {
                await supabase.auth.resetPasswordForEmail(
                  _currentEmail!,
                  redirectTo: 'proprice://login-callback',
                );
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text("Email de recuperación enviado con éxito"),
                      backgroundColor: AppColors.forest500,
                    ),
                  );
                }
              } on AuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("ENVIAR EMAIL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- SUPPRESSION DE COMPTE (réel, via Edge Function delete-account) ---
  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState2) {
          bool isLoading = false;
          String? errorText;

          return StatefulBuilder(
            builder: (context, setState3) => AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Eliminar cuenta",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Esta acción es irreversible. Confirma tu contraseña para proceder."),
                    const SizedBox(height: 20),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: _currentEmail ?? ""),
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
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    final password = passwordController.text;

                    if (password.isEmpty || _currentEmail == null) {
                      setState3(() => errorText = "Introduce tu contraseña.");
                      return;
                    }

                    setState3(() {
                      isLoading = true;
                      errorText = null;
                    });

                    try {
                      // Réauthentification pour confirmer l'identité
                      await supabase.auth.signInWithPassword(
                        email: _currentEmail!,
                        password: password,
                      );

                      final session = supabase.auth.currentSession;
                      if (session == null) {
                        throw Exception("Sesión no encontrada.");
                      }

                      final response = await supabase.functions.invoke(
                        'delete-account',
                        headers: {'Authorization': 'Bearer ${session.accessToken}'},
                      );

                      if (response.status != 200) {
                        throw Exception("No se pudo eliminar la cuenta.");
                      }

                      await supabase.auth.signOut();

                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          this.context,
                          AppPageRoute(builder: (context) => const AuthPage()),
                              (route) => false,
                        );
                      }
                    } on AuthException catch (e) {
                      setState3(() {
                        isLoading = false;
                        errorText = e.message;
                      });
                    } catch (e) {
                      setState3(() {
                        isLoading = false;
                        errorText = "No se pudo eliminar la cuenta.";
                      });
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}