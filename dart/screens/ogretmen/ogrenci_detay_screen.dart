import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OgrenciDetayScreen extends StatefulWidget {
  final String ogrenciId;
  final String ogrenciAdi;

  const OgrenciDetayScreen({
    super.key,
    required this.ogrenciId,
    required this.ogrenciAdi,
  });

  @override
  State<OgrenciDetayScreen> createState() => _OgrenciDetayScreenState();
}

class _OgrenciDetayScreenState extends State<OgrenciDetayScreen> {
  final TextEditingController _bildirimController = TextEditingController();
  bool _bildirimGonderiliyor = false;

  // Öğrenciye anlık Firestore üzerinden bildirim/not gönderme fonksiyonu
  Future<void> _ogretmenNotuGonder() async {
    if (_bildirimController.text.trim().isEmpty) return;

    setState(() => _bildirimGonderiliyor = true);

    try {
      // Öğrencinin dokümanına 'ogretmenNotu' adında bir alan ekliyoruz veya güncelliyoruz
      await FirebaseFirestore.instance
          .collection('ogrenciler')
          .doc(widget.ogrenciId)
          .update({
            'ogretmenNotu': _bildirimController.text.trim(),
            'notTarihi': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      _bildirimController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim öğrenciye başarıyla iletildi! 🚀'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Not gönderilemedi: $e')));
    } finally {
      if (mounted) setState(() => _bildirimGonderiliyor = false);
    }
  }

  @override
  void dispose() {
    _bildirimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${widget.ogrenciAdi} - Gelişim Paneli'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Doğru veri yoluna bağladık: 'yanlis_sorular' koleksiyonundan bu öğrencinin soruları filtreliyoruz
        stream:
            FirebaseFirestore.instance
                .collection('yanlis_sorular')
                .where('ogrenciId', isEqualTo: widget.ogrenciId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Sorular yüklenirken hata oluştu.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }

          var sorular = snapshot.data?.docs ?? [];

          // İstatistikleri Hesaplama
          int toplamSoru = sorular.length;
          int cozuldenSoru =
              sorular
                  .where(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['cozulduMu'] ==
                        true,
                  )
                  .length;
          int cozulmeyenSoru = toplamSoru - cozuldenSoru;

          return CustomScrollView(
            slivers: [
              // 1. BÖLÜM: SaaS Tablo & Özet Grafik Kartları
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Öğrenci Durum Özeti',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCard(
                            'Toplam Soru',
                            toplamSoru.toString(),
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Çözülen',
                            cozuldenSoru.toString(),
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Bekleyen',
                            cozulmeyenSoru.toString(),
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. BÖLÜM: Öğrenciye Anlık Bildirim / Not Gönderme Alanı
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📣 Öğrenciye Bildirim / Çalışma Notu Gönder',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _bildirimController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText:
                                    'Örn: Matematik türev sorularına tekrar göz at...',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _bildirimGonderiliyor
                              ? const CircularProgressIndicator(
                                color: Colors.deepPurple,
                              )
                              : ElevatedButton(
                                onPressed: _ogretmenNotuGonder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Icon(Icons.send_rounded, size: 20),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
                  child: Text(
                    '📚 Hatalı Soru Havuzu ($toplamSoru)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              // 3. BÖLÜM: Soruların Listelenmesi
              sorular.isEmpty
                  ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bu öğrenciye ait hatalı soru bulunamadı! 🎉',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      var soruDoc = sorular[index];
                      var soru = soruDoc.data() as Map<String, dynamic>;

                      String ders = soru['ders'] ?? 'Genel';
                      String konu = soru['konu'] ?? 'Belirtilmemiş';
                      String analiz =
                          soru['yapayZekaAnalizi'] ??
                          soru['analiz'] ??
                          'Analiz hazırlanıyor...';
                      String fotoUrl =
                          soru['fotoUrl'] ?? soru['imageUrl'] ?? '';
                      bool cozulduMu = soru['cozulduMu'] ?? false;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fotoUrl.isNotEmpty)
                                Image.network(
                                  fotoUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Chip(
                                          label: Text(ders),
                                          backgroundColor: Colors.deepPurple
                                              .withOpacity(0.1),
                                          labelStyle: const TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: Text(
                                            cozulduMu ? "Çözüldü" : "Çözülmedi",
                                          ),
                                          selected: cozulduMu,
                                          selectedColor: Colors.green
                                              .withOpacity(0.2),
                                          onSelected: (bool selected) {
                                            // Doğrudan yanlis_sorular dökümanını güncelliyoruz
                                            soruDoc.reference.update({
                                              'cozulduMu': selected,
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Konu: $konu',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '🤖 Yapay Zeka Analizi:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      analiz,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: sorular.length),
                  ),
            ],
          );
        },
      ),
    );
  }

  // İstatistik Kartlarını Oluşturan Yardımcı Tasarım Fonksiyonu
  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
