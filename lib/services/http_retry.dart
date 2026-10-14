import 'dart:convert';

import 'package:http/http.dart' as http;

/// GET cu reîncercări: Open-Meteo răspunde uneori „service is overloaded”.
Future<Map<String, dynamic>> getJsonWithRetry(
  Uri uri, {
  int attempts = 3,
}) async {
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    if (i > 0) await Future<void>.delayed(Duration(milliseconds: 800 * i * i));
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['error'] != true) {
        return body;
      }
      lastError = body is Map
          ? (body['reason'] ?? res.statusCode)
          : res.statusCode;
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception('Serviciul meteo nu răspunde ($lastError)');
}
