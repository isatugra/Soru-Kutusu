import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ⚠️ Google AI Studio'dan aldığın API anahtarını buraya yapıştır:
  final String _apiKey =
      "AQ.Ab8RN6K93Kj0A14vjSDZKw6C4ZQ4QMP6RGw8rXMCDxkh2jwGsw";

  Future<Map<String, dynamic>?> soruAnalizEt(File soruFotosu) async {
    try {
      // 1. Kullanacağımız modeli seçiyoruz (Hem yazı hem görsel okuyabilen flash modeli)
      final model = GenerativeModel(
        model:
            'gemini-2.5-flash', // En güncel ve kararlı Gemini 2.5 modeline geçiş yaptık
        apiKey: _apiKey,
      );

      // 2. Fotoğrafı yapay zekanın anlayacağı byte formatına dönüştürüyoruz
      final imageBytes = await soruFotosu.readAsBytes();
      final promptPart = DataPart('image/jpeg', imageBytes);

      // 3. Yapay zekaya ne yapacağını nokta atışı söylediğimiz "Prompt" alanı
      final textPart = TextPart('''
        Sana bir YKS (Yükseköğretim Kurumları Sınavı) soru fotoğrafı gönderiyorum.
        Lütfen bu soruyu incele ve analiz et. Cevabı SADECE ama SADECE aşağıdaki JSON formatında ver. 
        Asla JSON dışı açıklama yazısı ekleme. Türkçe karakter kurallarına uygun olsun.

        {
          "dersAdi": "Sorunun ait olduğu ana ders (Örn: Matematik, Fizik, Kimya, Biyoloji)",
          "konuAdi": "Sorunun tam YKS konu başlığı (Örn: Türev, Optik, Mol Kavramı, Hücre Bölünmesi)",
          "soruTuru": "Sorunun tipi (Örn: Çoktan Seçmeli, Öncüllü Soru, Grafik Okuma, Şekilli Soru)",
          "zorlukSeviyesi": "Sorunun tahmini zorluğu (Kolay, Orta, Zor)"
        }
      ''');

      // 4. İsteği Gemini'a gönderiyoruz
      final response = await model.generateContent([
        Content.multi([promptPart, textPart]),
      ]);

      // 5. Gelen cevabı temizleyip haritalandırıyoruz (JSON parse)
      if (response.text != null) {
        String temizCevap = response.text!.trim();

        // Yapay zeka bazen ```json ... ``` şeklinde bloklar ekleyebilir, onları temizliyoruz
        if (temizCevap.startsWith("```")) {
          temizCevap =
              temizCevap.replaceAll("```json", "").replaceAll("```", "").trim();
        }

        Map<String, dynamic> jsonResponse = jsonDecode(temizCevap);
        return jsonResponse;
      }

      return null;
    } catch (e) {
      print("Gemini Analiz Hatası: $e");
      return null;
    }
  }
}
