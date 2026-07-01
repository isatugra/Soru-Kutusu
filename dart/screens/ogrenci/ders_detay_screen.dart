import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart'; // Yerel dosya yolları için
import 'package:pdf/pdf.dart'; // PDF altyapısı
import 'package:pdf/widgets.dart' as pw; // PDF widget'ları
import 'package:open_filex/open_filex.dart'; // PDF dosyasını açmak için paketimiz

class DersDetayScreen extends StatelessWidget {
  final String dersAdi;
  final Color dersRengi;

  const DersDetayScreen({
    super.key,
    required this.dersAdi,
    required this.dersRengi,
  });

  // 🔥 SORU SİLME MOTORU (Firestore veritabanından güvenle temizler)
  Future<void> _soruSil(BuildContext context, String soruId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Soruyu Sil"),
            ],
          ),
          content: const Text(
            "Bu yanlış sorusunu klasörünüzden kalıcı olarak silmek istediğinize emin misiniz?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context); // Diyaloğu kapat

                try {
                  await FirebaseFirestore.instance
                      .collection('yanlis_sorular')
                      .doc(soruId)
                      .delete();

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Soru başarıyla silindi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Soru silinirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Sil"),
            ),
          ],
        );
      },
    );
  }

  // TASARRUFLU VE AKILLI PDF ÜRETME VE GÖRÜNTÜLEME MOTORU
  Future<void> _pdfUretVeKaydet(
    BuildContext context,
    List<QueryDocumentSnapshot> sorular,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          ),
    );

    try {
      final pdf = pw.Document();
      final List<pw.Widget> pdfIcerigi = [];

      pdfIcerigi.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '$dersAdi Yanlış Defteri - Kişisel Tarama Testi',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Oluşturulma Tarihi: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      );

      for (var i = 0; i < sorular.length; i++) {
        final data = sorular[i].data() as Map<String, dynamic>;
        final String yerelYol = data['yerelFotoYolu'] ?? '';
        final String konu = data['konuAdi'] ?? 'Konu Belirtilmemiş';
        final String zorluk = data['zorlukSeviyesi'] ?? 'Orta';

        if (yerelYol.isNotEmpty && File(yerelYol).existsSync()) {
          final imageBytes = File(yerelYol).readAsBytesSync();
          final pdfImage = pw.MemoryImage(imageBytes);

          pdfIcerigi.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Soru ${i + 1}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        'Konu: $konu | Zorluk: $zorluk',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Container(
                      height: 220,
                      child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) => pdfIcerigi,
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final String temizDersAdi = dersAdi.toLowerCase().replaceAll(' ', '_');
      final file = File("${output.path}/$temizDersAdi\_yanlis_testi.pdf");
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) Navigator.of(context).pop();

      if (file.existsSync()) {
        await OpenFilex.open(file.path);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Çevre dostu test kitapçığın hazırlandı!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'ŞİMDİ AÇ',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFilex.open(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ PDF açılırken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('yanlis_sorular')
              .where('dersAdi', isEqualTo: dersAdi)
              .snapshots(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> sorularDoc =
            snapshot.hasData ? snapshot.data!.docs : [];

        if (sorularDoc.isNotEmpty) {
          try {
            sorularDoc.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTarih = aData['eklenmeTarihi'];
              final bTarih = bData['eklenmeTarihi'];

              if (aTarih != null && bTarih != null) {
                final DateTime dateA =
                    aTarih is Timestamp
                        ? aTarih.toDate()
                        : DateTime.parse(aTarih.toString());
                final DateTime dateB =
                    bTarih is Timestamp
                        ? bTarih.toDate()
                        : DateTime.parse(bTarih.toString());
                return dateB.compareTo(dateA);
              }
              return 0;
            });
          } catch (e) {
            debugPrint("Sıralama hatası: $e");
          }
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              '$dersAdi Klasörü',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            actions: [
              if (sorularDoc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    label: const Text(
                      'PDF İndir',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _pdfUretVeKaydet(context, sorularDoc),
                  ),
                ),
            ],
          ),
          body:
              snapshot.connectionState == ConnectionState.waiting
                  ? const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  )
                  : sorularDoc.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$dersAdi dersine ait henüz bir yanlış eklenmemiş.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorularDoc.length,
                    itemBuilder: (context, index) {
                      final doc = sorularDoc[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String yerelYol = data['yerelFotoYolu'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1.5,
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: dersRengi.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.image_outlined, color: dersRengi),
                          ),
                          title: Text(
                            data['konuAdi'] ?? 'Konu Yok',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Tür: ${data['soruTuru'] ?? 'Belirtilmemiş'}',
                          ),
                          trailing: _buildZorlukRozeti(
                            data['zorlukSeviyesi'] ?? 'Orta',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  yerelYol.isNotEmpty &&
                                          File(yerelYol).existsSync()
                                      ? Container(
                                        height: 220,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            File(yerelYol),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      )
                                      : Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Soru görseli yerel hafızada bulunamadı.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    'Soru Türü:',
                                    data['soruTuru'] ?? 'Belirtilmemiş',
                                  ),
                                  _buildInfoRow(
                                    'Zorluk Derecesi:',
                                    data['zorlukSeviyesi'] ?? 'Orta',
                                  ),

                                  // 🔥 SİLME BUTONU ALANI
                                  const Divider(),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_forever,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        "Soruyu Sil",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed:
                                          () => _soruSil(
                                            context,
                                            doc.id,
                                          ), // Firebase doküman ID'sini gönderiyoruz
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }

  Widget _buildInfoRow(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              deger,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZorlukRozeti(String zorluk) {
    Color rozetRengi = Colors.orange;
    if (zorluk == 'Zor') rozetRengi = Colors.red;
    if (zorluk == 'Kolay') rozetRengi = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: rozetRengi.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        zorluk,
        style: TextStyle(
          color: rozetRengi,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
