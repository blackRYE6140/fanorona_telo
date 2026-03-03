import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'game_peer.dart';

class LanPeer implements GamePeer {
  LanPeer(this.socket) {
    _subscription = socket.listen(
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

  final Socket socket;
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<List<int>>? _subscription;
  String _buffer = '';

  @override
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  void _onData(List<int> data) {
    _buffer += utf8.decode(data, allowMalformed: true);

    while (true) {
      final lineBreakIndex = _buffer.indexOf('\n');
      if (lineBreakIndex < 0) {
        break;
      }

      final line = _buffer.substring(0, lineBreakIndex).trim();
      _buffer = _buffer.substring(lineBreakIndex + 1);

      if (line.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          _messagesController.add(decoded);
        } else if (decoded is Map) {
          _messagesController.add(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        _messagesController.add({
          'type': 'error',
          'message': 'Message JSON invalide reçu.',
        });
      }
    }
  }

  @override
  void send(Map<String, dynamic> message) {
    try {
      socket.write('${jsonEncode(message)}\n');
    } catch (_) {
      // Ignore write errors; connection lifecycle is handled by stream done.
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await socket.flush();
    } catch (_) {}

    try {
      await socket.close();
    } catch (_) {}

    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }
  }
}
