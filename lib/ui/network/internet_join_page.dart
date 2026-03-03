import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/constants.dart';
import '../../network/internet_settings.dart';
import '../../network/network_codec.dart';
import '../../network/relay_peer.dart';
import '../../profile/player_profile.dart';
import '../../profile/profile_service.dart';
import 'network_game_page.dart';

class InternetJoinPage extends StatefulWidget {
  const InternetJoinPage({super.key});

  @override
  State<InternetJoinPage> createState() => _InternetJoinPageState();
}

class _InternetJoinPageState extends State<InternetJoinPage> {
  PlayerProfile _profile = PlayerProfile.fallback;
  String? _avatarBase64;

  RelayPeer? _peer;
  StreamSubscription<Map<String, dynamic>>? _peerSubscription;

  String? _relayUrl;
  String _statusText = 'Recherche des invitations...';
  String _hostName = 'Host';

  bool _loading = true;
  bool _connecting = false;
  bool _connectedToRelay = false;
  bool _joiningHost = false;
  bool _navigatingToGame = false;
  String? _selectedHostId;

  List<_HostInvite> _availableHosts = const [];

  @override
  void initState() {
    super.initState();
    _initJoin();
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _peerSubscription = null;
    unawaited(_disconnectPeer(sendLeave: !_navigatingToGame));
    super.dispose();
  }

  Future<void> _initJoin() async {
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
      _profile = profile;
      _avatarBase64 = avatarBase64;
      _relayUrl = relayUrl;
      _loading = false;
    });

    await _connectToRelay();
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

  Future<void> _connectToRelay() async {
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

      peer.send({'type': 'discover_hosts', 'name': _profile.name});

      setState(() {
        _connecting = false;
        _connectedToRelay = true;
        _joiningHost = false;
        _selectedHostId = null;
        _statusText = 'Choisissez un ami dans la liste.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _connectedToRelay = false;
        _joiningHost = false;
        _selectedHostId = null;
        _statusText = 'Connexion relay impossible.';
      });
    }
  }

  Future<void> _joinHost(_HostInvite host) async {
    final peer = _peer;
    if (peer == null ||
        !_connectedToRelay ||
        _joiningHost ||
        _navigatingToGame) {
      return;
    }

    setState(() {
      _joiningHost = true;
      _selectedHostId = host.id;
      _statusText = 'Connexion à ${host.name} (${host.id})...';
    });

    peer.send({
      'type': 'join_host',
      'hostId': host.id,
      'name': _profile.name,
      'avatar': _avatarBase64,
    });
  }

  void _handlePeerMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'hosts_list') {
      final rawHosts = message['hosts'];
      final invites = <_HostInvite>[];
      if (rawHosts is List) {
        for (final item in rawHosts) {
          if (item is! Map) {
            continue;
          }
          final map = item.cast<String, dynamic>();
          final id = ((map['id'] as String?) ?? '').trim();
          final name = ((map['name'] as String?) ?? 'Host').trim();
          if (id.isEmpty) {
            continue;
          }
          invites.add(_HostInvite(id: id, name: name.isEmpty ? 'Host' : name));
        }
      }

      if (!mounted) {
        return;
      }

      final selectedId = _selectedHostId;
      final selectedStillExists =
          selectedId != null && invites.any((entry) => entry.id == selectedId);

      setState(() {
        _availableHosts = invites;
        if (!selectedStillExists) {
          _selectedHostId = null;
          _joiningHost = false;
          if (!_navigatingToGame && _connectedToRelay) {
            _statusText = invites.isEmpty
                ? 'Aucun ami en mode invitation pour le moment.'
                : 'Choisissez un ami dans la liste.';
          }
        }
      });
      return;
    }

    if (type == 'join_ack') {
      final hostName = (message['hostName'] as String?)?.trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _joiningHost = false;
        _hostName = hostName == null || hostName.isEmpty ? 'Host' : hostName;
        _statusText = 'Connecté à $_hostName. En attente du démarrage...';
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
        setState(() {
          _statusText = 'Données de partie invalides.';
          _joiningHost = false;
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

      final hostName = ((message['hostName'] as String?) ?? 'Host').trim();
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
            remoteName: hostName.isEmpty ? 'Host' : hostName,
            localAvatarBase64: guestAvatar,
            remoteAvatarBase64: hostAvatar,
          ),
        ),
      );
      return;
    }

    if (type == 'leave') {
      if (!mounted || _navigatingToGame) {
        return;
      }
      setState(() {
        _joiningHost = false;
        _selectedHostId = null;
        _statusText = 'Le host a fermé la session.';
      });
      return;
    }

    if (type == 'error') {
      final errorMessage = (message['message'] as String?) ?? 'Erreur réseau';
      if (!mounted) {
        return;
      }
      setState(() {
        _joiningHost = false;
        _selectedHostId = null;
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
      _joiningHost = false;
      _selectedHostId = null;
      _availableHosts = const [];
      _statusText = 'Connexion relay fermée.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

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
                      'REJOINDRE AMIS',
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
                    color: _connectedToRelay
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!_loading && !_connectedToRelay)
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _connectToRelay,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _connecting ? 'Connexion...' : 'Reconnexion relay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameConstants.neonPink.withAlpha(38),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: GameConstants.neonPink),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Invitations disponibles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(190),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _availableHosts.isEmpty
                      ? Center(
                          child: Text(
                            _connectedToRelay
                                ? 'Aucun ami en attente.'
                                : 'Connexion relay requise.',
                            style: TextStyle(
                              color: Colors.white.withAlpha(170),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _availableHosts.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white.withAlpha(40),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final host = _availableHosts[index];
                            final isSelected = _selectedHostId == host.id;

                            return ListTile(
                              onTap: _joiningHost
                                  ? null
                                  : () => _joinHost(host),
                              leading: CircleAvatar(
                                backgroundColor: GameConstants.neonBlue
                                    .withAlpha(40),
                                child: Icon(
                                  Icons.person,
                                  color: GameConstants.neonBlue,
                                ),
                              ),
                              title: Text(
                                host.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${host.id}',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(160),
                                ),
                              ),
                              trailing: isSelected && _joiningHost
                                  ? SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: GameConstants.neonPink,
                                      ),
                                    )
                                  : Icon(
                                      Icons.login,
                                      color: isSelected
                                          ? GameConstants.neonPink
                                          : Colors.white70,
                                    ),
                            );
                          },
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

class _HostInvite {
  final String id;
  final String name;

  const _HostInvite({required this.id, required this.name});
}
