import 'dart:convert';
import 'package:flutter/services.dart';

class LangService {
  static Future<List<Map<String, dynamic>>> loadOnboarding(String langCode) async {
    final String response =
        await rootBundle.loadString('assets/lang/$langCode.json');
    final data = json.decode(response);
    return List<Map<String, dynamic>>.from(data["onboarding"]);
  }
  

  static Future<String> getText(String langCode, String key) async {
    final String response =
        await rootBundle.loadString("assets/lang/$langCode.json");
    final data = json.decode(response);
    return data[key] as String;
  }

  static Future<Map<String, dynamic>> getJsonData(String langCode, String header) async {
    final String response =
        await rootBundle.loadString("assets/lang/$langCode.json");
    final data = json.decode(response);
    return Map<String, dynamic>.from(data[header]);
  }

  static Future<Map<String, dynamic>> getJsonDataArray(String langCode, String header, String subHeader) async {
  final String response =
      await rootBundle.loadString("assets/lang/$langCode.json");
  final data = json.decode(response);
  return Map<String, dynamic>.from(data[header][subHeader]);
}

}
