import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/storage/session_storage.dart';

class RealtimeNotificationEvent {
  final String eventName;
  final Map<String, dynamic> notification;

  const RealtimeNotificationEvent({
    required this.eventName,
    required this.notification,
  });
}

class RealtimeNotificationService {
  final http.Client _client;
  final StreamController<RealtimeNotificationEvent> _controller =
      StreamController<RealtimeNotificationEvent>.broadcast();

  bool _started = false;
  bool _disposed = false;

  RealtimeNotificationService({http.Client? client})
      : _client = client ?? http.Client();

  Stream<RealtimeNotificationEvent> get stream {
    _ensureStarted();
    return _controller.stream;
  }

  void _ensureStarted() {
    if (_started || _disposed) {
      return;
    }

    _started = true;
    unawaited(_listenLoop());
  }

  Future<void> _listenLoop() async {
    while (!_disposed) {
      final token = await SessionStorage.getToken();
      if (token == null || token.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      try {
        final request = http.Request(
          'GET',
          Uri.parse('${ApiConfig.baseUrl}/notifications/stream'),
        );
        request.headers.addAll({
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Authorization': 'Bearer $token',
        });

        final response = await _client.send(request);
        if (_disposed) {
          break;
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          break;
        }

        if (response.statusCode != 200) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        await _consumeStream(response.stream);
      } catch (_) {
        if (_disposed) {
          break;
        }
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  Future<void> _consumeStream(Stream<List<int>> stream) async {
    var currentEventName = 'message';
    final dataLines = <String>[];

    await for (final line in stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (_disposed) {
        break;
      }

      if (line.isEmpty) {
        _emitEvent(currentEventName, dataLines);
        currentEventName = 'message';
        dataLines.clear();
        continue;
      }

      if (line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('event:')) {
        currentEventName = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    _emitEvent(currentEventName, dataLines);
  }

  void _emitEvent(String eventName, List<String> dataLines) {
    if (dataLines.isEmpty) {
      return;
    }

    final raw = dataLines.join('\n');
    if (raw.isEmpty) {
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = <String, dynamic>{'raw': raw};
    }

    final notification = decoded is Map
        ? Map<String, dynamic>.from(decoded as Map)
        : <String, dynamic>{'raw': raw};

    _controller.add(
      RealtimeNotificationEvent(
        eventName: eventName,
        notification: notification,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _client.close();
    await _controller.close();
  }
}
