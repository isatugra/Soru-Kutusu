import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soru_kutusu_app/screens/auth/login_screen.dart';
import 'ogrenci_detay_screen.dart'; // Bir sonraki adımda oluşturacağız

class OgretmenHomeScreen extends StatefulWidget {
  const OgretmenHomeScreen({super.key});

  @override
  State<OgretmenHomeScreen> createState() => _OgretmenHomeScreenState();
}

class _OgretmenHomeScreenState extends State<OgretmenHomeScreen> {
  final TextEditingController _aramaController = TextEditingController();
  String _aramaKelimesi = "";

  // Telefon Araması Yapma Fonksiyonu
  Future<void> _aramaYap(String telNo) async {
    final Uri url = Uri.parse('tel:$telNo');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // WhatsApp Mesajı Gönderme Fonksiyonu
  Future<void> _whatsappMesajGonder(String telNo, String ogrenciAdi) async {
    // Türkiye kodu olan +90'ı otomatik ekliyoruz (başında 0 varsa siliyoruz)
    String temizTel = telNo.startsWith('0') ? telNo.substring(1) : telNo;
    String mesaj =
        "Merhaba $ogrenciAdi, Soru Kutusu uygulamasındaki hatalı sorularını inceledim. Eksiklerin üzerine çalışmaya devam edelim! 🚀";
    final Uri url = Uri.parse(
      "https://wa.me/90$temizTel?text=${Uri.encodeComponent(mesaj)}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Öğretmen Yönetim Paneli',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        actions: [
          // Oturumu Kapatma Butonu
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Oturumu Kapat',
            onPressed: () async {
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Üst Canlı Arama Çubuğu
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _aramaController,
              onChanged: (value) {
                setState(() {
                  _aramaKelimesi = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Öğrenci adı ile ara...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                suffixIcon:
                    _aramaController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _aramaController.clear();
                            setState(() => _aramaKelimesi = "");
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Öğrenci Listesi Ekranı
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('ogrenciler')
                      .orderBy('kayitTarihi', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text('Veriler yüklenirken hata oluştu.'),
                  );
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // Eğer arama çubuğuna bir şey yazıldıysa listeyi filtrele
                if (_aramaKelimesi.isNotEmpty) {
                  docs =
                      docs.where((doc) {
                        String adSoyad =
                            (doc['adSoyad'] ?? '').toString().toLowerCase();
                        return adSoyad.contains(_aramaKelimesi);
                      }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aranan kriterlere uygun öğrenci bulunamadı.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var veri = docs[index].data() as Map<String, dynamic>;
                    String adSoyad = veri['adSoyad'] ?? 'İsimsiz Öğrenci';
                    String telefon = veri['telefon'] ?? '';
                    String ogrenciId = veri['id'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          radius: 24,
                          child: Text(
                            adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          adSoyad,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Tel: $telefon',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // WhatsApp Butonu
                            IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.green,
                              ),
                              onPressed:
                                  () => _whatsappMesajGonder(telefon, adSoyad),
                            ),
                            // Doğrudan Arama Butonu
                            IconButton(
                              icon: const Icon(
                                Icons.phone_outlined,
                                color: Colors.blue,
                              ),
                              onPressed: () => _aramaYap(telefon),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () {
                          // Detay sayfasına geçiş yaparken öğrencinin ID ve ismini gönderiyoruz
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => OgrenciDetayScreen(
                                    ogrenciId: ogrenciId,
                                    ogrenciAdi: adSoyad,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
