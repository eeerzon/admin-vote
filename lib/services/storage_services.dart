// ignore_for_file: non_constant_identifier_names

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static Future<bool> setOnboardingDone(bool value) async {
    await _storage.write(key: 'hasSeenOnboarding', value: value.toString());
    return value;
  }

  static Future<bool> getOnboardingDone() async {
    return await _storage.read(key: 'hasSeenOnboarding') == 'true';
  }

  static Future<void> setLanguage(String langCode) async {
    await _storage.write(key: 'language_code', value: langCode);
  }

  static Future<String?> getLanguage() async {
    return await _storage.read(key: 'language_code');
  }
  
  static const _currencyKey = 'active_currency';

  static Future<void> setCurrency(String currencyCode) async {
    await _storage.write(key: _currencyKey, value: currencyCode);
  }

  static Future<String> getCurrency() async {
    final value = await _storage.read(key: _currencyKey);
    return value ?? 'IDR';
  }

  static Future<void> setToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  static Future<void> removeToken() async {
    await _storage.delete(key: 'token');
  }

  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<void> removeRefreshToken() async {
    await _storage.delete(key: 'refresh_token');
  }

  static Future<void> setUser({
    required String id,
    required String id_merchant,
    required String name,
    required String userName,
    required String email,
    required String phone,
    required String level,
  }) async {
    await _storage.write(key: 'user_id', value: id);
    await _storage.write(key: 'user_id_merchant', value: id_merchant);
    await _storage.write(key: 'user_name', value: name);
    await _storage.write(key: 'user_username', value: userName);
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_phone', value: phone);
    await _storage.write(key: 'user_level', value: level);
  }

  static Future<Map<String, String?>> getUser() async {
    final id = await _storage.read(key: 'user_id');
    final id_merchant = await _storage.read(key: 'user_id_merchant');
    final name = await _storage.read(key: 'user_name');
    final userName = await _storage.read(key: 'user_username');
    final email = await _storage.read(key: 'user_email');
    final phone = await _storage.read(key: 'user_phone');
    final level = await _storage.read(key: 'user_level');

    return {
      'id': id,
      'id_merchant': id_merchant,
      'name': name,
      'userName': userName,
      'email': email,
      'phone': phone,
      'level': level,
    };
  }

  static Future<void> clearUser() async {
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_id_merchant');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_username');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_phone');
    await _storage.delete(key: 'user_level');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<void> setIsChoosed(int isChoosed) async {
    await _storage.write(key: 'isChoosed', value: isChoosed.toString());
  }

  static Future<int?> getIsChoosed() async {
    final value = await _storage.read(key: 'isChoosed');
    return value != null ? int.tryParse(value) : null;
  }

  static Future<void> setTrayId(String langCode) async {
    await _storage.write(key: 'tray_id', value: langCode);
  }

  static Future<String?> getTrayId() async {
    return await _storage.read(key: 'tray_id');
  }

  static Future<void> removeTrayId() async {
    await _storage.delete(key: 'tray_id');
  }
}
