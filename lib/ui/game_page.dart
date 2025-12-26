import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/game_logic.dart';
import '../game/constants.dart';
import 'game_board.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameState _gameState;
  
  @override
  void initState() {
    super.initState();
    _gameState = GameState.initial();
  }
  
  void _handleStateChanged(GameState newState) {
    setState(() {
      _gameState = newState;
    });
  }
  
  void _resetGame() {
    setState(() {
      _gameState = GameLogic.resetGame();
    });
  }
  
  String get _gameStatusText {
    if (_gameState.status == GameStatus.player1Won) {
      return GameConstants.player1Wins;
    } else if (_gameState.status == GameStatus.player2Won) {
      return GameConstants.player2Wins;
    } else {
      return _gameState.currentPlayer == Player.player1
          ? GameConstants.player1Turn
          : GameConstants.player2Turn;
    }
  }
  
  String get _gamePhaseText {
    return _gameState.isPlacementPhase
        ? GameConstants.placementPhase
        : GameConstants.movementPhase;
  }
  
  Color get _currentPlayerColor {
    return _gameState.currentPlayer == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête
              _buildHeader(),
              
              const SizedBox(height: 20),
              
              // Plateau de jeu
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GameBoard(
                    gameState: _gameState,
                    onStateChanged: _handleStateChanged,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Infos et statistiques
              _buildGameInfo(),
              
              const SizedBox(height: 20),
              
              // Bouton reset
              _buildResetButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'FANORONA TELO',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: GameConstants.gridColor,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: GameConstants.gridColor.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Jeu Traditionnel Malgache',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GameConstants.gridColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Phase et tour
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phase:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _gamePhaseText,
                    style: TextStyle(
                      color: _currentPlayerColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Tour:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_gameState.turnsPlayed + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Statut du jeu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPlayerColor.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPlayerColor,
                    boxShadow: [
                      BoxShadow(
                        color: _currentPlayerColor.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _gameStatusText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Compteurs de pièces
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPieceCounter(
                'Joueur Rouge',
                GameConstants.neonPink,
                _gameState.player1Pieces.length,
                GameConstants.piecesPerPlayer,
              ),
              _buildPieceCounter(
                'Joueur Bleu',
                GameConstants.neonBlue,
                _gameState.player2Pieces.length,
                GameConstants.piecesPerPlayer,
              ),
            ],
          ),
          
          // Instructions
          if (_gameState.status == GameStatus.playing)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _gameState.isPlacementPhase
                    ? 'Cliquez sur une intersection vide pour placer votre pion'
                    : 'Glissez-déposez vos pions vers les positions adjacentes libres',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPieceCounter(String label, Color color, int placed, int total) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              '$placed/$total',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: _resetGame,
      style: ElevatedButton.styleFrom(
        backgroundColor: GameConstants.gridColor.withOpacity(0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: GameConstants.gridColor),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh, size: 20),
          SizedBox(width: 8),
          Text(
            'Nouvelle Partie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}