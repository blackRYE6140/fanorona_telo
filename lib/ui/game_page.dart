import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/game_logic.dart';
import '../game/constants.dart';
import '../ai/fanorona_ai.dart';
import 'game_board.dart';

class GamePage extends StatefulWidget {
  final GameMode mode;
  final AIDifficulty? aiDifficulty;
  final bool aiStarts;

  const GamePage({
    super.key,
    required this.mode,
    this.aiDifficulty,
    this.aiStarts = false,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameState _gameState;
  late FanoronaAI? _ai;
  bool _isAIThinking = false;
  final bool _playerIsRed = true; // Le joueur est rouge par défaut
  GameStatus? _lastPopupStatus;

  GameState _createInitialState() {
    final initial = GameState.initial();
    if (widget.mode == GameMode.vsAI && widget.aiStarts) {
      return initial.copyWith(currentPlayer: Player.player2);
    }
    return initial;
  }

  @override
  void initState() {
    super.initState();
    _gameState = _createInitialState();

    // Initialiser l'IA si en mode vs AI
    if (widget.mode == GameMode.vsAI && widget.aiDifficulty != null) {
      _ai = AIFactory.createAI(widget.aiDifficulty!);

      // Si l'IA commence, lancer son premier coup après rendu initial.
      if (_gameState.currentPlayer == Player.player2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAITurn();
        });
      }
    }
  }

  void _handleStateChanged(GameState newState) {
    setState(() {
      _gameState = newState;
    });
    _maybeShowWinnerPopup(newState);

    // Vérifier si c'est au tour de l'IA après le mouvement du joueur
    if (widget.mode == GameMode.vsAI &&
        _ai != null &&
        newState.status == GameStatus.playing &&
        newState.currentPlayer == Player.player2) {
      _startAITurn();
    }
  }

