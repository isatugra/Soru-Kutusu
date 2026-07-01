import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soru_kutusu_app/screens/ogrenci/ogrenci_home_screen.dart';
import 'package:soru_kutusu_app/screens/ogretmen/ogretmen_home_screen.dart'; // Öğretmen sayfasını import ediyoruz

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _kodController = TextEditingController();
  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _bransController =
      TextEditingController(); // Öğretmenler için ekstra branş

  // Belirlenen Özel Giriş Kodları
  final String _ogrenciKodu = "SORU2026";
  final String _ogretmenKodu = "HOCA2026";

  String _belirlenenRol = ""; // "Öğrenci" veya "Öğretmen" durumunu tutacak
  bool _kodDogrulandi = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _kodController.dispose();
    _adSoyadController.dispose();
    _telefonController.dispose();
    _bransController.dispose();
    super.dispose();
  }

  // Giriş Kodunu Kontrol Eden Fonksiyon (Rolü burada ayrıştırıyoruz)
  void _koduDogrula() {
    String girilenKod = _kodController.text.trim();

    if (girilenKod == _ogrenciKodu) {
      setState(() {
        _belirlenenRol = "Öğrenci";
        _kodDogrulandi = true;
      });
      _mesajGoster(
        'Öğrenci kodu onaylandı! Lütfen bilgilerinizi girin.',
        Colors.green,
      );
    } else if (girilenKod == _ogretmenKodu) {
      setState(() {
        _belirlenenRol = "Öğretmen";
        _kodDogrulandi = true;
      });
      _mesajGoster(
        'Öğretmen kodu onaylandı! Lütfen bilgilerinizi girin.',
        Colors.deepPurple,
      );
    } else {
      _mesajGoster('Geçersiz Giriş Kodu!', Colors.redAccent);
    }
  }

  // Kullanıcıyı Veritabanına ve Cihaz Hafızasına Kaydeden Fonksiyon
  Future<void> _sistemeGirisYap() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String uid =
        _telefonController.text
            .trim(); // Telefon numarasını benzersiz ID yapıyoruz
    String adSoyad = _adSoyadController.text.trim();
    String telefon = _telefonController.text.trim();
    String brans = _bransController.text.trim();

    // Hangi koleksiyona yazılacağını seçiyoruz
    String koleksiyonAdi =
        _belirlenenRol == "Öğrenci" ? 'ogrenciler' : 'ogretmenler';

    try {
      // 1. Firestore Bulut Veritabanına Kaydet
      await FirebaseFirestore.instance
          .collection(koleksiyonAdi)
          .doc(uid)
          .set({
            'id': uid,
            'adSoyad': adSoyad,
            'telefon': telefon,
            if (_belirlenenRol == "Öğretmen") 'brans': brans,
            'rol': _belirlenenRol,
            'kayitTarihi': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      print("Firestore bağlantısı atlandı (Web/Mobil Çevrimdışı Geçişi): $e");
    }

    // 2. Tarayıcı/Telefon Yerel Hafızasına Kaydet (Giriş durumunu hatırlasın diye)
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('rol', _belirlenenRol);
    await prefs.setString('adSoyad', adSoyad);
    await prefs.setString('telefon', telefon);

    if (!mounted) return;

    // 3. Role Göre Doğru Sayfaya Yönlendir
    if (_belirlenenRol == "Öğrenci") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OgrenciHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OgretmenHomeScreen()),
      );
    }
  }

  void _mesajGoster(String mesaj, Color renk) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ), // Web'de ekran devasa görünmesin diye sınırladık
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      size: 85,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Soru Kutusu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _kodDogrulandi
                          ? 'Profil Türü: $_belirlenenRol'
                          : 'Lütfen size verilen erişim kodu ile giriş yapın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            _kodDogrulandi
                                ? Colors.deepPurple
                                : Colors.grey[600],
                        fontWeight:
                            _kodDogrulandi
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // --- 1. AŞAMA: ERİŞİM KODU ALANI ---
                    if (!_kodDogrulandi) ...[
                      TextFormField(
                        controller: _kodController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'GİRİŞ KODU',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _koduDogrula,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Kodu Doğrula',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    // --- 2. AŞAMA: DİNAMİK KAYIT FORMU ---
                    if (_kodDogrulandi) ...[
                      TextFormField(
                        controller: _adSoyadController,
                        decoration: InputDecoration(
                          labelText: 'Adınız Soyadınız',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Lütfen adınızı girin'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Eğer öğretmen giriş yaptıysa ekstra branş soruyoruz
                      if (_belirlenenRol == "Öğretmen") ...[
                        TextFormField(
                          controller: _bransController,
                          decoration: InputDecoration(
                            labelText: 'Branşınız (Örn: Matematik)',
                            prefixIcon: const Icon(Icons.school_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Lütfen branşınızı girin'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _telefonController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Telefon Numaranız',
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.length < 10)
                                    ? 'Geçerli bir telefon girin'
                                    : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sistemeGirisYap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _belirlenenRol == "Öğrenci"
                                  ? Colors.green
                                  : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  '$_belirlenenRol Panelini Başlat',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
