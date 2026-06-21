import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLanguage = 'es'; // Langue par défaut

  final List<Map<String, String>> _languages = [
    {'name': 'Español', 'code': 'es'},
    {'name': 'Français', 'code': 'fr'},
    {'name': 'English', 'code': 'en'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  // Charger la langue sauvegardée
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language_code') ?? 'es';
    });
  }

  // Sauvegarder la langue choisie
  Future<void> _changeLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    setState(() {
      _selectedLanguage = code;
    });
    // Ici, tu pourrais appeler ton gestionnaire de traduction (ex: EasyLocalization)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
        title: const Text("Idioma", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // --- AJOUT : Illustration/Icône ---
            const Icon(Icons.language, size: 80, color: Color(0xFF1B4332)),
            const SizedBox(height: 20),
            const Text(
              "Selecciona tu idioma",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B4332)),
            ),
            const SizedBox(height: 10),
            Text(
              "Elige el idioma que prefieras para la interfaz de ProPrice.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            
            // --- Ta liste ---
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: RadioListTile<String>(
                      value: lang['code']!,
                      groupValue: _selectedLanguage,
                      activeColor: const Color(0xFF1B4332),
                      title: Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onChanged: (value) => _changeLanguage(value!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}