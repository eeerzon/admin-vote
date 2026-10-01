import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:admin_vote_mobile/helper/global_var.dart';
import 'package:admin_vote_mobile/services/lang_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {

  static Future<Map<String, dynamic>?> postLogin(
    String endpoint, 
    {
      Map<String, dynamic>? body,
      String? xLanguage,
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final url = Uri.parse("$baseUrl$endpoint");

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(const Duration(seconds: 15));

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      }

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      } on FormatException {
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      }

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> postLogout(
    String endpoint, 
    {
      String? xLanguage,
      String? token
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final url = Uri.parse("$baseUrl$endpoint");

    try {
      final response = await http.post(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      }

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      } on FormatException {
        return {
          "rc": response.statusCode,
          "status": false,
          "message": bahasa['error'],
          "data": [],
        };
      }

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }
  
  static Future<Map<String, dynamic>?> post(
    String endpoint, 
    {
      Map<String, dynamic>? body,
      String? xLanguage,
      String? token
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-language': xLanguage,
    };
    final url = Uri.parse("$baseUrl$endpoint");

    http.Response? response;
    try {
      response = await http.post(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(const Duration(seconds: 15));

      return json.decode(response.body) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      debugPrint(
        'ApiService.post $endpoint failed: $e\n'
        'status=${response?.statusCode} body=${response?.body}',
      );
      return {
        "rc": response?.statusCode ?? 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> postImage(
    String endpoint, 
    {
      File? file,
      String? xLanguage,
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    final url = Uri.parse("$baseUrl$endpoint");

    var request = http.MultipartRequest("POST", url);

    if (file != null) {
      request.files.add(
        await http.MultipartFile.fromPath('files[]', file.path),
      );
    }

    try {
      final streamedResponse = await request.send();
      final respStr = await streamedResponse.stream.bytesToString();
      
      return json.decode(respStr) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> postMultipart(
    String endpoint,
    {
      required String fieldName,
      required File file,
      String? token,
      String? xLanguage,
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    final url = Uri.parse("$baseUrl$endpoint");

    var request = http.MultipartRequest("POST", url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final respStr = await streamedResponse.stream.bytesToString();

      return json.decode(respStr) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> postSetProfil(
    String endpoint, 
    {
      String? token,
      Map<String, dynamic>? body,
      String? xLanguage,
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    final url = Uri.parse(endpoint);

    var headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };

    try {
      final response = await http
        .post(url, headers: headers, body: json.encode(body))
        .timeout(const Duration(seconds: 15));
        
      return json.decode(response.body) as Map<String, dynamic>;
      
    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }
  
  static Future<Map<String, dynamic>?> get(
    String endpoint, 
    {
      Map<String, String>? params,
      String? xLanguage,
      String? token
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-language': xLanguage,
      'Authorization': 'Bearer $token',
    };

    // Uri url = Uri.parse("$baseapiUrl$endpoint");
    Uri url = Uri.parse("$baseUrl$endpoint");
    
    if (params != null) {
      url = url.replace(queryParameters: params);
    }

    try {
      final response = await http
        .get(url, headers: headers)
        .timeout(Duration(seconds: 15));
        
      return json.decode(response.body) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> getLoginUser(
    String endpoint, 
    {
      String? token,
      String? xLanguage,
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    final url = Uri.parse("$baseUrl$endpoint");

    var headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };

    try {
      final response = await http
        .get(url, headers: headers)
        .timeout(Duration(seconds: 15));
        
      return json.decode(response.body) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> patch(
    String endpoint, 
    {
      Map<String, dynamic>? body,
      String? xLanguage,
      String? xCurrency,
      String? token
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-language': xLanguage,
      'x-currency': ?xCurrency,
    };

    final url = Uri.parse("$baseUrl$endpoint");

    try {
      final response = await http
        .patch(url, headers: headers, body: json.encode(body))
        .timeout(Duration(seconds: 15));
        
      return json.decode(response.body) as Map<String, dynamic>;
      
    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> delete(
    String endpoint,
    {
      String? xLanguage,
      String? token
    }
  ) async {
    final bahasa = await LangService.getJsonData(xLanguage!, 'bahasa');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-language': xLanguage,
    };

    final url = Uri.parse("$baseUrl$endpoint");

    try {
      final response = await http
        .delete(url, headers: headers)
        .timeout(const Duration(seconds: 15));

      return json.decode(response.body) as Map<String, dynamic>;

    } on TimeoutException {
      return {
        "rc": 408,
        "status": false,
        "message": bahasa['timeout'],
        "data": []
      };
    } on SocketException {
      return {
        "rc": 503,
        "status": false,
        "message": bahasa['no_internet'],
        "data": []
      };
    } catch (e) {
      return {
        "rc": 500,
        "status": false,
        "message": bahasa['error'],
        "data": []
      };
    }
  }

  static Future<Map<String, dynamic>?> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? xLanguage,
    String? token,
  }) async {
    // salin persis logic dari method `post` yang sudah ada,
    // cuma ganti http.post(...) jadi http.put(...)
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (xLanguage != null) 'x-language': xLanguage,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .put(url, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      return null;
    }
  }
}
