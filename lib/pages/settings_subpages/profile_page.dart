import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Clé pour la validation du formulaire
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController(text: "Jean Dupont");
  final TextEditingController _emailController = TextEditingController(text: "jean.dupont@email.com");
  final TextEditingController _phoneController = TextEditingController(text: "+33 6 12 34 56 78");

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE ---
  Future<void> _handleUpdate() async {
    // 1. Fermer le clavier
    FocusScope.of(context).unfocus();

    // 2. Valider le formulaire
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      // Simuler un appel API (ex: mise à jour en base de données)
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _isSaving = false);
        HapticFeedback.mediumImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Perfil actualizado con éxito"),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B4332),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color forestGreen = Color(0xFF1B4332);
    const Color backgroundCream = Color(0xFFF2EFE9);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const Text(
            "MI PERFIL",
            style: TextStyle(
              color: forestGreen,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: forestGreen, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form( // Ajout du widget Form pour la validation
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // --- SECTION AVATAR ---
                  _buildAvatarSection(forestGreen, backgroundCream),

                  const SizedBox(height: 20),

                  Text(
                    _nameController.text,
                    style: const TextStyle(color: forestGreen, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const Text(
                    "Socio verificado • 2024",
                    style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0.5, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 35),

                  // --- FORMULAIRE ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel("INFORMACIÓN PERSONAL"),
                        _buildProfileInput(
                          icon: Icons.person_outline_rounded,
                          hint: "Nombre completo",
                          controller: _nameController,
                          type: TextInputType.name,
                          validator: (value) => value!.isEmpty ? "Ingresa tu nombre" : null,
                        ),

                        const SizedBox(height: 20),
                        _buildSectionLabel("DATOS DE CONTACTO"),
                        _buildProfileInput(
                          icon: Icons.alternate_email_rounded,
                          hint: "Email de contacto",
                          controller: _emailController,
                          type: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || !value.contains('@')) return "Email inválido";
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildProfileInput(
                          icon: Icons.phone_iphone_rounded,
                          hint: "Número móvil",
                          controller: _phoneController,
                          type: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- BOUTON SAUVEGARDER ---
                  _buildSaveButton(forestGreen),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS COMPOSANTS ---

  Widget _buildAvatarSection(Color forestGreen, Color backgroundCream) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 125,
            height: 125,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: forestGreen.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))
              ],
            ),
          ),
          const CircleAvatar(
            radius: 52,
            backgroundColor: Color(0xFFE8E3D9),
            child: Icon(Icons.person_rounded, size: 60, color: Color(0xFF1B4332)),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: InkWell(
              onTap: () {
                // Action pour changer de photo
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color forestGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: forestGreen.withOpacity(_isSaving ? 0.1 : 0.25),
              blurRadius: 25,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: forestGreen,
            disabledBackgroundColor: forestGreen.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  "ACTUALIZAR PERFIL",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFF1B4332).withOpacity(0.4),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildProfileInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: Icon(icon, color: const Color(0xFF1B4332).withOpacity(0.7), size: 20),
        title: TextFormField( // Utilisation de TextFormField pour la validation
          controller: controller,
          keyboardType: type,
          validator: validator,
          cursorColor: const Color(0xFF1B4332),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 14),
            border: InputBorder.none,
            isDense: true,
            errorStyle: const TextStyle(fontSize: 10, height: 0.8), // Design des erreurs compact
          ),
        ),
      ),
    );
  }
}