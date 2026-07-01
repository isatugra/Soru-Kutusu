import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/storage_service.dart';
import '../../services/gemini_service.dart';
import '../../services/firestore_service.dart';
import 'ders_detay_screen.dart';
import 'package:soru_kutusu_app/screens/ogrenci/analiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soru_kutusu_app/screens/auth/login_screen.dart';

class OgrenciHomeScreen extends StatefulWidget {
  const OgrenciHomeScreen({super.key});

  @override
  State<OgrenciHomeScreen> createState() => _OgrenciHomeScreenState();
}

class _OgrenciHomeScreenState extends State<OgrenciHomeScreen> {
  final StorageService _storageService = StorageService();
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String? _secilenSoruYolu;
  bool _yukleniyor = false;

  // --- KAMERADAN VEYA GALERİDEN FOTOĞRAF ALMA VE KIRPMA ---
  Future<void> _soruSec(ImageSource kaynak) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: kaynak,
        imageQuality: 85,
      );
      if (foto == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: foto.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Soruyu Kırp',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _yukleniyor = true;
      });

      // Fotoğrafı yerel hafızaya kalıcı olarak kopyalıyoruz (Maliyet Sıfırlama)
      final directory = await getApplicationDocumentsDirectory();
      final String yeniIsim =
          'soru_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File yerelFoto = await File(
        croppedFile.path,
      ).copy('${directory.path}/$yeniIsim');

      // Gemini analizi senin servisindeki orijinal metot ismiyle başlatılıyor
      final analizSonucu = await _geminiService.soruAnalizEt(
        File(yerelFoto.path),
      );

      setState(() {
        _secilenSoruYolu = yerelFoto.path;
        _yukleniyor = false;
      });

      if (analizSonucu != null) {
        _analizSonucunuGoster(analizSonucu);
      } else {
        _hataMesajiGoster(
          'Yapay zeka analizi başarısız oldu. Lütfen tekrar deneyin.',
        );
      }
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataMesajiGoster('Bir hata oluştu: $e');
    }
  }

  void _manuelSoruEkle() {
    final dersController = TextEditingController();
    final konuController = TextEditingController();

    String soruTuru = "Çoktan Seçmeli";
    String zorluk = "Orta";
    String? manuelFotoYolu; // Seçilen fotoğrafın yolunu hafızada tutar

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Kameradan veya galeriden görsel alıp kırpan fonksiyon
            Future<void> manuelFotoSec(ImageSource kaynak) async {
              try {
                final XFile? foto = await _picker.pickImage(
                  source: kaynak,
                  imageQuality: 85,
                );
                if (foto == null) return;

                final croppedFile = await ImageCropper().cropImage(
                  sourcePath: foto.path,
                  uiSettings: [
                    AndroidUiSettings(
                      toolbarTitle: 'Soruyu Kırp',
                      toolbarColor: Colors.deepPurple,
                      toolbarWidgetColor: Colors.white,
                      initAspectRatio: CropAspectRatioPreset.original,
                      lockAspectRatio: false,
                    ),
                  ],
                );

                if (croppedFile == null) return;

                final directory = await getApplicationDocumentsDirectory();
                final String yeniIsim =
                    'manuel_soru_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final File yerelFoto = await File(
                  croppedFile.path,
                ).copy('${directory.path}/$yeniIsim');

                setModalState(() {
                  manuelFotoYolu =
                      yerelFoto.path; // Arayüzü tetikler ve resmi gösterir
                });
              } catch (e) {
                _hataMesajiGoster('Fotoğraf seçilirken hata oluştu: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Manuel Soru Ekle",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔥 FOTOĞRAF ÇEKME VE ÖNİZLEME ALANI
                    Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child:
                          manuelFotoYolu != null
                              ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(manuelFotoYolu!),
                                      width: double.infinity,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 18,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setModalState(() {
                                            manuelFotoYolu =
                                                null; // Resmi siler ve butonları geri getirir
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(
                                    onPressed:
                                        () => manuelFotoSec(ImageSource.camera),
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.deepPurple,
                                    ),
                                    label: const Text(
                                      'Kameradan Çek',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    color: Colors.grey.shade400,
                                    indent: 35,
                                    endIndent: 35,
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        () =>
                                            manuelFotoSec(ImageSource.gallery),
                                    icon: const Icon(
                                      Icons.photo_library,
                                      color: Colors.deepPurple,
                                    ),
                                    label: const Text(
                                      'Galeriden Seç',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: dersController,
                      decoration: const InputDecoration(
                        labelText: "Ders",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: konuController,
                      decoration: const InputDecoration(
                        labelText: "Konu",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: soruTuru,
                      decoration: const InputDecoration(
                        labelText: "Soru Türü",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Çoktan Seçmeli",
                          child: Text("Çoktan Seçmeli"),
                        ),
                        DropdownMenuItem(
                          value: "Klasik",
                          child: Text("Klasik"),
                        ),
                        DropdownMenuItem(
                          value: "Yeni Nesil",
                          child: Text("Yeni Nesil"),
                        ),
                        DropdownMenuItem(
                          value: "Boşluk Doldurma",
                          child: Text("Boşluk Doldurma"),
                        ),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          soruTuru = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: zorluk,
                      decoration: const InputDecoration(
                        labelText: "Zorluk",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Kolay", child: Text("Kolay")),
                        DropdownMenuItem(value: "Orta", child: Text("Orta")),
                        DropdownMenuItem(value: "Zor", child: Text("Zor")),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          zorluk = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _firestoreService.soruKaydet(
                            dersAdi: dersController.text.trim(),
                            konuAdi: konuController.text.trim(),
                            soruTuru: soruTuru,
                            zorlukSeviyesi: zorluk,
                            yerelFotoYolu:
                                manuelFotoYolu ??
                                "", // 🔥 Seçilen resmin yolunu artık buraya gönderiyoruz
                          );

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Soru başarıyla eklendi."),
                            ),
                          );
                        },
                        child: const Text("Kaydet"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- GEMINI SONUCUNU POP-UP DÜZENLEME EKRANINDA GÖSTERME ---
  // Eski hali Map<String, String> olan yeri Map<String, dynamic> yapıyoruz:
  void _analizSonucunuGoster(Map<String, dynamic> analiz) {
    final TextEditingController dersController = TextEditingController(
      text: analiz['dersAdi']?.toString(),
    );
    final TextEditingController konuController = TextEditingController(
      text: analiz['konuAdi']?.toString(),
    );
    String secilenSoruTuru = analiz['soruTuru']?.toString() ?? 'Çoktan Seçmeli';
    String secilenZorluk = analiz['zorlukSeviyesi']?.toString() ?? 'Orta';

    // Geri kalan alt kodlar (showModalBottomSheet...) tamamen aynı kalıyor

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yapay Zeka Analiz Sonucu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dersController,
                      decoration: const InputDecoration(
                        labelText: 'Ders Adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: konuController,
                      decoration: const InputDecoration(
                        labelText: 'Konu Adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Soru Türü Seçimi
                    const Text(
                      'Soru Türü',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      // 🔥 KORUMA: Eğer gelen değer listede yoksa çökme, listenin ilk elemanını seç
                      value:
                          [
                                'Çoktan Seçmeli',
                                'Klasik',
                                'Yeni Nesil',
                                'Boşluk Doldurma',
                                'Şekilli Soru', // 🔥 Hata veren 'Şekilli Soru' seçeneği listeye eklendi
                              ].contains(secilenSoruTuru)
                              ? secilenSoruTuru
                              : 'Çoktan Seçmeli',
                      isExpanded: true,
                      items:
                          [
                            'Çoktan Seçmeli',
                            'Klasik',
                            'Yeni Nesil',
                            'Boşluk Doldurma',
                            'Şekilli Soru', // 🔥 Görsel olarak da menüde belirecek
                          ].map((String deger) {
                            return DropdownMenuItem<String>(
                              value: deger,
                              child: Text(deger),
                            );
                          }).toList(),
                      onChanged:
                          (yeni) =>
                              setModalState(() => secilenSoruTuru = yeni!),
                    ),
                    const SizedBox(height: 12),

                    // Zorluk Seçimi
                    const Text(
                      'Zorluk Seviyesi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      // 🔥 KORUMA: Zorluk seviyesi için de aynı zırhı ekliyoruz
                      value:
                          ['Kolay', 'Orta', 'Zor'].contains(secilenZorluk)
                              ? secilenZorluk
                              : 'Orta',
                      isExpanded: true,
                      items:
                          ['Kolay', 'Orta', 'Zor'].map((String deger) {
                            return DropdownMenuItem<String>(
                              value: deger,
                              child: Text(deger),
                            );
                          }).toList(),
                      onChanged:
                          (yeni) => setModalState(() => secilenZorluk = yeni!),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final String sonDers = dersController.text.trim();
                        final String sonKonu = konuController.text.trim();

                        Navigator.of(context).pop();

                        bool kayitBasarili = await _firestoreService.soruKaydet(
                          dersAdi: sonDers,
                          konuAdi: sonKonu,
                          soruTuru: secilenSoruTuru,
                          zorlukSeviyesi: secilenZorluk,
                          yerelFotoYolu: _secilenSoruYolu ?? '',
                        );

                        if (!context.mounted) return;

                        if (kayitBasarili) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🎉 $sonDers - $sonKonu başarıyla deftere kaydedildi!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Veri tabanına kaydedilirken bir hata oluştu.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Onayla ve Deftere Ekle',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _hataMesajiGoster(String mesaj) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
  }

  // --- DERS RENKLERİNİ OTOMATİK BELİRLEYEN YARDIMCI METOD ---
  Color _getDersRenk(String ders) {
    switch (ders) {
      case 'Matematik':
        return Colors.blue;
      case 'Fizik':
        return Colors.orange;
      case 'Kimya':
        return Colors.green;
      case 'Biyoloji':
        return Colors.pink;
      case 'Türkçe':
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // --- APPBAR BAŞLANGICI ---
      appBar: AppBar(
        title: const Text(
          'Soru Kutusu',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          // 1. ANALİZ BUTONU (Senin eklediğin)
          IconButton(
            icon: const Icon(
              Icons.bar_chart_rounded,
              color:
                  Colors
                      .deepPurple, // Beyaz arka planda deepPurple harika durur
              size: 26,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalizScreen()),
              );
            },
          ),

          // 2. PROFESYONEL ÇIKIŞ BUTONU (Yeni eklenen)
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color:
                  Colors
                      .redAccent, // Çıkış butonu olduğu için hafif kırmızı tonda olması şık durur
              size: 24,
            ),
            tooltip: 'Oturumu Kapat',
            onPressed: () async {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Oturumu Kapat'),
                    content: const Text(
                      'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(color: Colors.grey),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text(
                          'Çıkış Yap',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.clear(); // Hafızayı temizle

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ), // --- APPBAR BİTİŞİ ---
      body:
          _yukleniyor
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    SizedBox(height: 16),
                    Text(
                      'Gemini soruyu analiz ediyor, lütfen bekleyin...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Karşılama Kartı
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selam Mühendis! 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Yanlış yaptığın soruların fotoğrafını çek, yapay zeka senin için klasörlesin ve PDF test kitapçığı hazırlasın.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Ders Klasörlerin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🔥 DİNAMİK FIRESTORE SINIFLANDIRMA MOTORU
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('yanlis_sorular')
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.deepPurple,
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henüz hiç soru eklenmemiş. İlk sorunu ekle!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        // Firestore'daki verileri ders adına göre grupluyoruz
                        final docs = snapshot.data!.docs;
                        Map<String, List<QueryDocumentSnapshot>>
                        dinamikDersler = {};

                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          String ders = data['dersAdi'] ?? 'Genel';
                          if (!dinamikDersler.containsKey(ders)) {
                            dinamikDersler[ders] = [];
                          }
                          dinamikDersler[ders]!.add(doc);
                        }

                        final benzersizDersListesi =
                            dinamikDersler.keys.toList();

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.3,
                              ),
                          itemCount: benzersizDersListesi.length,
                          itemBuilder: (context, index) {
                            String dersAdi = benzersizDersListesi[index];
                            int soruSayisi = dinamikDersler[dersAdi]!.length;
                            Color cizgiRengi = _getDersRenk(dersAdi);

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => DersDetayScreen(
                                          dersAdi: dersAdi,
                                          dersRengi: cizgiRengi,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: cizgiRengi,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dersAdi,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$soruSayisi Hatalı Soru',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'Fotoğraf',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _soruSec(ImageSource.camera),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: const Text(
                    'Galeri',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _soruSec(ImageSource.gallery),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note),
                  label: const Text(
                    'Manuel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _manuelSoruEkle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
