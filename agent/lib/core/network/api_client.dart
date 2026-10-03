import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:agent/core/network/api_config.dart';
import 'package:agent/core/services/network_time_service.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<dynamic> get(String path, {bool authenticated = true}) async {
    debugPrint('[ApiClient] GET ${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.get(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(authenticated),
      ),
    );
    return _extractData(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    debugPrint('[ApiClient] POST ${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _extractData(response);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    debugPrint('[ApiClient] PUT ${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.put(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _extractData(response);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    debugPrint('[ApiClient] PATCH ${ApiConfig.baseUrl}$path');
    final response = await _sendRequest(
      () async => _client.patch(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _extractData(response);
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    Map<String, String>? filePaths, // key: field name, value: file path
    bool authenticated = true,
  }) async {
    debugPrint('[ApiClient] POST (multipart) ${ApiConfig.baseUrl}$path');
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    
    final headers = await _headers(authenticated);
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    if (filePaths != null) {
      for (final entry in filePaths.entries) {
        if (entry.value.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }
    }

    final response = await _sendRequest(
      () => _client.send(request).then(http.Response.fromStream),
    );
    return _extractData(response);
  }

  Future<Map<String, String>> _headers(bool authenticated) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await SessionStorage.getToken();
      if (token == null || token.isEmpty) {
        throw const ApiException('Session agent invalide. Reconnectez-vous.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps a repondre. Reessayez.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Impossible de joindre le serveur. Verifiez votre connexion.',
      );
    }
  }

  dynamic _extractData(http.Response response) {
    final dynamic payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // ── Capture trusted server time from the HTTP Date header ──────────
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        final serverTime = HttpDate.parse(dateHeader);
        NetworkTimeService.instance.updateFromServerTime(serverTime);
      }
      // ───────────────────────────────────────────────────────────────────

      if (payload is Map<String, dynamic> && payload.containsKey('data')) {
        return payload['data'];
      }
      return payload;
    }

    final message = payload is Map<String, dynamic>
        ? payload['message'] as String? ?? 'Une erreur est survenue.'
        : 'Une erreur est survenue.';

    if (response.statusCode == 401) {
      if (message == 'KILL_SWITCH_ACTIVATED') {
        _handleKillSwitch();
        throw const ApiException('Votre session a été révoquée par un administrateur.', 401);
      }
      SessionStorage.clear();
    }

    throw ApiException(message, response.statusCode);
  }

  void _handleKillSwitch() async {
    await SessionStorage.clear();
    await const FlutterSecureStorage().deleteAll();
    try {
      await Hive.deleteFromDisk();
    } catch (_) {}
  }
}
