import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalizScreen extends StatelessWidget {
  const AnalizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Performans Analizi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Canlı akışla tüm yanlış soruları çekip analiz ediyoruz
        stream:
            FirebaseFirestore.instance.collection('yanlis_sorular').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Henüz analiz edilecek soru bulunmuyor.\nSoru ekledikçe burası canlanacak! 🚀',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            );
          }

          // Verileri Derslere Göre Gruplama Sözlüğü
          Map<String, int> dersSayilari = {};
          // En çok yanlış yapılan konuları takip etmek için
          Map<String, int> konuSayilari = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String ders = data['dersAdi'] ?? 'Diğer';
            final String konu = data['konuAdi'] ?? 'Belirtilmemiş';

            dersSayilari[ders] = (dersSayilari[ders] ?? 0) + 1;

            String benzersizKonu = '$ders - $konu';
            konuSayilari[benzersizKonu] =
                (konuSayilari[benzersizKonu] ?? 0) + 1;
          }

          // En çok yanlış yapılan konuları sıralayalım
          var siraliKonular =
              konuSayilari.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Özet Kartları Row'u
                Row(
                  children: [
                    _buildOzetKart(
                      'Toplam Yanlış',
                      '${docs.length}',
                      Colors.redAccent,
                      Icons.analytics,
                    ),
                    const SizedBox(width: 12),
                    _buildOzetKart(
                      'Odaklanılan Ders',
                      '${dersSayilari.keys.length}',
                      Colors.blueAccent,
                      Icons.menu_book,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Pasta Grafik Kartı
                const Text(
                  'Derslere Göre Hata Dağılımı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Grafik alanı
                      Expanded(
                        flex: 4,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _buildPieSections(dersSayilari),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Grafik Yanı Renk Göstergeleri
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildGrafikGostergeleri(dersSayilari),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Kritik Alarm Veren Konular Listesi
                const Text(
                  '🚨 En Çok Yanlış Yapılan Konular',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      siraliKonular.length > 5
                          ? 5
                          : siraliKonular.length, // İlk 5 konuyu göster
                  itemBuilder: (context, index) {
                    final eklenti = siraliKonular[index];
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[50],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          eklenti.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${eklenti.value} Yanlış',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- YARDIMCI WIDGET VE METODLAR ---

  Widget _buildOzetKart(
    String baslik,
    String deger,
    Color renk,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: renk.withOpacity(0.1),
              child: Icon(icon, color: renk, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deger,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Grafik Dilimlerini Oluşturur
  List<PieChartSectionData> _buildPieSections(Map<String, int> dersSayilari) {
    final renkler = [
      Colors.deepPurple,
      Colors.orange,
      Colors.cyan,
      Colors.redAccent,
      Colors.green,
      Colors.indigo,
    ];
    int i = 0;

    return dersSayilari.entries.map((entry) {
      final color = renkler[i % renkler.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 45,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  // Grafik Yanındaki Renk Açıklamalarını Oluşturur
  List<Widget> _buildGrafikGostergeleri(Map<String, int> dersSayilari) {
    final renkler = [
      Colors.deepPurple,
      Colors.orange,
      Colors.cyan,
      Colors.redAccent,
      Colors.green,
      Colors.indigo,
    ];
    int i = 0;

    return dersSayilari.entries.map((entry) {
      final color = renkler[i % renkler.length];
      i++;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
