import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true;

  // --- CONTROLLERS (TODOS LOS CAMPOS) ---
  final _lastNameController = TextEditingController(text: "Dupont");
  final _firstNameController = TextEditingController(text: "Jean");
  final _emailController = TextEditingController(text: "jean.dupont@email.com");
  final _passwordController = TextEditingController(text: "password123");
  final _deptController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();

  @override
  void dispose() {
    for (var c in [
      _lastNameController, _firstNameController, _emailController,
      _passwordController, _deptController, _addressController, _countryController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- LÓGICA DE GUARDADO ---
  Future<void> _handleUpdate() async {
    FocusScope.of(context).unfocus();
    
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      // Simulación de API
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildAvatarSection(forestGreen),
                  
                  const SizedBox(height: 30),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECCIÓN OBLIGATORIA ---
                        _buildSectionLabel("DATOS OBLIGATORIOS"),
                        _buildProfileInput(
                          icon: Icons.person_outline_rounded,
                          hint: "Apellido",
                          controller: _lastNameController,
                          validator: (v) => v!.isEmpty ? "Ingresa tu apellido" : null,
                        ),
                        _buildProfileInput(
                          icon: Icons.person_outline_rounded,
                          hint: "Nombre",
                          controller: _firstNameController,
                          validator: (v) => v!.isEmpty ? "Ingresa tu nombre" : null,
                        ),
                        _buildProfileInput(
                          icon: Icons.alternate_email_rounded,
                          hint: "Email de contacto",
                          controller: _emailController,
                          type: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? "Email inválido" : null,
                        ),
                        _buildProfileInput(
                          icon: Icons.lock_outline_rounded,
                          hint: "Contraseña",
                          controller: _passwordController,
                          isPassword: true,
                          validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                        ),

                        const SizedBox(height: 25),

                        // --- SECCIÓN COMPLEMENTARIA ---
                        _buildSectionLabel("LOCALIZACIÓN"),
                        _buildProfileInput(
                          icon: Icons.map_outlined,
                          hint: "Departamento",
                          controller: _deptController,
                        ),
                        _buildProfileInput(
                          icon: Icons.home_outlined,
                          hint: "Dirección exacta",
                          controller: _addressController,
                        ),
                        _buildProfileInput(
                          icon: Icons.public_rounded,
                          hint: "País",
                          controller: _countryController,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
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

  // --- COMPONENTES UI MEJORADOS ---

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
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: Icon(icon, color: const Color(0xFF1B4332).withOpacity(0.6), size: 20),
        title: TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: type,
          validator: validator,
          cursorColor: const Color(0xFF1B4332),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Color forestGreen) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white,
              boxShadow: [BoxShadow(color: forestGreen.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
          ),
          const CircleAvatar(
            radius: 50, backgroundColor: Color(0xFFE8E3D9),
            child: Icon(Icons.person_rounded, size: 55, color: Color(0xFF1B4332)),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: InkWell(
              onTap: () => HapticFeedback.lightImpact(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestGreen, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
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
        width: double.infinity, height: 60,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: forestGreen.withOpacity(_isSaving ? 0.1 : 0.25), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: forestGreen,
            disabledBackgroundColor: forestGreen.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                ),
        ),
      ),
    );
  }
}