import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../game/constants.dart';
import '../../network/lan_peer.dart';
import '../../network/lan_utils.dart';
import '../../network/network_codec.dart';
import '../../profile/player_profile.dart';
import '../../profile/profile_service.dart';
import 'network_game_page.dart';

class LanJoinPage extends StatefulWidget {
  const LanJoinPage({super.key});

  @override
  State<LanJoinPage> createState() => _LanJoinPageState();
}

class _LanJoinPageState extends State<LanJoinPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  PlayerProfile _profile = PlayerProfile.fallback;
  String? _avatarBase64;

  LanPeer? _peer;
  StreamSubscription<Map<String, dynamic>>? _peerSubscription;

  bool _loadingProfile = true;
  bool _connecting = false;
  bool _scanLocked = false;
  bool _navigatingToGame = false;

  String _statusText =
      'Scannez le QR code affiché sur le téléphone qui crée la partie.';
  String _hostName = 'Créateur';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _peerSubscription = null;
    unawaited(_disconnectPeer(sendLeave: !_navigatingToGame));
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.loadProfile();
    final avatarBase64 = await ProfileService.avatarPathToBase64(
      profile.avatarPath,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _avatarBase64 = avatarBase64;
      _loadingProfile = false;
    });
  }

  Future<void> _disconnectPeer({bool sendLeave = true}) async {
    final peer = _peer;
    _peer = null;

    await _peerSubscription?.cancel();
    _peerSubscription = null;

    if (peer == null) {
      return;
    }

    if (sendLeave) {
      peer.send({'type': 'leave'});
    }
    await peer.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (!mounted) {
      return;
    }
    if (_loadingProfile || _scanLocked || _connecting || _navigatingToGame) {
      return;
    }

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        rawValue = candidate;
        break;
      }
    }

    if (rawValue == null) {
      return;
    }

    final payload = LanUtils.parseQrPayload(rawValue);
    if (payload == null) {
      setState(() {
        _statusText = 'QR invalide. Veuillez scanner le QR du créateur.';
      });
      return;
    }

    setState(() {
      _scanLocked = true;
      _statusText = 'QR détecté. Connexion à la partie...';
    });
    unawaited(_connectToHost(payload));
  }

  Future<void> _connectToHost(LanJoinPayload payload) async {
    if (_connecting) {
      return;
    }

    setState(() {
      _connecting = true;
      _statusText = 'Connexion à ${payload.ip}:${payload.port}...';
    });

    try {
      await _scannerController.stop();
    } catch (_) {}

    try {
      final socket = await Socket.connect(
        payload.ip,
        payload.port,
        timeout: const Duration(seconds: 7),
      );

      if (!mounted) {
        socket.destroy();
        return;
      }

      final peer = LanPeer(socket);
      _peer = peer;

      _peerSubscription = peer.messages.listen(
        _handlePeerMessage,
        onDone: _handlePeerDisconnected,
      );

      peer.send({
        'type': 'join',
        'code': payload.code,
        'name': _profile.name,
        'avatar': _avatarBase64,
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _statusText = 'Connecté. En attente du démarrage...';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connecting = false;
        _scanLocked = false;
        _statusText = 'Connexion impossible. Re-scanner le QR code.';
      });

      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  void _handlePeerMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'join_ack') {
      final hostName = (message['hostName'] as String?)?.trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _hostName = (hostName == null || hostName.isEmpty)
            ? 'Créateur'
            : hostName;
        _statusText =
            'Connecté à $_hostName. Cette personne choisit qui commence.';
      });
      return;
    }

    if (type == 'start') {
      final peer = _peer;
      if (peer == null) {
        return;
      }

      final rawState = message['state'];
      Map<String, dynamic>? stateMap;
      if (rawState is Map<String, dynamic>) {
        stateMap = rawState;
      } else if (rawState is Map) {
        stateMap = rawState.cast<String, dynamic>();
      }

      if (stateMap == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _statusText = 'Données de partie invalides.';
          _scanLocked = false;
        });
        return;
      }

      final hostPlayer = NetworkCodec.playerFromWire(
        (message['hostPlayer'] as String?) ?? 'player1',
      );
      final localPlayer = hostPlayer == Player.player1
          ? Player.player2
          : Player.player1;
      final initialState = NetworkCodec.gameStateFromMap(stateMap);

      final hostName = ((message['hostName'] as String?) ?? 'Créateur').trim();
      final guestName = ((message['guestName'] as String?) ?? _profile.name)
          .trim();
      final hostAvatar = message['hostAvatar'] as String?;
      final guestAvatar = message['guestAvatar'] as String? ?? _avatarBase64;

      _peerSubscription?.cancel();
      _peerSubscription = null;
      _peer = null;
      _navigatingToGame = true;

      if (!mounted) {
        unawaited(peer.dispose());
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NetworkGamePage(
            peer: peer,
            initialState: initialState,
            localPlayer: localPlayer,
            localName: guestName.isEmpty ? _profile.name : guestName,
            remoteName: hostName.isEmpty ? 'Créateur' : hostName,
            localAvatarBase64: guestAvatar,
            remoteAvatarBase64: hostAvatar,
          ),
        ),
      );
      return;
    }

    if (type == 'error') {
      final errorMessage =
          (message['message'] as String?) ?? 'Erreur de connexion.';
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      setState(() {
        _connecting = false;
        _scanLocked = false;
        _statusText = errorMessage;
      });
      unawaited(_disconnectPeer(sendLeave: false));
      unawaited(_scannerController.start());
    }
  }

  void _handlePeerDisconnected() {
    if (!mounted || _navigatingToGame) {
      return;
    }

    setState(() {
      _connecting = false;
      _scanLocked = false;
      _statusText = 'Connexion fermée. Re-scanner le QR code.';
    });

    _peer = null;
    _peerSubscription = null;
    unawaited(_scannerController.start());
  }

  Future<void> _rescan() async {
    await _disconnectPeer(sendLeave: true);
    if (!mounted) {
      return;
    }

    setState(() {
      _connecting = false;
      _scanLocked = false;
      _statusText =
          'Scannez le QR code affiché sur le téléphone qui crée la partie.';
      _hostName = 'Créateur';
    });

    try {
      await _scannerController.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
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
                      'REJOINDRE LA PARTIE',
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
              const SizedBox(height: 10),
              Text(
                'Profil: ${_profile.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(170),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_loadingProfile)
                        Container(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: GameConstants.gridColor,
                            ),
                          ),
                        )
                      else
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleDetect,
                        ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: GameConstants.gridColor.withAlpha(170),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Container(
                              width: isSmallScreen ? 210 : 250,
                              height: isSmallScreen ? 210 : 250,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: GameConstants.neonPink.withAlpha(220),
                                  width: 2.3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: GameConstants.gridColor.withAlpha(120),
                  ),
                ),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _scanLocked ? Colors.greenAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _connecting ? null : _rescan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'Re-scanner QR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameConstants.neonPink.withAlpha(38),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: GameConstants.neonPink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
