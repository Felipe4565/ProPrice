import 'package:flutter/material.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1B4D3E);
    
    final List<Map<String, String>> news = [
      {"title": "Le blé atteint un nouveau record historique", "date": "IL Y A 2 HEURES", "image": "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&q=80&w=400", "tag": "MARCHÉ"},
      {"title": "Prévisions météo : Sécheresse en approche ?", "date": "IL Y A 5 HEURES", "image": "https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&q=80&w=400", "tag": "MÉTÉO"},
      {"title": "Nouvelles régulations sur l'exportation", "date": "HIER", "image": "https://images.unsplash.com/photo-1530263503756-b389f76e0339?auto=format&fit=crop&q=80&w=400", "tag": "LÉGISLATION"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: news.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 20, top: 10), 
              child: Text("ACTUALITÉS", style: TextStyle(color: darkGreen, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1))
            );
          }
          final item = news[index - 1];
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), 
                child: Image.network(item["image"]!, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, o, s) => Container(height: 150, color: Colors.grey[300], child: const Icon(Icons.broken_image)))
              ),
              Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: darkGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(item["tag"]!, style: const TextStyle(color: darkGreen, fontSize: 10, fontWeight: FontWeight.bold))), 
                  const Spacer(), 
                  Text(item["date"]!, style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 10), 
                Text(item["title"]!, style: const TextStyle(color: darkGreen, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 10), 
                Text("Lire l'article ->", style: TextStyle(color: darkGreen.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold))
              ]))
            ]),
          );
        },
      ),
    );
  }
}