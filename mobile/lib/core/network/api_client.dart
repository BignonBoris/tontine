import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/storage/session_storage.dart';

enum ApiErrorType {
  network,
  sessionExpired,
  unauthorized,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorType type;

  const ApiException(
    this.message, [
    this.statusCode,
    this.type = ApiErrorType.unknown,
  ]);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;
  final bool invalidateSessionOnUnauthorized;

  ApiClient({
    http.Client? client,
    this.invalidateSessionOnUnauthorized = true,
  }) : _client = client ?? http.Client();

  Future<dynamic> get(String path, {bool authenticated = true}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.get(
        uri,
        headers: await _headers(authenticated: authenticated),
      ),
    );
    _logHttpResponse('GET', uri, response);
    return _extractData(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.post(
        uri,
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    _logHttpResponse('POST', uri, response);
    return _extractData(response);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.patch(
        uri,
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    _logHttpResponse('PATCH', uri, response);
    return _extractData(response);
  }

  Future<dynamic> postBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.Request('POST', uri)
      ..headers.addAll(await _headers(authenticated: true))
      ..headers['Content-Type'] = contentType
      ..bodyBytes = bytes;
    final response = await _sendRequest(
      () => _client.send(request).then(http.Response.fromStream),
    );
    _logHttpResponse('POST', uri, response);
    return _extractData(response);
  }

  void _logHttpResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[API] $method $uri -> ${response.statusCode}');
    if (response.body.isNotEmpty) {
      debugPrint('[API] $method $uri response => ${response.body}');
    }
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        "Le serveur met trop de temps a repondre. Verifiez votre connexion puis reessayez.",
        null,
        ApiErrorType.network,
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('[API CLIENT] ClientException: $e');
      }
      throw const ApiException(
        "Impossible de joindre le serveur. Verifiez votre connexion internet.",
        null,
        ApiErrorType.network,
      );
    } on FormatException {
      throw const ApiException(
        "La reponse du serveur est invalide. Reessayez plus tard.",
        null,
        ApiErrorType.server,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[API CLIENT] Unexpected network error: $e');
      }
      throw ApiException(
        "Impossible de joindre le serveur ($e).",
        null,
        ApiErrorType.network,
      );
    }
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await SessionStorage.getToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          "Session invalide. Reconnectez-vous pour continuer.",
          null,
          ApiErrorType.sessionExpired,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _extractData(http.Response response) {
    final dynamic payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload is Map<String, dynamic> && payload.containsKey('data')) {
        return payload['data'];
      }
      return payload;
    }

    final message = payload is Map<String, dynamic>
        ? (payload['message'] as String? ?? 'Une erreur est survenue.')
        : 'Une erreur est survenue.';

    if (response.statusCode == 401) {
      if (invalidateSessionOnUnauthorized) {
        SessionStorage.clear();
        throw ApiException(
          message.isEmpty
              ? "Votre session a expire. Reconnectez-vous pour continuer."
              : message,
          response.statusCode,
          ApiErrorType.sessionExpired,
        );
      }
      throw ApiException(
        message.isEmpty
            ? "Acces refuse. Reconnectez-vous pour continuer."
            : message,
        response.statusCode,
        ApiErrorType.unauthorized,
      );
    }

    final type = switch (response.statusCode) {
      400 || 404 || 409 || 422 => ApiErrorType.validation,
      403 => ApiErrorType.unauthorized,
      >= 500 => ApiErrorType.server,
      _ => ApiErrorType.unknown,
    };

    throw ApiException(message, response.statusCode, type);
  }
}
