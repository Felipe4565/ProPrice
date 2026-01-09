import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';

class ArticleDetailPage extends StatelessWidget {
  final dynamic article;

  const ArticleDetailPage({super.key, required this.article});

  // 1. Calcul dynamique du temps de lecture
  String _calculateReadingTime(String? text) {
    if (text == null || text.isEmpty) return "1 min lectura";
    int words = text.split(' ').length;
    int time = (words / 200).ceil();
    return "$time min lectura";
  }

  // 2. Nettoyage du texte NewsAPI (enlève le "[+1234 chars]")
  String _cleanDescription(String? text) {
    if (text == null) return "Sin descripción disponible.";
    return text.replaceAll(RegExp(r'\[\+\d+ chars\]'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs thématiques
    const Color forestGreen = Color(0xFF1B4332);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Formatage sécurisé de la date
    String formattedDate = "Reciente";
    try {
      if (article['publishedAt'] != null) {
        formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(article['publishedAt']));
      }
    } catch (e) {
      formattedDate = "Reciente";
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF081C15) : Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HEADER : IMAGE AVEC EFFET SLIVER & STRETCH
          SliverAppBar(
            expandedHeight: 380.0,
            pinned: true,
            stretch: true,
            backgroundColor: forestGreen,
            elevation: 0,
            leading: _buildFloatingButton(
              context: context,
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.pop(context),
            ),
            actions: [
              _buildFloatingButton(
                context: context,
                icon: Icons.share_outlined,
                onTap: () => Share.share("Mira esta noticia: ${article['title']}\n\n${article['url']}"),
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              centerTitle: true,
              title: Text(
                article['source']?['name'] ?? "Noticia",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: article['url'] ?? 'news_image',
                    child: Image.network(
                      article['urlToImage'] ?? 'https://via.placeholder.com/800x600',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(color: Colors.grey[300]),
                    ),
                  ),
                  // Dégradé pour la lisibilité du titre dans l'AppBar
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CORPS DE L'ARTICLE
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne d'infos : Badge et Temps de lecture
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: forestGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (article['source']?['name'] ?? "NEWS").toUpperCase(),
                          style: const TextStyle(
                            color: forestGreen, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 11
                          ),
                        ),
                      ),
                      Text(
                        _calculateReadingTime(article['description']),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600], 
                          fontSize: 12, 
                          fontStyle: FontStyle.italic
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // TITRE PRINCIPAL
                  Text(
                    article['title'] ?? 'Sin título',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF081C15),
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // DATE
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600], 
                      fontSize: 13
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 25),
                    child: Divider(thickness: 0.7),
                  ),

                  // DESCRIPTION / CONTENU
                  Text(
                    _cleanDescription(article['description']),
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.8,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                      fontFamily: 'Georgia', // Optionnel, donne un style journal
                    ),
                  ),

                  const SizedBox(height: 45),

                  // BOUTON D'ACTION FINAL (CTA)
                  _buildCallToAction(forestGreen, article['url'] ?? ""),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget des boutons de l'AppBar (Glassmorphism)
  Widget _buildFloatingButton({
    required BuildContext context, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.white.withOpacity(0.25),
            child: IconButton(
              icon: Icon(icon, color: Colors.white, size: 20),
              onPressed: onTap,
            ),
          ),
        ),
      ),
    );
  }

  // Widget du bouton "Leer más" stylisé
  Widget _buildCallToAction(Color color, String url) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            if (url.isNotEmpty) {
              final Uri uri = Uri.parse(url);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                // Optionnel : Ajouter un SnackBar en cas d'erreur
              }
            }
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "CONTINUAR LEYENDO",
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.5,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}