  void _startAITurn() async {
    if (_gameState.status != GameStatus.playing ||
        _gameState.currentPlayer != Player.player2 ||
        _isAIThinking) {
      return;
    }

    setState(() {
      _isAIThinking = true;
    });

    try {
      GameState nextState = _gameState;

      if (_gameState.isPlacementPhase) {
        final position = await _ai!.getPlacementMove(_gameState);
        if (position != null) {
          nextState = GameLogic.placePiece(_gameState, position);
        }
      } else {
        final move = await _ai!.getMovementMove(_gameState);
        if (move != null) {
          nextState = GameLogic.movePiece(
            _gameState,
            move.piece,
            move.newPosition,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _gameState = nextState;
        _isAIThinking = false;
      });
      _maybeShowWinnerPopup(nextState);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erreur IA: $e');
      setState(() {
        _isAIThinking = false;
      });
    }
  }

  void _resetGame() {
    setState(() {
      _gameState = _createInitialState();
      _isAIThinking = false;
      _lastPopupStatus = null;
    });

    // Si l'IA commence
    if (widget.mode == GameMode.vsAI &&
        _ai != null &&
        _gameState.currentPlayer == Player.player2) {
      _startAITurn();
    }
  }

  String get _gameStatusText {
    if (_gameState.status == GameStatus.player1Won) {
      return widget.mode == GameMode.vsAI
          ? (_playerIsRed ? GameConstants.youWin : GameConstants.aiWins)
          : GameConstants.player1Wins;
    } else if (_gameState.status == GameStatus.player2Won) {
      return widget.mode == GameMode.vsAI
          ? (_playerIsRed ? GameConstants.aiWins : GameConstants.youWin)
          : GameConstants.player2Wins;
    } else {
      if (_gameState.currentPlayer == Player.player1) {
        return widget.mode == GameMode.vsAI
            ? (_playerIsRed ? GameConstants.yourTurn : GameConstants.aiMove)
            : GameConstants.player1Turn;
      } else {
        return widget.mode == GameMode.vsAI
            ? (_playerIsRed ? GameConstants.aiMove : GameConstants.yourTurn)
            : GameConstants.player2Turn;
      }
    }
  }

  String get _gamePhaseText {
    return _gameState.isPlacementPhase
        ? GameConstants.placementPhase
        : GameConstants.movementPhase;
  }

  Color get _currentPlayerColor {
    if (_isAIThinking && widget.mode == GameMode.vsAI && _ai != null) {
      return _ai!.color;
    }

    return _gameState.currentPlayer == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;
  }

  Color get _statusTextColor {
    if (_gameState.status == GameStatus.player1Won) {
      return _playerIsRed ? GameConstants.neonPink : GameConstants.neonBlue;
    } else if (_gameState.status == GameStatus.player2Won) {
      return _playerIsRed ? GameConstants.neonBlue : GameConstants.neonPink;
    }
    return _currentPlayerColor;
  }

  void _maybeShowWinnerPopup(GameState state) {
    if (state.status == GameStatus.playing) {
      _lastPopupStatus = null;
      return;
    }

    if (_lastPopupStatus == state.status) {
      return;
    }
    _lastPopupStatus = state.status;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWinnerPopup(state.status);
    });
  }

  String _winnerTitle(GameStatus status) {
    if (widget.mode == GameMode.vsAI) {
      final playerWon =
          (status == GameStatus.player1Won && _playerIsRed) ||
          (status == GameStatus.player2Won && !_playerIsRed);
      return playerWon ? 'Victoire' : 'Défaite';
    }
    return status == GameStatus.player1Won
        ? 'Joueur Rouge gagne'
        : 'Joueur Bleu gagne';
  }

  String _winnerSubtitle(GameStatus status) {
    if (widget.mode == GameMode.vsAI) {
      final playerWon =
          (status == GameStatus.player1Won && _playerIsRed) ||
          (status == GameStatus.player2Won && !_playerIsRed);
      return playerWon
          ? 'Très bon jeu. Vous avez dominé la partie.'
          : 'Partie difficile. Rejouez pour prendre votre revanche.';
    }
    return 'La partie est terminée.';
  }

  Color _winnerColor(GameStatus status) {
    if (status == GameStatus.player1Won) {
      return _playerIsRed ? GameConstants.neonPink : GameConstants.neonBlue;
    }
    return _playerIsRed ? GameConstants.neonBlue : GameConstants.neonPink;
  }

  Future<void> _showWinnerPopup(GameStatus status) async {
    final winnerColor = _winnerColor(status);
    final title = _winnerTitle(status);
    final subtitle = _winnerSubtitle(status);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Fin de partie',
      barrierColor: Colors.black.withAlpha(190),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      winnerColor.withAlpha(45),
                      GameConstants.backgroundColor.withAlpha(240),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: winnerColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: winnerColor.withAlpha(90),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: winnerColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: winnerColor.withAlpha(45),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: winnerColor, width: 1.6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Nouvelle Partie',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 500 || screenWidth < 350;
    // ignore: unused_local_variable
    final isSmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallScreen ? 8.0 : 12.0,
            vertical: isVerySmallScreen ? 4.0 : 8.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec bouton retour
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: isVerySmallScreen ? 20.0 : 24.0,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.mode == GameMode.vsAI
                              ? GameConstants.vsAI
                              : GameConstants.vsPlayer,
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 16.0 : 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.mode == GameMode.vsAI && _ai != null)
                          Text(
                            _ai!.name,
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 12.0 : 14.0,
                              color: _ai!.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),

              // Plateau de jeu
              Expanded(
                flex: isVerySmallScreen ? 7 : 5,
                child: GameBoard(
                  gameState: _gameState,
                  onStateChanged: _handleStateChanged,
                ),
              ),

              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),

              // Infos de jeu
              Container(
                padding: EdgeInsets.all(isVerySmallScreen ? 6.0 : 10.0),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(76),
                  borderRadius: BorderRadius.circular(
                    isVerySmallScreen ? 6.0 : 10.0,
                  ),
                  border: Border.all(
                    color: GameConstants.gridColor.withAlpha(76),
                    width: 1,
                  ),
                ),
                child: _buildGameInfo(isVerySmallScreen),
              ),

              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameConstants.gridColor.withAlpha(51),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isVerySmallScreen ? 10.0 : 14.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isVerySmallScreen ? 6.0 : 8.0,
                          ),
                          side: BorderSide(color: GameConstants.gridColor),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: isVerySmallScreen ? 16.0 : 20.0,
                          ),
                          SizedBox(width: isVerySmallScreen ? 6.0 : 8.0),
                          Text(
                            'Nouvelle Partie',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfo(bool isVerySmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Colonne gauche: Phase et Tour
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Phase: ',
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: isVerySmallScreen ? 10.0 : 12.0,
                  ),
                ),
                Text(
                  _gamePhaseText,
                  style: TextStyle(
                    color: _currentPlayerColor,
                    fontSize: isVerySmallScreen ? 10.0 : 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Tour: ',
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: isVerySmallScreen ? 10.0 : 12.0,
                  ),
                ),
                Text(
                  '${_gameState.turnsPlayed + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVerySmallScreen ? 14.0 : 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Colonne centre: Statut
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 6.0 : 10.0,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 6.0 : 10.0,
              vertical: isVerySmallScreen ? 4.0 : 6.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(102),
              borderRadius: BorderRadius.circular(
                isVerySmallScreen ? 4.0 : 6.0,
              ),
              border: Border.all(color: _statusTextColor.withAlpha(102)),
            ),
            child: Center(
              child: Text(
                _gameStatusText,
                style: TextStyle(
                  color: _statusTextColor,
                  fontSize: isVerySmallScreen ? 10.0 : 12.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),

        // Colonne droite: Compteurs
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildPieceCounter(
              isVerySmallScreen,
              widget.mode == GameMode.vsAI && !_playerIsRed ? 'IA' : 'Rouge',
              _playerIsRed ? GameConstants.neonPink : GameConstants.neonBlue,
              _gameState.player1Pieces.length,
            ),
            SizedBox(height: 4),
            _buildPieceCounter(
              isVerySmallScreen,
              widget.mode == GameMode.vsAI && _playerIsRed ? 'IA' : 'Bleu',
              _playerIsRed ? GameConstants.neonBlue : GameConstants.neonPink,
              _gameState.player2Pieces.length,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPieceCounter(
    bool isVerySmallScreen,
    String label,
    Color color,
    int placed,
  ) {
    return Row(
      children: [
        Container(
          width: isVerySmallScreen ? 14.0 : 18.0,
          height: isVerySmallScreen ? 14.0 : 18.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(76),
            border: Border.all(color: color, width: 1),
          ),
          child: Center(
            child: Text(
              '$placed',
              style: TextStyle(
                color: Colors.white,
                fontSize: isVerySmallScreen ? 8.0 : 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: isVerySmallScreen ? 8.0 : 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '/${GameConstants.piecesPerPlayer}',
              style: TextStyle(
                color: Colors.white.withAlpha(153),
                fontSize: isVerySmallScreen ? 8.0 : 10.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
