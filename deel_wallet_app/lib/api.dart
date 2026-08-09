import 'dart:convert';
import 'package:http/http.dart' as http;

/// 10.0.2.2 = alias reseau de l'hote depuis l'emulateur Android, pas de
/// backend qui tourne dans docker-compose (port 3001). Sur telephone
/// physique ou hors emulateur, remplacer par l'IP LAN de la machine ou une
/// URL ngrok.
const apiBaseUrl = 'http://10.0.2.2:3001';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ponytail: un seul client statique, pas de DI/singleton-factory pour une
/// app a un seul backend. Token garde en memoire (perdu au redemarrage de
/// l'app) — ajouter shared_preferences si "rester connecte" est demande.
class Api {
  static String? token;

  static Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decode(http.Response r) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Réponse serveur invalide (${r.statusCode}).');
    }
    if (r.statusCode >= 400) {
      throw ApiException(
          (body['error'] ?? body['message'] ?? 'Erreur serveur (${r.statusCode}).')
              .toString());
    }
    return body;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final r = await http.get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _decode(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Impossible de joindre le serveur BAOU Finance.');
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _decode(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Impossible de joindre le serveur BAOU Finance.');
    }
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .patch(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _decode(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Impossible de joindre le serveur BAOU Finance.');
    }
  }
}
