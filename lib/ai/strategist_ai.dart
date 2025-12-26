import 'dart:async';
import 'dart:math';
import 'fanorona_ai.dart';
import '../game/game_state.dart';
import '../game/ai_game_logic.dart';
import '../game/constants.dart';

class StrategistAI extends FanoronaAI {
  StrategistAI()
      : super(
          name: 'Stratège',
          description: 'Défi équilibré - Analyse 3 coups',
          strength: 3,
          color: GameConstants.strategistColor,
        );
  
  final Random _random = Random();
  
  @override
  Future<GridPosition?> getPlacementMove(GameState state) async {
    await think();
    
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) return null;
    
    // Stratégie de placement intelligente
    // 1. Essayer de prendre le centre
    final center = GridPosition(1, 1);
    if (emptyPositions.contains(center)) {
      return center;
    }
    
    // 2. Prendre un coin adjacent au centre
    final corners = [
      GridPosition(0, 0), GridPosition(2, 0),
      GridPosition(0, 2), GridPosition(2, 2),
    ];
    
    for (var corner in corners) {
      if (emptyPositions.contains(corner)) {
        // Vérifier si le centre est occupé par l'adversaire
        final centerPiece = state.getPieceAt(center);
        if (centerPiece != null && centerPiece.player != Player.player2) {
          return corner; // Bon pour attaquer le centre
        }
      }
    }
    
    // 3. Choisir aléatoirement parmi les meilleures positions
    final goodPositions = emptyPositions.where((pos) {
      // Éviter les bords non stratégiques si possible
      return !(pos.x == 1 && (pos.y == 0 || pos.y == 2)) &&
             !(pos.y == 1 && (pos.x == 0 || pos.x == 2));
    }).toList();
    
    if (goodPositions.isNotEmpty) {
      return goodPositions[_random.nextInt(goodPositions.length)];
    }
    
    // 4. Fallback: position aléatoire
    return emptyPositions[_random.nextInt(emptyPositions.length)];
  }
  
  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();
    
    // Utiliser Minimax avec profondeur limitée
    final bestMove = await AIGameLogic.findBestMove(
      state,
      Player.player2, // L'IA est toujours le joueur 2
      GameConstants.strategistDepth,
      true, // Utiliser élagage alpha-bêta
    );
    
    if (bestMove != null) {
      return bestMove;
    }
    
    // Fallback: mouvement aléatoire
    final playerPieces = state.player2Pieces;
    if (playerPieces.isEmpty) return null;
    
    final shuffledPieces = List<GamePiece>.from(playerPieces)..shuffle();
    
    for (var piece in shuffledPieces) {
      final adjacent = _getAdjacentPositions(piece.position);
      final validMoves = adjacent.where((pos) => !state.isPositionOccupied(pos)).toList();
      
      if (validMoves.isNotEmpty) {
        validMoves.shuffle();
        return AIMove(piece, validMoves.first);
      }
    }
    
    return null;
  }
  
  List<GridPosition> _getEmptyPositions(GameState state) {
    final List<GridPosition> empty = [];
    for (int x = 0; x <= 2; x++) {
      for (int y = 0; y <= 2; y++) {
        final pos = GridPosition(x, y);
        if (!state.isPositionOccupied(pos)) {
          empty.add(pos);
        }
      }
    }
    return empty;
  }
  
  List<GridPosition> _getAdjacentPositions(GridPosition position) {
    // Implémentation simplifiée
    final positions = <GridPosition>[];
    
    // Horizontal et vertical
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        if (dx.abs() == 1 && dy.abs() == 1) {
          // Diagonales seulement depuis centre ou coins
          if (position.x == 1 || position.y == 1) continue;
        }
        
        final newX = position.x + dx;
        final newY = position.y + dy;
        
        if (newX >= 0 && newX <= 2 && newY >= 0 && newY <= 2) {
          positions.add(GridPosition(newX, newY));
        }
      }
    }
    
    return positions;
  }
}