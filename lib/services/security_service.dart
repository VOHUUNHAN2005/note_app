import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final _key = encrypt_pkg.Key.fromUtf8('my32lengthsupersecretnoappkey123');
  final _iv = encrypt_pkg.IV.fromLength(16);

  static const String _passwordKey = 'private_notes_password';

  SecurityService._init();
  String encryptText(String text) {
    if (text.isEmpty) return text;
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_key));
    final encrypted = encrypter.encrypt(text, iv: _iv);
    return encrypted.base64;
  }

  String decryptText(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    try {
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_key));
      return encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (e) {
      return encryptedText; 
    }
  }
  Future<bool> hasPassword() async {
    final pwd = await _storage.read(key: _passwordKey);
    return pwd != null && pwd.isNotEmpty;
  }

  Future<void> savePassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<bool> verifyPassword(String inputPassword) async {
    final savedPwd = await _storage.read(key: _passwordKey);
    return savedPwd == inputPassword;
  }
  String? validateBankPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mật khẩu không được để trống';
    }
    if (value.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ cái viết hoa';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ cái viết thường';
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ số';
    }
    if (!RegExp(r'(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt (!@#\$%...)';
    }
    return null;
  }
}