import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/constants.dart';
import '../../game/game_state.dart';
import '../../network/lan_peer.dart';
import '../../network/lan_utils.dart';
import '../../network/network_codec.dart';
import '../../profile/player_profile.dart';
import '../../profile/profile_service.dart';
import 'network_game_page.dart';

class LanHostPage extends StatefulWidget {
  const LanHostPage({super.key});

  @override
  State<LanHostPage> createState() => _LanHostPageState();
}

class _LanHostPageState extends State<LanHostPage> {
  PlayerProfile _hostProfile = PlayerProfile.fallback;
  String? _hostAvatarBase64;

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  LanPeer? _peer;
  StreamSubscription<Map<String, dynamic>>? _peerSubscription;

  final String _sessionCode = LanUtils.generateSessionCode();
  String _statusText = 'Préparation de la partie...';
  String? _localIp;
  int? _port;

  bool _loading = true;
  bool _guestConnected = false;
  String _guestName = 'Invité';
  String? _guestAvatarBase64;
  bool _hostStarts = true;

  @override
  void initState() {
    super.initState();
    _initHostServer();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _serverSubscription?.cancel();
    _server?.close();

    final peer = _peer;
    if (peer != null) {
      peer.dispose();
    }

    super.dispose();
  }

  Future<void> _initHostServer() async {
    final profile = await ProfileService.loadProfile();
    final avatarBase64 = await ProfileService.avatarPathToBase64(
      profile.avatarPath,
    );
    final localIp = await LanUtils.findLocalNetworkIp();

    if (!mounted) {
      return;
    }

    if (localIp == null) {
      setState(() {
        _loading = false;
        _statusText = 'Impossible de trouver une IP locale (Wi-Fi).';
      });
      return;
    }

    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      if (!mounted) {
        await server.close();
        return;
      }

      setState(() {
        _hostProfile = profile;
        _hostAvatarBase64 = avatarBase64;
        _localIp = localIp;
        _port = server.port;
        _server = server;
        _loading = false;
        _statusText = 'En attente d\'un joueur...';
      });

      _serverSubscription = server.listen(_handleIncomingSocket);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = 'Impossible de démarrer la connexion locale.';
      });
    }
  }

  void _handleIncomingSocket(Socket socket) {
    if (_peer != null) {
      socket.destroy();
      return;
    }

    final peer = LanPeer(socket);
    _peer = peer;

    _peerSubscription = peer.messages.listen(
      (message) {
        final type = message['type'] as String?;

        if (type == 'join') {
          final code = (message['code'] as String?) ?? '';
          if (code != _sessionCode) {
            peer.send({
              'type': 'error',
              'message': 'Code de session invalide.',
            });
            peer.dispose();
            _peer = null;
            return;
          }

          final guestName = (message['name'] as String?)?.trim();
          final guestAvatar = message['avatar'] as String?;

          if (!mounted) {
            return;
          }
          setState(() {
            _guestConnected = true;
            _guestName = guestName == null || guestName.isEmpty
                ? 'Invité'
                : guestName;
            _guestAvatarBase64 = guestAvatar;
            _statusText = 'Joueur connecté: $_guestName';
          });

          peer.send({
            'type': 'join_ack',
            'hostName': _hostProfile.name,
            'hostAvatar': _hostAvatarBase64,
            'message': 'Connecté au host',
          });
        }

        if (type == 'leave') {
          if (!mounted) {
            return;
          }
          setState(() {
            _guestConnected = false;
            _guestName = 'Invité';
            _guestAvatarBase64 = null;
            _statusText = 'Le joueur a quitté la session.';
          });
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _guestConnected = false;
          _guestName = 'Invité';
          _guestAvatarBase64 = null;
          _statusText = 'Connexion fermée. En attente d\'un joueur...';
        });
        _peer = null;
      },
    );
  }

  String get _qrPayload {
    final ip = _localIp;
    final port = _port;
    if (ip == null || port == null) {
      return '';
    }

    return LanUtils.buildQrPayload(ip: ip, port: port, code: _sessionCode);
  }

  Future<void> _startNetworkGame() async {
    final peer = _peer;
    if (peer == null || !_guestConnected) {
      return;
    }

    const hostPlayer = Player.player1;
    final startingPlayer = _hostStarts ? Player.player1 : Player.player2;
    final initialState = GameState.initial().copyWith(
      currentPlayer: startingPlayer,
    );

    peer.send({
      'type': 'start',
      'hostPlayer': NetworkCodec.playerToWire(hostPlayer),
      'state': NetworkCodec.gameStateToMap(initialState),
      'hostName': _hostProfile.name,
      'guestName': _guestName,
      'hostAvatar': _hostAvatarBase64,
      'guestAvatar': _guestAvatarBase64,
    });

    _peerSubscription?.cancel();
    _peerSubscription = null;
    _peer = null;

    if (!mounted) {
      await peer.dispose();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NetworkGamePage(
          peer: peer,
          initialState: initialState,
          localPlayer: hostPlayer,
          localName: _hostProfile.name,
          remoteName: _guestName,
          localAvatarBase64: _hostAvatarBase64,
          remoteAvatarBase64: _guestAvatarBase64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 700;
    final qrSize = (screenWidth - (isSmallScreen ? 56 : 72))
        .clamp(160.0, 220.0)
        .toDouble();
    final guestStartLabel = _guestName.trim().isEmpty
        ? 'Ami'
        : _guestName.trim();

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'CRÉER LA PARTIE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loading)
                  Center(
                    child: CircularProgressIndicator(
                      color: GameConstants.gridColor,
                    ),
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: GameConstants.gridColor.withAlpha(120),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'IP: ${_localIp ?? '-'}    Port: ${_port ?? '-'}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code session: $_sessionCode',
                              style: TextStyle(
                                color: GameConstants.neonBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_qrPayload.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _qrPayload,
                            size: qrSize,
                            version: QrVersions.auto,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                            errorStateBuilder: (context, error) => SizedBox(
                              height: qrSize,
                              width: qrSize,
                              child: const Center(
                                child: Text(
                                  'QR indisponible',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _guestConnected
                        ? Colors.greenAccent
                        : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_guestConnected) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Qui commence ?',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withAlpha(70),
                      selectedForegroundColor: Colors.black,
                      selectedBackgroundColor: const Color.fromARGB(
                        255,
                        128,
                        2,
                        80,
                      ),
                      side: BorderSide(
                        color: Colors.white.withAlpha(160),
                        width: 1.2,
                      ),
                    ),
                    segments: [
                      const ButtonSegment<bool>(
                        value: true,
                        label: Text('Moi'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(
                          guestStartLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {_hostStarts},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _hostStarts = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _startNetworkGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameConstants.neonBlue.withAlpha(40),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: GameConstants.neonBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Démarrer la partie',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
