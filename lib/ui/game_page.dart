import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/game_logic.dart';
import '../game/constants.dart';
import '../ai/fanorona_ai.dart';
import 'game_board.dart';

class GamePage extends StatefulWidget {
  final GameMode mode;
  final AIDifficulty? aiDifficulty;
  
  const GamePage({
    super.key,
    required this.mode,
    this.aiDifficulty,
  });
  
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameState _gameState;
  late FanoronaAI? _ai;
  bool _isAIThinking = false;
  bool _playerIsRed = true; // Le joueur est rouge par défaut
  
  @override
  void initState() {
    super.initState();
    _gameState = GameState.initial();
    
    // Initialiser l'IA si en mode vs AI
    if (widget.mode == GameMode.vsAI && widget.aiDifficulty != null) {
      _ai = AIFactory.createAI(widget.aiDifficulty!);
      
      // Si l'IA commence (joueur 2 est bleu)
      if (!_playerIsRed && _gameState.currentPlayer == Player.player2) {
        _startAITurn();
      }
    }
  }
  
  void _handleStateChanged(GameState newState) {
    setState(() {
      _gameState = newState;
    });
    
    // Vérifier si c'est au tour de l'IA après le mouvement du joueur
    if (widget.mode == GameMode.vsAI &&
        _ai != null &&
        _gameState.status == GameStatus.playing &&
        _gameState.currentPlayer == Player.player2) {
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
      if (_gameState.isPlacementPhase) {
        // Phase placement
        final position = await _ai!.getPlacementMove(_gameState);
        if (position != null) {
          final newState = GameLogic.placePiece(_gameState, position);
          setState(() {
            _gameState = newState;
            _isAIThinking = false;
          });
        }
      } else {
        // Phase mouvement
        final move = await _ai!.getMovementMove(_gameState);
        if (move != null) {
          final newState = GameLogic.movePiece(_gameState, move.piece, move.newPosition);
          setState(() {
            _gameState = newState;
            _isAIThinking = false;
          });
        }
      }
    } catch (e) {
      print('Erreur IA: $e');
      setState(() {
        _isAIThinking = false;
      });
    }
  }
  
  void _resetGame() {
    setState(() {
      _gameState = GameState.initial();
      _isAIThinking = false;
    });
    
    // Si l'IA commence
    if (widget.mode == GameMode.vsAI &&
        _ai != null &&
        !_playerIsRed &&
        _gameState.currentPlayer == Player.player2) {
      _startAITurn();
    }
  }
  
  void _switchColors() {
    setState(() {
      _playerIsRed = !_playerIsRed;
    });
    
    // Si on change de couleur, réinitialiser le jeu
    _resetGame();
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
      if (_isAIThinking) {
        return GameConstants.aiThinking;
      }
      
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
  
  Widget _buildAIThinkingOverlay() {
    if (!_isAIThinking || widget.mode != GameMode.vsAI || _ai == null) {
      return const SizedBox();
    }
    
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(150),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: _ai!.color,
                strokeWidth: 4,
              ),
              const SizedBox(height: 20),
              Text(
                _ai!.name,
                style: TextStyle(
                  color: _ai!.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Réfléchit...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _ai!.description,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
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
                  
                  // Bouton pour changer de couleur (seulement en mode vs AI)
                  if (widget.mode == GameMode.vsAI)
                    IconButton(
                      icon: Icon(
                        Icons.color_lens,
                        color: _playerIsRed 
                            ? GameConstants.neonPink 
                            : GameConstants.neonBlue,
                        size: isVerySmallScreen ? 20.0 : 24.0,
                      ),
                      onPressed: _switchColors,
                      tooltip: 'Changer de couleur',
                    ),
                ],
              ),
              
              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
              
              // Plateau de jeu
              Expanded(
                flex: isVerySmallScreen ? 7 : 5,
                child: Stack(
                  children: [
                    GameBoard(
                      gameState: _gameState,
                      onStateChanged: _handleStateChanged,
                    ),
                    _buildAIThinkingOverlay(),
                  ],
                ),
              ),
              
              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
              
              // Infos de jeu
              Container(
                padding: EdgeInsets.all(isVerySmallScreen ? 6.0 : 10.0),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(76),
                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 6.0 : 10.0),
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
                          borderRadius: BorderRadius.circular(isVerySmallScreen ? 6.0 : 8.0),
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
            margin: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 6.0 : 10.0),
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 6.0 : 10.0,
              vertical: isVerySmallScreen ? 4.0 : 6.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(102),
              borderRadius: BorderRadius.circular(isVerySmallScreen ? 4.0 : 6.0),
              border: Border.all(
                color: _statusTextColor.withAlpha(102),
              ),
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
              widget.mode == GameMode.vsAI && !_playerIsRed 
                  ? 'IA' 
                  : 'Rouge',
              _playerIsRed ? GameConstants.neonPink : GameConstants.neonBlue,
              _gameState.player1Pieces.length,
            ),
            SizedBox(height: 4),
            _buildPieceCounter(
              isVerySmallScreen,
              widget.mode == GameMode.vsAI && _playerIsRed 
                  ? 'IA' 
                  : 'Bleu',
              _playerIsRed ? GameConstants.neonBlue : GameConstants.neonPink,
              _gameState.player2Pieces.length,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPieceCounter(bool isVerySmallScreen, String label, Color color, int placed) {
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