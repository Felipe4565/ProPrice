import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_skeleton.dart';
import '../../theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _addressFocusNode = FocusNode();
  final supabase = Supabase.instance.client;

  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _obscurePassword = true;
  bool _hasChanges = false;
  bool _isSelectingAddress = false;

  File? _imageFile;
  String? _avatarUrl;
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
    _addressController.dispose();
    _countryController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE PERSISTENCE (Supabase) ---

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    _emailController.text = user.email ?? "";

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _lastNameController.text = data['last_name'] ?? "";
        _firstNameController.text = data['first_name'] ?? "";
        _addressController.text = data['address'] ?? "";
        _countryController.text = data['country'] ?? "";
        _avatarUrl = data['avatar_url'];
      }
    } catch (e) {
      debugPrint("Erreur chargement profil: $e");
    }

    if (mounted) {
      setState(() {
        _hasChanges = false;
        _isLoadingProfile = false;
      });
    }
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
            child: const Text("SALIR", style: TextStyle(color: AppColors.danger)),
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
      backgroundColor: AppColors.surface,
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
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.forest500),
              title: const Text("Choisir depuis la galerie"),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.forest500),
              title: const Text("Prendre une photo"),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            if (_imageFile != null || _avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
                title: const Text(
                  "Supprimer la photo actuelle",
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  setState(() {
                    _imageFile = null;
                    _avatarUrl = null;
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

  // --- APPEL API ADRESSE ---

  Future<List<String>> _searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) return [];

    final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}'
            '&limit=15'
            '&lang=en'
            '&lat=-34.85&lon=-56.17'
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ProPriceApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'] ?? [];

        List<String> results = [];
        for (var f in features) {
          final p = f['properties'];
          if (p == null) continue;

          String name = p['name']?.toString() ?? "";
          String street = p['street']?.toString() ?? "";
          String city = p['city']?.toString() ?? p['state']?.toString() ?? "";
          String house = p['housenumber']?.toString() ?? "";
          String country = p['country']?.toString() ?? "";

          List<String> parts = [];

          if (name.isNotEmpty) parts.add(name);

          if (street.isNotEmpty && street.toLowerCase() != name.toLowerCase()) {
            parts.add(house.isNotEmpty ? "$street $house" : street);
          }

          if (city.isNotEmpty) parts.add(city);
          if (country.isNotEmpty) parts.add(country);

          String finalString = parts.join(", ");
          if (finalString.isNotEmpty) {
            results.add(finalString);
          }
        }
        return results;
      } else {
        debugPrint("ERREUR API: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ERREUR RÉSEAU: $e");
    }

    return [];
  }

  // --- LOGIQUE DE SAUVEGARDE (Supabase) ---

  Future<void> _handleUpdate() async {
    FocusScope.of(context).unfocus();

    if (_countryController.text.isNotEmpty &&
        !_paisesOptions.contains(_countryController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, selecciona un país válido de la lista."),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Upload de la nouvelle photo si elle a changé
      String? avatarUrl = _avatarUrl;
      if (_imageFile != null) {
        // Supprime les anciens fichiers du dossier de l'utilisateur,
        // peu importe leur extension, pour éviter d'accumuler des fichiers
        // orphelins si le format change entre deux photos (ex: jpg -> png).
        try {
          final existingFiles = await supabase.storage.from('avatars').list(path: user.id);
          if (existingFiles.isNotEmpty) {
            final pathsToDelete = existingFiles.map((f) => '${user.id}/${f.name}').toList();
            await supabase.storage.from('avatars').remove(pathsToDelete);
          }
        } catch (e) {
          debugPrint("Impossible de nettoyer les anciennes photos: $e");
        }

        final fileExt = _imageFile!.path.split('.').last;
        final filePath = '${user.id}/avatar.$fileExt';

        await supabase.storage.from('avatars').upload(
          filePath,
          _imageFile!,
          fileOptions: const FileOptions(upsert: true),
        );

        avatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
        // Casse le cache pour que l'image se rafraîchisse bien à l'affichage
        avatarUrl = '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // 2. Sauvegarde des infos de profil dans la table
      await supabase.from('profiles').upsert({
        'id': user.id,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'address': _addressController.text,
        'country': _countryController.text,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Changement d'email si modifié (envoie un email de confirmation)
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await supabase.auth.updateUser(
          UserAttributes(email: newEmail),
          emailRedirectTo: 'proprice://login-callback',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Revisa tu bandeja de entrada para confirmar el nuevo email."),
              backgroundColor: AppColors.forest500,
            ),
          );
        }
      }

      // 4. Changement de mot de passe si un nouveau a été saisi
      if (_passwordController.text.isNotEmpty) {
        await supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
          _avatarUrl = avatarUrl;
          _imageFile = null;
        });
        _passwordController.clear();
        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("¡Perfil actualizado con éxito!"),
            backgroundColor: AppColors.forest500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  /// Skeleton affiché tant que le profil n'a pas fini de charger, dans la
  /// même mise en page que le formulaire réel (AppBar + avatar rond +
  /// champs), pour éviter le "saut" visuel à l'arrivée des données.
  Widget _buildProfileSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "MI PERFIL",
          style: TextStyle(
            color: AppColors.forest500,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.forest500, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Center(child: AppSkeleton.circle(size: 120)),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(height: 10, width: 150),
                    SizedBox(height: 10),
                    AppSkeleton(height: 54, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(18))),
                    SizedBox(height: 10),
                    AppSkeleton(height: 54, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(18))),
                    SizedBox(height: 10),
                    AppSkeleton(height: 54, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(18))),
                    SizedBox(height: 25),
                    AppSkeleton(height: 10, width: 130),
                    SizedBox(height: 10),
                    AppSkeleton(height: 54, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(18))),
                    SizedBox(height: 10),
                    AppSkeleton(height: 54, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(18))),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: AppSkeleton(height: 60, width: double.infinity, borderRadius: BorderRadius.circular(18)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return _buildProfileSkeleton();
    }

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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: const Text(
              "MI PERFIL",
              style: TextStyle(
                color: AppColors.forest500,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2.5,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.forest500, size: 18),
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
                onChanged: () {
                  if (!_hasChanges) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _hasChanges = true);
                      }
                    });
                  }
                },
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _showPickImageOptions,
                      child: _buildAvatarSection(),
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
                            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
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
                            hint: "Nueva contraseña (opcional)",
                            controller: _passwordController,
                            isPassword: true,
                            validator: (v) => (v != null && v.isNotEmpty && v.length < 6)
                                ? "Mínimo 6 caracteres"
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, top: 4),
                            child: Text(
                              "Déjalo en blanco si no quieres cambiar la contraseña.",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.forest500.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          _buildSectionLabel("LOCALIZACIÓN"),
                          _buildAddressAutocomplete(),
                          _buildCountryAutocomplete(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildSaveButton(),
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
  // Depuis le passage à AppTheme (transparent par défaut), ces widgets
  // n'ont plus besoin qu'on leur passe une couleur en paramètre : ils
  // utilisent directement AppColors.forest500, comme _buildSectionLabel
  // et _buildInput le faisaient déjà.

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.forest500.withValues(alpha: 0.4),
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: AppTheme.softShadow().map((s) => s.scale(0.3)).toList(),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.forest500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.forest500, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: isPassword ? _obscurePassword : false,
              keyboardType: type,
              validator: validator,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.forest500.withValues(alpha: 0.35), fontSize: 14),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                suffixIcon: isPassword
                    ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.forest500.withValues(alpha: 0.5),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressAutocomplete() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: AppTheme.softShadow().map((s) => s.scale(0.3)).toList(),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.forest500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_outlined, color: AppColors.forest500, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TypeAheadField<String>(
              hideOnSelect: true,
              hideOnEmpty: true,
              debounceDuration: const Duration(milliseconds: 300),

              suggestionsCallback: (pattern) async {
                if (pattern.length < 3 || _isSelectingAddress) return null;
                return await _searchAddress(pattern);
              },

              itemBuilder: (context, suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.forest500),
                  title: Text(suggestion, style: const TextStyle(fontSize: 13)),
                );
              },

              onSelected: (suggestion) {
                setState(() {
                  _isSelectingAddress = true;
                  _addressController.text = suggestion;
                  _hasChanges = true;

                  List<String> parts = suggestion.split(',');
                  if (parts.length > 1) {
                    String rawCountry = parts.last.trim();

                    Map<String, String> translationMap = {
                      "Argentina": "Argentina",
                      "Bolivia": "Bolivia",
                      "Brazil": "Brasil",
                      "Chile": "Chile",
                      "Colombia": "Colombia",
                      "Ecuador": "Ecuador",
                      "Guyana": "Guyana",
                      "Paraguay": "Paraguay",
                      "Peru": "Perú",
                      "Suriname": "Suriname",
                      "Uruguay": "Uruguay",
                      "Venezuela": "Venezuela",
                      "French Guiana": "Francia",
                      "Costa Rica": "Costa Rica",
                      "Cuba": "Cuba",
                      "El Salvador": "El Salvador",
                      "Guatemala": "Guatemala",
                      "Honduras": "Honduras",
                      "Nicaragua": "Nicaragua",
                      "Panama": "Panamá",
                      "Puerto Rico": "Puerto Rico",
                      "Dominican Republic": "República Dominicana",
                      "United States": "Estados Unidos",
                      "USA": "Estados Unidos",
                      "United Kingdom": "Reino Unido",
                      "UK": "Reino Unido",
                      "France": "Francia",
                      "Germany": "Alemania",
                      "Italy": "Italia",
                      "Spain": "España",
                      "China": "China",
                      "Japan": "Japón",
                      "Russia": "Rusia",
                      "Canada": "Canadá",
                      "Mexico": "México",
                    };

                    String countryToLookFor = translationMap[rawCountry] ?? rawCountry;

                    if (_paisesOptions.any((p) => p.toLowerCase() == countryToLookFor.toLowerCase())) {
                      _countryController.text = _paisesOptions.firstWhere(
                              (p) => p.toLowerCase() == countryToLookFor.toLowerCase()
                      );
                    }
                  }
                });

                FocusManager.instance.primaryFocus?.unfocus();

                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() => _isSelectingAddress = false);
                  }
                });
              },

              builder: (context, controller, focusNode) {
                if (controller.text != _addressController.text) {
                  Future.microtask(() {
                    controller.text = _addressController.text;
                  });
                }

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Dirección",
                    hintStyle: TextStyle(color: AppColors.forest500.withValues(alpha: 0.35), fontSize: 14),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) {
                    if (_isSelectingAddress) _isSelectingAddress = false;
                    _addressController.text = value;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryAutocomplete() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: AppTheme.softShadow().map((s) => s.scale(0.3)).toList(),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.forest500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.public_rounded, color: AppColors.forest500, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textValue) {
                if (textValue.text == '') return const Iterable<String>.empty();
                return _paisesOptions.where((String option) =>
                    option.toLowerCase().contains(textValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                setState(() {
                  _countryController.text = selection;
                  _hasChanges = true;
                });
                FocusScope.of(context).unfocus();
              },
              optionsViewBuilder: (context, onSelected, options) {
                return _buildOptionsDropdown(context, onSelected, options);
              },
              fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                if (fieldController.text != _countryController.text) {
                  Future.microtask(() {
                    if (context.mounted) {
                      fieldController.text = _countryController.text;
                    }
                  });
                }

                return TextFormField(
                  controller: fieldController,
                  focusNode: focusNode,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "País",
                    hintStyle: TextStyle(color: AppColors.forest500.withValues(alpha: 0.35), fontSize: 14),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) {
                    _countryController.text = value;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsDropdown(BuildContext context, Function(String) onSelected, Iterable<String> options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surface,
        child: Container(
          width: MediaQuery.of(context).size.width - 50,
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.withValues(alpha: 0.1), height: 1),
            itemBuilder: (BuildContext context, int index) {
              final String option = options.elementAt(index);
              return ListTile(
                leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.forest500),
                title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.forest500)),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    ImageProvider? imageProvider;
    if (_imageFile != null && _imageFile!.existsSync()) {
      imageProvider = FileImage(_imageFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_avatarUrl!);
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.surface,
              boxShadow: [BoxShadow(color: AppColors.forest500.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)],
            ),
          ),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.neutral200,
            foregroundImage: imageProvider,
            child: const Icon(Icons.person_rounded, size: 55, color: AppColors.forest500),
          ),
          Positioned(
            bottom: 5, right: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.forest500, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2.5)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forest500,
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