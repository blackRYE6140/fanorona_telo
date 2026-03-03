import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _ClientState {
  _ClientState(this.channel);

  final WebSocketChannel channel;

  String displayName = 'Invite';
  String? avatar;

  bool isHost = false;
  String? ownedHostId;
  String? waitingHostId;
  WebSocketChannel? peer;
}

final Map<WebSocketChannel, _ClientState> _clients =
    <WebSocketChannel, _ClientState>{};
final Map<String, _ClientState> _hostsById = <String, _ClientState>{};
final Random _random = Random.secure();

void main() async {
  final portValue = int.tryParse(Platform.environment['PORT'] ?? '');
  final port = portValue ?? 8080;
  final bindAddress = InternetAddress.anyIPv4;

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(
        Cascade()
            .add(
              webSocketHandler(
                _handleSocket,
                pingInterval: const Duration(seconds: 20),
              ),
            )
            .add((Request request) {
              return Response.ok(
                jsonEncode({
                  'service': 'fanorona-relay',
                  'status': 'ok',
                  'clients': _clients.length,
                  'hosts': _hostsById.length,
                }),
                headers: {'content-type': 'application/json'},
              );
            })
            .handler,
      );

  final server = await shelf_io.serve(handler, bindAddress, port);
  stdout.writeln(
    'Fanorona relay running on ws://${server.address.address}:${server.port}',
  );
}

void _handleSocket(WebSocketChannel channel, String? subprotocol) {
  final client = _ClientState(channel);
  _clients[channel] = client;

  channel.stream.listen(
    (dynamic rawData) {
      final message = _decodeMessage(rawData);
      if (message == null) {
        _send(channel, {'type': 'error', 'message': 'Message JSON invalide.'});
        return;
      }

      _handleMessage(client, message);
    },
    onDone: () => _handleDisconnect(client, notifyPeer: true),
    onError: (Object error, StackTrace stackTrace) =>
        _handleDisconnect(client, notifyPeer: true),
    cancelOnError: true,
  );
}

Map<String, dynamic>? _decodeMessage(dynamic rawData) {
  try {
    final dynamic decodedRaw;
    if (rawData is String) {
      decodedRaw = jsonDecode(rawData);
    } else if (rawData is List<int>) {
      decodedRaw = jsonDecode(utf8.decode(rawData, allowMalformed: true));
    } else {
      return null;
    }

    if (decodedRaw is Map<String, dynamic>) {
      return decodedRaw;
    }
    if (decodedRaw is Map) {
      return decodedRaw.cast<String, dynamic>();
    }
    return null;
  } catch (_) {
    return null;
  }
}

void _handleMessage(_ClientState client, Map<String, dynamic> message) {
  final type = message['type'] as String?;
  if (type == null || type.isEmpty) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Type de message manquant.',
    });
    return;
  }

  switch (type) {
    case 'host_announce':
      _handleHostAnnounce(client, message);
      return;
    case 'discover_hosts':
      _handleDiscoverHosts(client, message);
      return;
    case 'join_host':
      _handleJoinHost(client, message);
      return;
    case 'host_create':
      _handleHostCreateLegacy(client, message);
      return;
    case 'join_room':
      _handleJoinRoomLegacy(client, message);
      return;
    case 'leave':
      _handleDisconnect(client, notifyPeer: true);
      return;
    default:
      _relayToPeer(client, message);
      return;
  }
}

void _handleHostAnnounce(_ClientState client, Map<String, dynamic> message) {
  final displayName = (message['name'] as String?)?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    client.displayName = displayName;
  }
  final avatar = message['avatar'] as String?;
  client.avatar = avatar;

  _unpairClient(client, notifyPeer: true);

  final preferredHostId = (message['hostId'] as String?)?.trim();
  final hostId = _activateHostMode(client, preferredHostId: preferredHostId);

  _send(client.channel, {'type': 'host_ready', 'hostId': hostId});
}

void _handleDiscoverHosts(_ClientState client, Map<String, dynamic> message) {
  final displayName = (message['name'] as String?)?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    client.displayName = displayName;
  }

  _sendHostsList(client.channel);
}

void _handleJoinHost(_ClientState client, Map<String, dynamic> message) {
  final hostId = (message['hostId'] as String?)?.trim() ?? '';
  if (hostId.isEmpty) {
    _send(client.channel, {'type': 'error', 'message': 'ID host manquant.'});
    return;
  }

  final host = _hostsById[hostId];
  if (host == null) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Invitation introuvable.',
    });
    return;
  }
  if (identical(host.channel, client.channel)) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Impossible de rejoindre votre propre invitation.',
    });
    return;
  }
  if (host.peer != null) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Cet ami est déjà en partie.',
    });
    return;
  }
  if (client.peer != null) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Vous êtes déjà en partie.',
    });
    return;
  }

  final displayName = (message['name'] as String?)?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    client.displayName = displayName;
  }
  client.avatar = message['avatar'] as String?;

  _removeHostFromList(host);

  host.peer = client.channel;
  client.peer = host.channel;
  client.isHost = false;
  client.ownedHostId = null;
  client.waitingHostId = null;

  _send(host.channel, {
    'type': 'join',
    'hostId': hostId,
    'name': client.displayName,
    'avatar': client.avatar,
  });
}

