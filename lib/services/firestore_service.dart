import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // Firestore koleksiyonumuza referans oluşturuyoruz
  final CollectionReference _sorularKoleksiyonu = FirebaseFirestore.instance
      .collection('yanlis_sorular');

  // Yeni bir analiz verisini buluta kaydetme fonksiyonu
  Future<bool> soruKaydet({
    required String dersAdi,
    required String konuAdi,
    required String soruTuru,
    required String zorlukSeviyesi,
    required String yerelFotoYolu,
  }) async {
    try {
      await _sorularKoleksiyonu.add({
        'dersAdi': dersAdi,
        'konuAdi': konuAdi,
        'soruTuru': soruTuru,
        'zorlukSeviyesi': zorlukSeviyesi,
        'yerelFotoYolu':
            yerelFotoYolu, // Fotoğrafın kendisi telefonda, yolu bulutta saklanıyor!
        'eklenmeTarihi':
            FieldValue.serverTimestamp(), // Sunucu saatiyle otomatik tarih
        'ogrenciId':
            'test_ogrenci_123', // İleride Authentication ekleyince burası dinamik olacak
      });
      return true; // Kayıt başarılıysa true döner
    } catch (e) {
      print('Firestore Kayıt Hatası: $e');
      return false; // Hata durumunda false döner
    }
  }
}
