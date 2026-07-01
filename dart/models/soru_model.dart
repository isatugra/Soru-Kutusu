class SoruModel {
  final String id;
  final String fotografYolu; // Telefon hafizasindaki dosya konumu
  final String dersAdi;
  final String konuAdi;
  final String soruTuru; // Örn: Çoktan Seçmeli, Klasik, Öncüllü
  final String zorlukSeviyesi; // Örn: Kolay, Orta, Zor
  final DateTime eklenmeTarihi;

  SoruModel({
    required this.id,
    required this.fotografYolu,
    required this.dersAdi,
    required this.konuAdi,
    required this.soruTuru,
    required this.zorlukSeviyesi,
    required this.eklenmeTarihi,
  });

  // Yapay zekadan gelecek olan JSON formatındaki veriyi nesneye dönüştürmek için yardımcı fonksiyon
  factory SoruModel.fromJson(Map<String, dynamic> json, String fotopath) {
    return SoruModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fotografYolu: fotopath,
      dersAdi: json['dersAdi'] ?? 'Belirsiz',
      konuAdi: json['konuAdi'] ?? 'Belirsiz',
      soruTuru: json['soruTuru'] ?? 'Belirsiz',
      zorlukSeviyesi: json['zorlukSeviyesi'] ?? 'Orta',
      eklenmeTarihi: DateTime.now(),
    );
  }
}
