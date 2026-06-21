import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_data_provider.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  final Color forestGreen = const Color(0xFF1B4332);
  final Color backgroundCream = const Color(0xFFF2EFE9);

  @override
  Widget build(BuildContext context) {
    // On récupère le provider pour écouter les changements de favoris
    final provider = context.watch<UserDataProvider>();
    
    // On filtre les données pour ne garder que les favoris
    final favoriteGrains = provider.grainsData
        .where((g) => provider.isFavorite(g["name"]))
        .toList();

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: backgroundCream,
        elevation: 0,
        title: Text("Mi Perfil", style: TextStyle(color: forestGreen, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: forestGreen),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER & STATUT ---
            Center(
              child: Column(
                children: [
                  const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                  const SizedBox(height: 10),
                  const Text("Juan Pérez", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text("Agricultor Pro", style: TextStyle(color: forestGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- ACTIONS RAPIDES ---
            Row(
              children: [
                Expanded(child: _buildActionButton("Añadir Cultivo", Icons.add_circle_outline, Colors.blueGrey)),
                const SizedBox(width: 10),
                Expanded(child: _buildActionButton("Nueva Alerta", Icons.notification_add_outlined, Colors.orange)),
              ],
            ),
            const SizedBox(height: 30),

            // --- LISTE DES FAVORIS DYNAMIQUE ---
            _buildSectionTitle("CULTIVOS FAVORITOS"),
            if (favoriteGrains.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("No tienes cultivos favoritos aún.", style: TextStyle(fontStyle: FontStyle.italic)),
              )
            else
              ...favoriteGrains.map((item) => _buildListTile(
                item["name"], 
                "${item["price"]} USD", 
                Icons.grass
              )),

            // --- RESTE DES SECTIONS ---
            _buildSectionTitle("MIS ALERTAS"),
            _buildListTile("Precio Soja < 500", "Activa", Icons.notifications_active),

            _buildSectionTitle("ÚLTIMOS ARTÍCULOS"),
            _buildListTile("Tendencias 2026", "Leer ahora", Icons.article),
            
            _buildSectionTitle("HISTORIAL DE ALERTAS"),
            _buildListTile("Maíz subió 2%", "Hace 2h", Icons.history),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AIDES ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      child: Text(
        title, 
        style: TextStyle(
          color: forestGreen.withValues(alpha: 0.5), 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.2, 
          fontSize: 12
        )
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: forestGreen),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}