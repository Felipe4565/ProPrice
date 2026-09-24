import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/user_data_provider.dart';
import 'article_detail_page.dart';
import 'subscription_plan_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  final Color forestGreen = const Color(0xFF1B4332);
  final Color backgroundCream = const Color(0xFFF2EFE9);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserDataProvider>();

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: backgroundCream,
        body: Center(child: CircularProgressIndicator(color: forestGreen)),
      );
    }

    final favoriteGrains = provider.grainsData
        .where((g) => provider.isFavorite(g["name"]))
        .toList();

    final lastArticle = provider.lastArticle;
    final alerts = provider.alerts;
    final avatarUrl = provider.avatarUrl;

    return Scaffold(
      backgroundColor: backgroundCream,
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        color: forestGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // --- HEADER & STATUT (dynamique via le provider) ---
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(provider.fullName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: provider.isPremium
                            ? forestGreen.withValues(alpha: 0.1)
                            : Colors.blueGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        provider.tierLabel,
                        style: TextStyle(
                          color: provider.isPremium ? forestGreen : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- ACTIONS RAPIDES ---
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      "Mi Plan",
                      Icons.workspace_premium_outlined,
                      forestGreen,
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SubscriptionPlanPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionButton("Nueva Alerta", Icons.notification_add_outlined, Colors.orange, () {})),
                ],
              ),
              const SizedBox(height: 30),

              // --- CULTIVOS FAVORITOS (table "favorites" via provider) ---
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
                  Icons.grass,
                )),

              // --- DERNIER ARTICLE (table "reading_history" via provider) ---
              _buildSectionTitle("ÚLTIMO ARTÍCULO LEÍDO"),
              lastArticle == null
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("Ningún artículo leído todavía."),
              )
                  : _buildListTile(
                lastArticle['title'] ?? "Sin título",
                "Toca para volver a leer",
                Icons.article,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleDetailPage(article: lastArticle),
                    ),
                  );
                },
              ),

              // --- MIS ALERTAS (table "alerts" via provider) ---
              _buildSectionTitle("MIS ALERTAS"),
              if (alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("No tienes alertas activas.", style: TextStyle(fontStyle: FontStyle.italic)),
                )
              else
                ...alerts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final alert = entry.value;
                  return _buildListTile(
                    "${alert['commodity'].toString().toUpperCase()} > ${alert['price']} \$",
                    (alert['status'] ?? '').toString(),
                    Icons.notifications_active,
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.removeAlert(index);
                      },
                    ),
                  );
                }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: forestGreen.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
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

  Widget _buildListTile(String title, String subtitle, IconData icon,
      {VoidCallback? onTap, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: forestGreen),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}