void _handleHostCreateLegacy(
  _ClientState client,
  Map<String, dynamic> message,
) {
  final code = (message['code'] as String?)?.trim();
  _handleHostAnnounce(client, {
    'type': 'host_announce',
    'hostId': code,
    'name': message['name'],
    'avatar': message['avatar'],
  });
}

void _handleJoinRoomLegacy(_ClientState client, Map<String, dynamic> message) {
  final code = (message['code'] as String?)?.trim();
  _handleJoinHost(client, {
    'type': 'join_host',
    'hostId': code,
    'name': message['name'],
    'avatar': message['avatar'],
  });
}

void _relayToPeer(_ClientState client, Map<String, dynamic> message) {
  final peerChannel = client.peer;
  if (peerChannel == null) {
    _send(client.channel, {
      'type': 'error',
      'message': 'Aucun adversaire connecté.',
    });
    return;
  }

  final peer = _clients[peerChannel];
  if (peer == null) {
    client.peer = null;
    _send(client.channel, {
      'type': 'error',
      'message': 'Adversaire indisponible.',
    });
    if (client.isHost) {
      final restoredHostId = _activateHostMode(
        client,
        preferredHostId: client.ownedHostId,
      );
      _send(client.channel, {'type': 'host_ready', 'hostId': restoredHostId});
    }
    return;
  }

  _send(peer.channel, message);
}

void _handleDisconnect(_ClientState client, {required bool notifyPeer}) {
  if (!_clients.containsKey(client.channel)) {
    return;
  }

  _removeHostFromList(client);
  _unpairClient(client, notifyPeer: notifyPeer);
  _clients.remove(client.channel);
  unawaited(client.channel.sink.close());
}

void _unpairClient(_ClientState client, {required bool notifyPeer}) {
  final peerChannel = client.peer;
  client.peer = null;

  if (peerChannel == null) {
    return;
  }

  final peer = _clients[peerChannel];
  if (peer == null) {
    return;
  }

  peer.peer = null;

  if (notifyPeer) {
    _send(peer.channel, {
      'type': 'leave',
      'message': client.isHost
          ? 'Le host a quitté la session.'
          : 'Le joueur a quitté la session.',
    });
  }

  if (peer.isHost) {
    final restoredHostId = _activateHostMode(
      peer,
      preferredHostId: peer.ownedHostId,
    );
    _send(peer.channel, {'type': 'host_ready', 'hostId': restoredHostId});
  }
}

String _activateHostMode(_ClientState client, {String? preferredHostId}) {
  client.isHost = true;

  _removeHostFromList(client);

  final picked = _pickHostId(preferredHostId: preferredHostId);
  client.ownedHostId = picked;
  client.waitingHostId = picked;
  _hostsById[picked] = client;
  _broadcastHostsList();
  return picked;
}

void _removeHostFromList(_ClientState client) {
  final waitingHostId = client.waitingHostId;
  if (waitingHostId == null) {
    return;
  }

  final mappedClient = _hostsById[waitingHostId];
  if (identical(mappedClient, client)) {
    _hostsById.remove(waitingHostId);
    _broadcastHostsList();
  }
  client.waitingHostId = null;
}

String _pickHostId({String? preferredHostId}) {
  final preferred = (preferredHostId ?? '').trim();
  if (preferred.isNotEmpty) {
    final existing = _hostsById[preferred];
    if (existing == null) {
      return preferred;
    }
  }

  while (true) {
    final code = (_random.nextInt(900000) + 100000).toString();
    if (!_hostsById.containsKey(code)) {
      return code;
    }
  }
}

void _broadcastHostsList() {
  for (final client in _clients.keys.toList()) {
    _sendHostsList(client);
  }
}

void _sendHostsList(WebSocketChannel clientChannel) {
  final hosts =
      _hostsById.entries.map<Map<String, String>>((entry) {
        final host = entry.value;
        return {'id': entry.key, 'name': host.displayName};
      }).toList()..sort((a, b) {
        final nameA = a['name'] ?? '';
        final nameB = b['name'] ?? '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

  _send(clientChannel, {'type': 'hosts_list', 'hosts': hosts});
}

void _send(WebSocketChannel channel, Map<String, dynamic> message) {
  try {
    channel.sink.add(jsonEncode(message));
  } catch (_) {
    // Ignore send errors; disconnect cleanup handles state.
  }
}
