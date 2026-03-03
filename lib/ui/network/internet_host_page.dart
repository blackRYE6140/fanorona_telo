import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/constants.dart';
import '../../game/game_state.dart';
import '../../network/internet_settings.dart';
import '../../network/network_codec.dart';
import '../../network/relay_peer.dart';
import '../../profile/player_profile.dart';
import '../../profile/profile_service.dart';
import 'network_game_page.dart';

class InternetHostPage extends StatefulWidget {
  const InternetHostPage({super.key});

  @override
  State<InternetHostPage> createState() => _InternetHostPageState();
}

class _InternetHostPageState extends State<InternetHostPage> {
  PlayerProfile _hostProfile = PlayerProfile.fallback;
  String? _hostAvatarBase64;

  RelayPeer? _peer;
  StreamSubscription<Map<String, dynamic>>? _peerSubscription;

  String? _relayUrl;
  String _hostId = '-';
  String _statusText = 'Initialisation...';

  bool _loading = true;
  bool _connecting = false;
  bool _connectedToRelay = false;
  bool _guestConnected = false;
  bool _navigatingToGame = false;

  String _guestName = 'Invite';
  String? _guestAvatarBase64;
  bool _hostStarts = true;

  @override
  void initState() {
    super.initState();
    _initHost();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _peerSubscription = null;
    unawaited(_disconnectPeer(sendLeave: !_navigatingToGame));
    super.dispose();
  }

  Future<void> _initHost() async {
    final profile = await ProfileService.loadProfile();
    final avatarBase64 = await ProfileService.avatarPathToBase64(
      profile.avatarPath,
    );
    final relayUrl = await InternetSettings.resolveRelayUrl();

    if (!mounted) {
      return;
    }

    if (relayUrl.isEmpty) {
      setState(() {
        _loading = false;
        _statusText =
            'Relay non configuré. Lancez avec --dart-define=FANORONA_RELAY_URL=wss://votre-relay';
      });
      return;
    }

    setState(() {
      _hostProfile = profile;
      _hostAvatarBase64 = avatarBase64;
      _relayUrl = relayUrl;
      _loading = false;
    });

    await _connectAndAnnounce();
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

  Future<void> _connectAndAnnounce() async {
    final relayUrl = _relayUrl;
    if (relayUrl == null || relayUrl.isEmpty || _connecting) {
      return;
    }

    setState(() {
      _connecting = true;
      _statusText = 'Connexion au relay...';
    });

    await _disconnectPeer(sendLeave: false);

    try {
      final peer = await RelayPeer.connect(relayUrl);
      if (!mounted) {
        await peer.dispose();
        return;
      }

      _peer = peer;
      _peerSubscription = peer.messages.listen(
        _handlePeerMessage,
        onDone: _handlePeerDisconnected,
      );

      peer.send({
        'type': 'host_announce',
        'name': _hostProfile.name,
        'avatar': _hostAvatarBase64,
      });

      setState(() {
        _connecting = false;
        _connectedToRelay = true;
        _statusText = 'Relay connecté. Publication de votre invitation...';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _connectedToRelay = false;
        _guestConnected = false;
        _statusText = 'Connexion relay impossible.';
      });
    }
  }

  void _handlePeerMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'host_ready') {
      final hostId =
          ((message['hostId'] as String?) ?? (message['code'] as String?) ?? '')
              .trim();
      if (!mounted) {
        return;
      }
      setState(() {
        if (hostId.isNotEmpty) {
          _hostId = hostId;
        }
        _statusText = 'Invitation active. En attente d\'un ami...';
      });
      return;
    }

    if (type == 'join') {
      final guestName = (message['name'] as String?)?.trim();
      final guestAvatar = message['avatar'] as String?;

      setState(() {
        _guestConnected = true;
        _guestName = guestName == null || guestName.isEmpty
            ? 'Invite'
            : guestName;
        _guestAvatarBase64 = guestAvatar;
        _statusText = 'Joueur connecté: $_guestName';
      });

      _peer?.send({
        'type': 'join_ack',
        'hostName': _hostProfile.name,
        'hostAvatar': _hostAvatarBase64,
        'message': 'Connecté au host internet',
      });
      return;
    }

    if (type == 'leave') {
      setState(() {
        _guestConnected = false;
        _guestName = 'Invite';
        _guestAvatarBase64 = null;
        _statusText = 'Le joueur a quitté. En attente d\'un ami...';
      });
      return;
    }

    if (type == 'error') {
      final errorMessage = (message['message'] as String?) ?? 'Erreur réseau';
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = errorMessage;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _handlePeerDisconnected() {
    if (!mounted || _navigatingToGame) {
      return;
    }

    _peer = null;
    _peerSubscription = null;

    setState(() {
      _connecting = false;
      _connectedToRelay = false;
      _guestConnected = false;
      _guestName = 'Invite';
      _guestAvatarBase64 = null;
      _statusText = 'Connexion relay fermée.';
    });
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
    _navigatingToGame = true;

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

  Future<void> _copyConnectionId() async {
    if (_hostId == '-' || _hostId.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _hostId));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ID de connexion copié')));
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
                      'INVITER AMIS',
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
              const SizedBox(height: 8),
              Text(
                'Profil: ${_hostProfile.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(170),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GameConstants.gridColor.withAlpha(120),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'ID de connexion',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hostId,
                      style: TextStyle(
                        color: GameConstants.neonPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _copyConnectionId,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier ID'),
                    ),
                  ],
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
                  _loading ? 'Chargement...' : _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _guestConnected
                        ? Colors.greenAccent
                        : _connectedToRelay
                        ? Colors.white
                        : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_loading && !_connectedToRelay)
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _connectAndAnnounce,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _connecting ? 'Connexion...' : 'Reconnexion relay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameConstants.neonBlue.withAlpha(40),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: GameConstants.neonBlue),
                    ),
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
                    selectedBackgroundColor: GameConstants.neonBlue,
                    side: BorderSide(
                      color: Colors.white.withAlpha(160),
                      width: 1.2,
                    ),
                  ),
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('Host')),
                    ButtonSegment<bool>(value: false, label: Text('Join')),
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
    );
  }
}
