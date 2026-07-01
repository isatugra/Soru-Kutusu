import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Aktif kullanıcı durumunu dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // E-posta ve Şifre ile Kayıt Ol
  Future<UserCredential> kayitOl({
    required String email,
    required String password,
    required String adSoyad,
    required String rol,
  }) async {
    try {
      // 1. Firebase Auth üzerinde kullanıcı oluştur
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Firestore'da kullanıcı profil dökümanını oluştur
      await _firestore
          .collection('kullanicilar')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'adSoyad': adSoyad,
            'email': email,
            'rol': rol,
            'kayitTarihi': FieldValue.serverTimestamp(),
          });

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception("Bilinmeyen bir hata oluştu: $e");
    }
  }

  // E-posta ve Şifre ile Giriş Yap
  Future<String> girisYap({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Auth girişi yap
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Firestore'dan kullanıcının rolünü oku
      DocumentSnapshot userDoc =
          await _firestore
              .collection('kullanicilar')
              .doc(userCredential.user!.uid)
              .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['rol'] ?? 'Öğrenci';
      } else {
        throw Exception("Kullanıcı profili veritabanında bulunamadı.");
      }
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Çıkış Yap
  Future<void> cikisYap() async {
    await _auth.signOut();
  }

  // Firebase Hata Mesajlarını Türkçeleştirme Dönüştürücüsü
  String hataMesajiniTurkcelestir(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'Geçersiz bir e-posta adresi girdiniz.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı engellenmiştir.';
      case 'user-not-found':
        return 'Bu e-posta adresine kayıtlı bir kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten başka bir hesap tarafından kullanılıyor.';
      case 'weak-password':
        return 'Girdiğiniz şifre çok zayıf (En az 6 karakter olmalıdır).';
      case 'operation-not-allowed':
        return 'E-posta/Şifre girişi Firebase üzerinde aktif edilmemiş.';
      default:
        return 'Bir kimlik doğrulama hatası oluştu ($errorCode).';
    }
  }
}
