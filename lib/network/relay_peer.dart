import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'game_peer.dart';

class RelayPeer implements GamePeer {
  RelayPeer._(this._channel) {
    _subscription = _channel.stream.listen(
      _onData,
      onError: (Object error, StackTrace stackTrace) {
        if (!_messagesController.isClosed) {
          _messagesController.add({
            'type': 'error',
            'message': error.toString(),
          });
        }
      },
      onDone: () {
        if (!_messagesController.isClosed) {
          _messagesController.close();
        }
      },
      cancelOnError: false,
    );
  }

  final IOWebSocketChannel _channel;
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _subscription;

  static Future<RelayPeer> connect(
    String relayUrl, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse(relayUrl);
    final channel = IOWebSocketChannel.connect(
      uri,
      connectTimeout: timeout,
      pingInterval: const Duration(seconds: 20),
    );
    await channel.ready.timeout(timeout);
    return RelayPeer._(channel);
  }

  @override
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  void _onData(dynamic data) {
    final dynamic decodedRaw;
    try {
      if (data is String) {
        decodedRaw = jsonDecode(data);
      } else if (data is List<int>) {
        decodedRaw = jsonDecode(utf8.decode(data, allowMalformed: true));
      } else {
        _messagesController.add({
          'type': 'error',
          'message': 'Type de message websocket non supporte.',
        });
        return;
      }
    } catch (_) {
      _messagesController.add({
        'type': 'error',
        'message': 'Message websocket JSON invalide.',
      });
      return;
    }

    if (decodedRaw is Map<String, dynamic>) {
      _messagesController.add(decodedRaw);
      return;
    }
    if (decodedRaw is Map) {
      _messagesController.add(decodedRaw.cast<String, dynamic>());
      return;
    }

    _messagesController.add({
      'type': 'error',
      'message': 'Format de message websocket invalide.',
    });
  }

  @override
  void send(Map<String, dynamic> message) {
    try {
      _channel.sink.add(jsonEncode(message));
    } catch (_) {
      // Ignore write errors; lifecycle is handled by stream done.
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel.sink.close(ws_status.goingAway);
    } catch (_) {}

    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }
  }
}
