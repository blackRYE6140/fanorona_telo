import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../game/constants.dart';
import '../../game/game_state.dart';
import '../../network/lan_peer.dart';
import '../../network/network_codec.dart';
import '../game_board.dart';

class NetworkGamePage extends StatefulWidget {
  const NetworkGamePage({
    super.key,
    required this.peer,
    required this.initialState,
    required this.localPlayer,
    required this.localName,
    required this.remoteName,
    this.localAvatarBase64,
    this.remoteAvatarBase64,
  });

  final LanPeer peer;
  final GameState initialState;
  final Player localPlayer;
  final String localName;
  final String remoteName;
  final String? localAvatarBase64;
  final String? remoteAvatarBase64;

  @override
  State<NetworkGamePage> createState() => _NetworkGamePageState();
}

class _NetworkGamePageState extends State<NetworkGamePage> {
  late GameState _gameState;
  StreamSubscription<Map<String, dynamic>>? _peerSubscription;
  bool _peerDisconnected = false;
  GameStatus? _shownGameResult;

  @override
  void initState() {
    super.initState();
    _gameState = widget.initialState;

    _peerSubscription = widget.peer.messages.listen(
      _handleIncomingMessage,
      onDone: () {
        if (!mounted) return;
        setState(() {
          _peerDisconnected = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    widget.peer.dispose();
    super.dispose();
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'state') {
      final rawState = message['state'];
      Map<String, dynamic>? stateMap;
      if (rawState is Map<String, dynamic>) {
        stateMap = rawState;
      } else if (rawState is Map) {
        stateMap = rawState.cast<String, dynamic>();
      }

      if (stateMap != null) {
        final nextState = NetworkCodec.gameStateFromMap(stateMap);
        if (!mounted) return;

        setState(() {
          _gameState = nextState;
        });
        _showWinnerPopupIfNeeded(nextState.status);
      }
      return;
    }

    if (type == 'leave') {
      if (!mounted) return;
      setState(() {
        _peerDisconnected = true;
      });
      return;
    }

    if (type == 'error') {
      if (!mounted) return;
      final messageText = (message['message'] as String?) ?? 'Erreur réseau';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageText)));
    }
  }

  void _handleLocalStateChanged(GameState newState) {
    if (_peerDisconnected || _gameState.currentPlayer != widget.localPlayer) {
      return;
    }

    setState(() {
      _gameState = newState;
    });

    widget.peer.send({
      'type': 'state',
      'state': NetworkCodec.gameStateToMap(newState),
    });

    _showWinnerPopupIfNeeded(newState.status);
  }

  void _showWinnerPopupIfNeeded(GameStatus status) {
    if (status == GameStatus.playing) {
      _shownGameResult = null;
      return;
    }

    if (_shownGameResult == status) {
      return;
    }
    _shownGameResult = status;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWinnerDialog(status);
    });
  }

  bool get _localIsPlayer1 => widget.localPlayer == Player.player1;

  String get _statusText {
    if (_peerDisconnected) {
      return 'Connexion interrompue';
    }

    if (_gameState.status == GameStatus.playing) {
      if (_gameState.currentPlayer == widget.localPlayer) {
        return 'À vous de jouer';
      }
      return 'Tour de ${widget.remoteName}';
    }

    final localWon =
        (_gameState.status == GameStatus.player1Won && _localIsPlayer1) ||
        (_gameState.status == GameStatus.player2Won && !_localIsPlayer1);
    return localWon ? 'Victoire' : 'Défaite';
  }

  Color get _statusColor {
    if (_peerDisconnected) {
      return Colors.orangeAccent;
    }

    if (_gameState.status == GameStatus.playing) {
      return _gameState.currentPlayer == widget.localPlayer
          ? GameConstants.gridColor
          : Colors.white;
    }

    final localWon =
        (_gameState.status == GameStatus.player1Won && _localIsPlayer1) ||
        (_gameState.status == GameStatus.player2Won && !_localIsPlayer1);
    return localWon ? Colors.greenAccent : Colors.redAccent;
  }

  Future<void> _showWinnerDialog(GameStatus status) async {
    final localWon =
        (status == GameStatus.player1Won && _localIsPlayer1) ||
        (status == GameStatus.player2Won && !_localIsPlayer1);

    final title = localWon ? 'Victoire' : 'Défaite';
    final subtitle = localWon
        ? 'Vous avez gagné cette partie réseau.'
        : '${widget.remoteName} gagne la partie.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GameConstants.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _statusColor, width: 2),
          ),
          title: Text(
            title,
            style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
          ),
          content: Text(subtitle, style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Retour'),
            ),
          ],
        );
      },
    );
  }

  ImageProvider<Object>? _avatarFromBase64(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) {
        return null;
      }
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlayerHeader({
    required String name,
    required Player player,
    required bool isLocal,
    required String? avatar,
  }) {
    final currentTurn = _gameState.currentPlayer == player;
    final color = player == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;

    final avatarProvider = _avatarFromBase64(avatar);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(70),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: currentTurn ? color : Colors.white24,
            width: currentTurn ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withAlpha(60),
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Icon(Icons.person, color: Colors.white.withAlpha(220))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isLocal ? 'Vous' : 'Adversaire',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localIsPlayer1 = _localIsPlayer1;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      widget.peer.send({'type': 'leave'});
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'PARTIE RÉSEAU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPlayerHeader(
                    name: localIsPlayer1 ? widget.localName : widget.remoteName,
                    player: Player.player1,
                    isLocal: localIsPlayer1,
                    avatar: localIsPlayer1
                        ? widget.localAvatarBase64
                        : widget.remoteAvatarBase64,
                  ),
                  const SizedBox(width: 8),
                  _buildPlayerHeader(
                    name: localIsPlayer1 ? widget.remoteName : widget.localName,
                    player: Player.player2,
                    isLocal: !localIsPlayer1,
                    avatar: localIsPlayer1
                        ? widget.remoteAvatarBase64
                        : widget.localAvatarBase64,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(70),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _statusColor.withAlpha(170)),
                ),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GameBoard(
                  gameState: _gameState,
                  interactivePlayer: widget.localPlayer,
                  onStateChanged: _handleLocalStateChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
