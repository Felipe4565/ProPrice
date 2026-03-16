import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _addressFocusNode = FocusNode();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _hasChanges = false;
  bool _isSelectingAddress = false;
  
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

  // --- LOGIQUE DE PERSISTENCE ---

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastNameController.text = prefs.getString('last_name') ?? "Dupont";
      _firstNameController.text = prefs.getString('first_name') ?? "Jean";
      _emailController.text = prefs.getString('email') ?? "jean.dupont@email.com";
      _passwordController.text = prefs.getString('password') ?? "password123";
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

  // --- APPEL API ADRESSE ---

Future<List<String>> _searchAddress(String query) async {
  if (query.length < 3) return [];
  
  final url = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
  
  try {
    // AJOUT DES HEADERS POUR ÉVITER LE 403
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'ProPriceApp/1.0 (contact@votre-email.com)', // Change l'email si tu veux
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 5));
    
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
        String country = p['country']?.toString() ?? "";
        
        List<String> parts = [];
        if (street.isNotEmpty) {
          String house = p['housenumber']?.toString() ?? "";
          parts.add(house.isNotEmpty ? "$street $house" : street);
        } else if (name.isNotEmpty) {
          parts.add(name);
        }
        
        if (city.isNotEmpty) parts.add(city);
        if (country.isNotEmpty) parts.add(country);

        String finalString = parts.join(", ");
        if (finalString.isNotEmpty) results.add(finalString);
      }
      return results;
    } else {
      // Si on a encore une erreur, on l'affiche pour savoir
      debugPrint("ERREUR API ${response.statusCode}: ${response.body}");
    }
  } catch (e) {
    debugPrint("ERREUR RÉSEAU: $e");
  }
  return [];
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
                onChanged: () {
                  if (!_hasChanges) {
                    // On attend la fin de la construction de la frame actuelle
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
                            hint: "Contraseña",
                            controller: _passwordController,
                            isPassword: true,
                            validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                          ),
                          const SizedBox(height: 25),
                          _buildSectionLabel("LOCALIZACIÓN"),
                          _buildAddressAutocomplete(forestGreen),
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
          color: const Color(0xFF1B4332).withValues(alpha: 0.4), 
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: Icon(icon, color: const Color(0xFF1B4332).withValues(alpha: 0.6), size: 20),
        title: TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: type,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4), fontSize: 13),
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

Widget _buildAddressAutocomplete(Color forestGreen) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
        )
      ],
    ),
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
          leading: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF1B4332)),
          title: Text(suggestion, style: const TextStyle(fontSize: 13)),
        );
      },

      onSelected: (suggestion) {
        setState(() {
          _isSelectingAddress = true;
          _addressController.text = suggestion;
          _hasChanges = true;

          // --- LOGIQUE DE TRADUCTION ET CORRESPONDANCE ---
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
      }, // Fin de onSelected (une seule fois !)

      builder: (context, controller, focusNode) {
        // Synchronisation du controller
        if (controller.text != _addressController.text) {
          Future.microtask(() {
            controller.text = _addressController.text;
          });
        }

        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Dirección",
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4), fontSize: 13),
            icon: Icon(Icons.home_outlined, color: forestGreen.withValues(alpha: 0.6), size: 20),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (_isSelectingAddress) _isSelectingAddress = false;
            _addressController.text = value;
            // _hasChanges est géré par le Form.onChanged
          },
        );
      },
    ),
  );
}

 Widget _buildCountryAutocomplete(Color forestGreen) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
        )
      ],
    ),
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
  // On synchronise dès que les textes sont différents (même si pas vide)
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: "País",
            hintStyle: TextStyle(
              color: Colors.grey.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            icon: Icon(
              Icons.public_rounded,
              color: forestGreen.withValues(alpha: 0.6),
              size: 20,
            ),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            _countryController.text = value;
            // Pas de setState ici, le onChanged du Form parent gère le _hasChanges
          },
        );
      },
    ),
  );
}

  Widget _buildOptionsDropdown(BuildContext context, Function(String) onSelected, Iterable<String> options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
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
                leading: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF1B4332)),
                title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B4332))),
                onTap: () => onSelected(option),
              );
            },
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
              boxShadow: [BoxShadow(color: forestGreen.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)],
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