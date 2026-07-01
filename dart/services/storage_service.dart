import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final ImagePicker _picker = ImagePicker();

  // 1. Kameradan Fotoğraf Çekme ve Otomatik Kırpma Fonksiyonu
  Future<File?> fotografCekVeKirp(BuildContext context) async {
    // Kameradan ham fotoğrafı alıyoruz
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (pickedFile == null) return null;

    // Fotoğraf çekildiyse hemen kırpıcıyı (Cropper) açıyoruz
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Soruyu Kırp',
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false, // Kullanıcı istediği boyutta kırpabilsin
        ),
        IOSUiSettings(title: 'Soruyu Kırp'),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  // 2. Kırpılan Fotoğrafı Telefon Hafızasına Kalıcı Kaydetme
  Future<String> lokaleKaydet(File kirpilmisFoto) async {
    // Uygulamanın telefondaki özel döküman klasörünü buluyoruz
    final directory = await getApplicationDocumentsDirectory();

    // Benzersiz bir dosya adı oluşturuyoruz (Örn: soru_171956572.jpg)
    String dosyaAdi = 'soru_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Klasör yolu ile dosya adını birleştiriyoruz
    final String kaliciYol = path.join(directory.path, dosyaAdi);

    // Fotoğrafı o kalıcı yola kopyalıyoruz
    final File yeniFoto = await kirpilmisFoto.copy(kaliciYol);

    // Telefon hafızasındaki dosya yolunu dönüyoruz
    return yeniFoto.path;
  }
}
