import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _hasChanges = false;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _paisesOptions = [
    "Argentina", "Bolivia", "Brasil", "Chile", "Colombia", "Costa Rica", 
    "Cuba", "Ecuador", "El Salvador", "España", "Estados Unidos", "Francia",
    "Guatemala", "Honduras", "México", "Nicaragua", "Panamá", "Paraguay", 
    "Perú", "Puerto Rico", "República Dominicana", "Uruguay", "Venezuela"
  ];

  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deptController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE PERSISTENCE ---

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastNameController.text = prefs.getString('last_name') ?? "Dupont";
      _firstNameController.text = prefs.getString('first_name') ?? "Jean";
      _emailController.text = prefs.getString('email') ?? "jean.dupont@email.com";
      _passwordController.text = prefs.getString('password') ?? "password123";
      _deptController.text = prefs.getString('dept') ?? "";
      _addressController.text = prefs.getString('address') ?? "";
      _countryController.text = prefs.getString('country') ?? "";
      
      String? imagePath = prefs.getString('profile_image');
      if (imagePath != null && File(imagePath).existsSync()) {
        _imageFile = File(imagePath);
      }
      _hasChanges = false;
    });
  }

  // --- LOGIQUE DE CONFIRMATION DE SORTIE ---

  Future<bool> _showExitConfirmation() async {
    if (!_hasChanges) return true; 

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cambios sin guardar"),
        content: const Text("¿Estás seguro de que quieres salir? Perderás las modificaciones."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SALIR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // --- LOGIQUE DE LA PHOTO ---

  void _showPickImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                "Photo de profil", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF1B4332)),
              title: const Text("Choisir depuis la galerie"),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1B4332)),
              title: const Text("Prendre une photo"),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            if (_imageFile != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                title: const Text(
                  "Supprimer la photo actuelle", 
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  setState(() {
                    _imageFile = null;
                    _hasChanges = true;
                  });
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source, 
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint("Erreur sélection image: $e");
    }
  }

  // --- LOGIQUE DE SAUVEGARDE ---

  Future<void> _handleUpdate() async {
    FocusScope.of(context).unfocus();

    if (_countryController.text.isNotEmpty && 
        !_paisesOptions.contains(_countryController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, selecciona un país válido de la lista."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_name', _lastNameController.text);
      await prefs.setString('first_name', _firstNameController.text);
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setString('dept', _deptController.text);
      await prefs.setString('address', _addressController.text);
      await prefs.setString('country', _countryController.text);
      
      if (_imageFile != null) {
        await prefs.setString('profile_image', _imageFile!.path);
      } else {
        await prefs.remove('profile_image');
      }

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        HapticFeedback.mediumImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("¡Perfil actualizado con éxito!"),
            backgroundColor: const Color(0xFF1B4332),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: GestureDetector(
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
              onPressed: () async {
                final shouldPop = await _showExitConfirmation();
                if (shouldPop && context.mounted) Navigator.pop(context);
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                onChanged: () => _hasChanges = true,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _showPickImageOptions,
                      child: _buildAvatarSection(forestGreen),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("DATOS OBLIGATORIOS"),
                          _buildInput(
                            icon: Icons.person_outline,
                            hint: "Apellido",
                            controller: _lastNameController,
                            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
                          ),
                          _buildInput(
                            icon: Icons.person_outline,
                            hint: "Nombre",
                            controller: _firstNameController,
                            validator: (v) => v!.isEmpty ? "Campo obligatoire" : null,
                          ),
                          _buildInput(
                            icon: Icons.alternate_email,
                            hint: "Email",
                            controller: _emailController,
                            type: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@')) ? "Email no válido" : null,
                          ),
                          _buildInput(
                            icon: Icons.lock_outline,
                            hint: "Contraseña",
                            controller: _passwordController,
                            isPassword: true,
                            validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                          ),
                          const SizedBox(height: 25),
                          _buildSectionLabel("LOCALIZACIÓN"),
                          _buildInput(
                            icon: Icons.map_outlined, 
                            hint: "Departamento", 
                            controller: _deptController,
                          ),
                          _buildInput(
                            icon: Icons.home_outlined, 
                            hint: "Dirección", 
                            controller: _addressController,
                          ),
                          _buildCountryAutocomplete(forestGreen),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildSaveButton(forestGreen),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

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

  Widget _buildInput({
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13),
            border: InputBorder.none,
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCountryAutocomplete(Color forestGreen) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textValue) {
          if (textValue.text == '') return const Iterable<String>.empty();
          return _paisesOptions.where((String option) =>
              option.toLowerCase().contains(textValue.text.toLowerCase()));
        },
        onSelected: (String selection) {
          _countryController.text = selection;
          _hasChanges = true;
          FocusScope.of(context).unfocus();
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                child: Container(
                  width: MediaQuery.of(context).size.width - 50,
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined, size: 18),
                        title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B4332))),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
          if (_countryController.text.isNotEmpty && fieldController.text.isEmpty) {
            fieldController.text = _countryController.text;
          }
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            leading: Icon(Icons.public_rounded, color: forestGreen.withOpacity(0.6), size: 20),
            title: TextField(
              controller: fieldController,
              focusNode: focusNode,
              onChanged: (value) {
                _countryController.text = value;
                _hasChanges = true;
              },
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                hintText: "País",
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          );
        },
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
              boxShadow: [BoxShadow(color: forestGreen.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
            ),
          ),
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFE8E3D9),
            foregroundImage: (_imageFile != null && _imageFile!.existsSync()) ? FileImage(_imageFile!) : null,
            child: const Icon(Icons.person_rounded, size: 55, color: Color(0xFF1B4332)),
          ),
          Positioned(
            bottom: 5, right: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: forestGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color forestGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: forestGreen, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: _isSaving 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      ),
    );
  }
}