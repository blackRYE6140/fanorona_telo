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
      return "🎉 Rouge Gagne !";
    } else if (_gameState.status == GameStatus.player2Won) {
      return "🎉 Bleu Gagne !";
    } else {
      return _gameState.currentPlayer == Player.player1
          ? "Tour: Rouge"
          : "Tour: Bleu";
    }
  }
  
  String get _gamePhaseText {
    return _gameState.isPlacementPhase ? "Placement" : "Mouvement";
  }
  
  Color get _currentPlayerColor {
    return _gameState.currentPlayer == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;
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
              // En-tête TRÈS compact
              _buildHeader(isVerySmallScreen),
              
              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
              
              // Plateau de jeu - prend plus d'espace
              Expanded(
                flex: isVerySmallScreen ? 7 : 5,
                child: GameBoard(
                  gameState: _gameState,
                  onStateChanged: _handleStateChanged,
                ),
              ),
              
              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
              
              // Infos ULTRA compactes
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
                child: _buildUltraCompactGameInfo(isVerySmallScreen),
              ),
              
              SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
              
              // Bouton reset compact
              _buildResetButton(isVerySmallScreen),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isVerySmallScreen) {
    return Column(
      children: [
        Text(
          'FANORONA TELO',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 18.0 : 24.0,
            fontWeight: FontWeight.bold,
            color: GameConstants.gridColor,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Jeu Malagasy Traditionnel by blackRYE',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 9.0 : 11.0,
            color: Colors.white.withAlpha(153),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  Widget _buildUltraCompactGameInfo(bool isVerySmallScreen) {
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
                color: _currentPlayerColor.withAlpha(102),
              ),
            ),
            child: Center(
              child: Text(
                _gameStatusText,
                style: TextStyle(
                  color: Colors.white,
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
            _buildMiniPieceCounter(
              isVerySmallScreen,
              GameConstants.neonPink,
              _gameState.player1Pieces.length,
            ),
            SizedBox(height: 4),
            _buildMiniPieceCounter(
              isVerySmallScreen,
              GameConstants.neonBlue,
              _gameState.player2Pieces.length,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMiniPieceCounter(bool isVerySmallScreen, Color color, int placed) {
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
        Text(
          '/${GameConstants.piecesPerPlayer}',
          style: TextStyle(
            color: Colors.white.withAlpha(153),
            fontSize: isVerySmallScreen ? 8.0 : 10.0,
          ),
        ),
      ],
    );
  }
  
  Widget _buildResetButton(bool isVerySmallScreen) {
    return ElevatedButton(
      onPressed: _resetGame,
      style: ElevatedButton.styleFrom(
        backgroundColor: GameConstants.gridColor.withAlpha(51),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isVerySmallScreen ? 8.0 : 12.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 6.0 : 8.0),
          side: BorderSide(color: GameConstants.gridColor),
        ),
        minimumSize: Size.zero, // Important pour les petits écrans
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Important pour éviter l'overflow
        children: [
          Icon(
            Icons.refresh,
            size: isVerySmallScreen ? 14.0 : 18.0,
          ),
          SizedBox(width: isVerySmallScreen ? 4.0 : 6.0),
          Text(
            'Nouvelle Partie',
            style: TextStyle(
              fontSize: isVerySmallScreen ? 11.0 : 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}