import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Pour le bouton "Voir l'article complet"
import 'package:intl/intl.dart';                 // Pour formater la date
import 'package:share_plus/share_plus.dart';     // Pour le bouton partager

class ArticleDetailPage extends StatelessWidget {
  final dynamic article;

  const ArticleDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    // Couleur principale de ton application
    const Color forestGreen = Color(0xFF1B4332);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: forestGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Retour à la liste
        ),
        title: Text(
          article['source']['name'] ?? "Noticia",
          style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => Share.share("Mira esta noticia: ${article['title']}\n\n${article['url']}"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE DE L'ARTICLE
            Hero(
              tag: article['url'], // Animation fluide depuis la page précédente
              child: Image.network(
                article['urlToImage'] ?? 'https://via.placeholder.com/400x200',
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITRE
                  Text(
                    article['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Color(0xFF081C15),
                    ),
                  ),
                  
                  const SizedBox(height: 15),

                  // DATE ET SOURCE
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.parse(article['publishedAt'])),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(),
                  ),

                  // DESCRIPTION / CONTENU
                  Text(
                    article['description'] ?? "Sin descripción disponible.",
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // BOUTON POUR VOIR L'ARTICLE ORIGINAL
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: forestGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final Uri url = Uri.parse(article['url']);
                        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No se pudo abrir el enlace")),
                          );
                        }
                      },
                      icon: const Icon(Icons.launch, size: 18),
                      label: const Text(
                        "Leer artículo completo",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}