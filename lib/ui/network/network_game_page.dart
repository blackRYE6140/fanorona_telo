import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../game/constants.dart';
import '../../game/game_state.dart';
import '../../network/game_peer.dart';
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

  final GamePeer peer;
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
  bool _isLeavingGame = false;
  bool _disconnectDialogShown = false;
  String? _incomingChatText;
  Timer? _incomingChatTimer;

  @override
  void initState() {
    super.initState();
    _gameState = widget.initialState;

    _peerSubscription = widget.peer.messages.listen(
      _handleIncomingMessage,
      onDone: () {
        _handlePeerDisconnected(
          'Connexion interrompue. ${widget.remoteName} est déconnecté.',
        );
      },
    );
  }

  @override
  void dispose() {
    _isLeavingGame = true;
    _incomingChatTimer?.cancel();
    _incomingChatTimer = null;
    _peerSubscription?.cancel();
    widget.peer.dispose();
    super.dispose();
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'state') {
      if (_peerDisconnected) {
        return;
      }
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
      _handlePeerDisconnected('${widget.remoteName} a quitté la partie.');
      return;
    }

    if (type == 'chat') {
      final rawText = message['text'];
      final chatText = rawText is String ? rawText.trim() : '';
      if (chatText.isNotEmpty) {
        _showIncomingChat('${widget.remoteName}: $chatText');
      }
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

  void _showIncomingChat(String text) {
    if (!mounted) {
      return;
    }

    _incomingChatTimer?.cancel();
    setState(() {
      _incomingChatText = text;
    });

    _incomingChatTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingChatText = null;
      });
    });
  }

  Future<void> _openMessageComposer() async {
    if (_peerDisconnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connexion interrompue.')));
      return;
    }

    const quickMessages = <String>[
      'Bien joué !',
      'Bonne chance !',
      'À toi de jouer.',
      'Attends un peu.',
      'Merci !',
    ];

    final message =
        await showModalBottomSheet<String>(
          context: context,
          backgroundColor: GameConstants.backgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Message rapide',
                    style: TextStyle(
                      color: GameConstants.gridColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...quickMessages.map((text) {
                    return ListTile(
                      leading: Icon(
                        Icons.sms_outlined,
                        color: GameConstants.neonBlue,
                      ),
                      title: Text(
                        text,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(text),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ) ??
        '';

    if (!mounted) {
      return;
    }

    final text = message.trim();
    if (text.isEmpty) {
      return;
    }

    widget.peer.send({'type': 'chat', 'text': text});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message envoyé')));
  }

  void _handlePeerDisconnected(String reason) {
    if (!mounted || _isLeavingGame || _peerDisconnected) {
      return;
    }

    setState(() {
      _peerDisconnected = true;
    });

    if (_gameState.status != GameStatus.playing) {
      return;
    }
    _showPeerDisconnectedDialog(reason);
  }

  void _showPeerDisconnectedDialog(String reason) {
    if (_disconnectDialogShown || _isLeavingGame) {
      return;
    }
    _disconnectDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isLeavingGame) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope<void>(
            canPop: false,
            child: AlertDialog(
              backgroundColor: GameConstants.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.orangeAccent, width: 1.6),
              ),
              title: const Text(
                'Partie interrompue',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                reason,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Retour'),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || _isLeavingGame) {
        return;
      }
      _isLeavingGame = true;
      Navigator.pop(context);
    });
  }

  Future<bool> _confirmExitGame() async {
    if (_isLeavingGame || _disconnectDialogShown) {
      return false;
    }

    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: GameConstants.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: GameConstants.gridColor, width: 1.3),
              ),
              title: Text(
                'Quitter la partie ?',
                style: TextStyle(
                  color: GameConstants.gridColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                _peerDisconnected
                    ? 'Vous allez retourner au menu.'
                    : 'Votre adversaire sera déconnecté.',
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Quitter'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldExit) {
      return false;
    }

    _isLeavingGame = true;
    if (!_peerDisconnected) {
      widget.peer.send({'type': 'leave'});
    }
    return true;
  }

  Future<void> _handleExitPressed() async {
    final shouldExit = await _confirmExitGame();
    if (!mounted || !shouldExit) {
      return;
    }
    Navigator.pop(context);
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

  Color _pieceColorForPlayer(Player player) {
    return player == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;
  }

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
      return _pieceColorForPlayer(_gameState.currentPlayer);
    }

    final localWon =
        (_gameState.status == GameStatus.player1Won && _localIsPlayer1) ||
        (_gameState.status == GameStatus.player2Won && !_localIsPlayer1);
    return localWon ? Colors.greenAccent : Colors.redAccent;
  }

  void _replayNetworkGame() {
    if (!mounted) {
      return;
    }

    if (_peerDisconnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion interrompue. Rejouer impossible.'),
        ),
      );
      return;
    }

    final restartedState = GameState.initial().copyWith(
      currentPlayer: widget.initialState.currentPlayer,
    );

    setState(() {
      _gameState = restartedState;
      _shownGameResult = null;
    });

    widget.peer.send({
      'type': 'state',
      'state': NetworkCodec.gameStateToMap(restartedState),
    });
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
      builder: (dialogContext) {
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
                Navigator.pop(dialogContext);
                if (!mounted) return;
                _isLeavingGame = true;
                Navigator.pop(context);
              },
              child: const Text('Quitter'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _replayNetworkGame();
              },
              child: const Text('Rejouer'),
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
    final color = _pieceColorForPlayer(player);

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
            const SizedBox(width: 8),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(200),
                border: Border.all(color: color, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(120),
                    blurRadius: 8,
                    spreadRadius: 1,
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

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await _confirmExitGame();
        if (!mounted || !shouldExit) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        backgroundColor: GameConstants.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: _handleExitPressed,
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
                        IconButton(
                          icon: const Icon(Icons.sms_outlined),
                          color: Colors.white70,
                          onPressed: _openMessageComposer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPlayerHeader(
                          name: localIsPlayer1
                              ? widget.localName
                              : widget.remoteName,
                          player: Player.player1,
                          isLocal: localIsPlayer1,
                          avatar: localIsPlayer1
                              ? widget.localAvatarBase64
                              : widget.remoteAvatarBase64,
                        ),
                        const SizedBox(width: 8),
                        _buildPlayerHeader(
                          name: localIsPlayer1
                              ? widget.remoteName
                              : widget.localName,
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
                      child: AbsorbPointer(
                        absorbing: _peerDisconnected,
                        child: GameBoard(
                          gameState: _gameState,
                          interactivePlayer: widget.localPlayer,
                          onStateChanged: _handleLocalStateChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_incomingChatText != null)
                  Positioned(
                    top: 56,
                    left: 6,
                    right: 6,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(190),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: GameConstants.neonBlue.withAlpha(180),
                            ),
                          ),
                          child: Text(
                            _incomingChatText!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
