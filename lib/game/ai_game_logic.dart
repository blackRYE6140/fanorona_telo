import 'dart:math';
import 'package:fanorona_telo/game/game_logic.dart';

import 'game_state.dart';
import 'constants.dart';
import '../utils/position_utils.dart';

class AIMove {
  final GamePiece piece;
  final GridPosition newPosition;
  
  AIMove(this.piece, this.newPosition);
  
  @override
  String toString() => '${piece.position} -> $newPosition';
}

class AIGameLogic {
  // Obtenir tous les coups de placement possibles
  static List<GridPosition> getPlacementMoves(GameState state) {
    final List<GridPosition> moves = [];
    
    for (int x = 0; x <= 2; x++) {
      for (int y = 0; y <= 2; y++) {
        final pos = GridPosition(x, y);
        if (!state.isPositionOccupied(pos)) {
          moves.add(pos);
        }
      }
    }
    
    return moves;
  }
  
  // Obtenir tous les coups de mouvement possibles
  static List<AIMove> getMovementMoves(GameState state, Player player) {
    final List<AIMove> moves = [];
    
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      final adjacentPositions = PositionUtils.getAdjacentPositions(piece.position);
      
      for (var newPos in adjacentPositions) {
        if (!state.isPositionOccupied(newPos)) {
          moves.add(AIMove(piece, newPos));
        }
      }
    }
    
    return moves;
  }
  
  // Évaluation basique d'une position
  static int evaluatePosition(GameState state, Player aiPlayer) {
    int score = 0;
    
    // 1. Victoire/défaite immédiate
    if (GameLogic.checkWin(state, aiPlayer)) return 10000;
    if (GameLogic.checkWin(state, aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return -10000;
    }
    
    // 2. Blocage
    if (state.isPlayerBlocked(aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return 9000; // L'adversaire est bloqué
    }
    if (state.isPlayerBlocked(aiPlayer)) {
      return -9000; // L'IA est bloquée
    }
    
    // 3. Mobilité
    final aiMoves = getMovementMoves(state, aiPlayer).length;
    final playerMoves = getMovementMoves(state, 
      aiPlayer == Player.player1 ? Player.player2 : Player.player1).length;
    score += (aiMoves - playerMoves) * 10;
    
    // 4. Position centrale
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    final playerPieces = state.pieces.where((p) => p.player != aiPlayer).toList();
    
    for (var piece in aiPieces) {
      if (piece.position.x == 1 && piece.position.y == 1) {
        score += 30; // Centre
      } else if (piece.position.x == 1 || piece.position.y == 1) {
        score += 15; // Bords centraux
      } else {
        score += 10; // Coins
      }
    }
    
    for (var piece in playerPieces) {
      if (piece.position.x == 1 && piece.position.y == 1) {
        score -= 30; // Centre adverse
      } else if (piece.position.x == 1 || piece.position.y == 1) {
        score -= 15; // Bords centraux adverses
      } else {
        score -= 10; // Coins adverses
      }
    }
    
    return score;
  }
  
  // Ordonner les coups pour meilleur élagage
  static List<AIMove> orderMoves(List<AIMove> moves, GameState state, Player aiPlayer) {
    // Trie les coups par évaluation heuristique
    moves.sort((a, b) {
      // Simuler les coups et évaluer
      final stateA = simulateMove(state, a);
      final stateB = simulateMove(state, b);
      
      final scoreA = evaluatePosition(stateA, aiPlayer);
      final scoreB = evaluatePosition(stateB, aiPlayer);
      
      return scoreB.compareTo(scoreA); // Ordre décroissant
    });
    
    return moves;
  }
  
  // Simuler un coup
  static GameState simulateMove(GameState state, AIMove move) {
    if (state.isPlacementPhase) {
      // Simuler placement (ce n'est pas utilisé pour AIMove)
      return GameLogic.placePiece(state, move.newPosition);
    } else {
      // Simuler mouvement
      return GameLogic.movePiece(state, move.piece, move.newPosition);
    }
  }
  
  // Trouver le meilleur coup avec Minimax
  static Future<AIMove?> findBestMove(
    GameState state, 
    Player aiPlayer,
    int depth,
    bool useAlphaBeta,
  ) async {
    if (state.isPlacementPhase) {
      // Pour le placement, utiliser une stratégie simple
      final moves = getPlacementMoves(state);
      if (moves.isEmpty) return null;
      
      // Priorité: centre, puis coins, puis bords
      moves.sort((a, b) {
        final scoreA = _evaluatePlacement(a);
        final scoreB = _evaluatePlacement(b);
        return scoreB.compareTo(scoreA);
      });
      
      // Retourner le meilleur placement
      return AIMove(
        GamePiece(player: aiPlayer, position: GridPosition(-1, -1)), // Pièce fictive
        moves.first,
      );
    } else {
      // Pour le mouvement, utiliser Minimax
      final moves = getMovementMoves(state, aiPlayer);
      if (moves.isEmpty) return null;
      
      final orderedMoves = orderMoves(List.from(moves), state, aiPlayer);
      
      AIMove? bestMove;
      int bestScore = -100000;
      
      for (var move in orderedMoves) {
        final newState = simulateMove(state, move);
        final score = await _minimax(
          newState,
          depth - 1,
          false,
          aiPlayer,
          -100000,
          100000,
          useAlphaBeta,
        );
        
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }
      
      return bestMove;
    }
  }
  
  static int _evaluatePlacement(GridPosition pos) {
    // Centre = meilleur
    if (pos.x == 1 && pos.y == 1) return 3;
    // Coins = bon
    if ((pos.x == 0 || pos.x == 2) && (pos.y == 0 || pos.y == 2)) return 2;
    // Bords = moins bon
    return 1;
  }
  
  static Future<int> _minimax(
    GameState state,
    int depth,
    bool maximizing,
    Player aiPlayer,
    int alpha,
    int beta,
    bool useAlphaBeta,
  ) async {
    // Condition d'arrêt
    if (depth == 0 || state.status != GameStatus.playing) {
      return evaluatePosition(state, aiPlayer);
    }
    
    final currentPlayer = maximizing ? aiPlayer : 
      (aiPlayer == Player.player1 ? Player.player2 : Player.player1);
    
    final moves = getMovementMoves(state, currentPlayer);
    if (moves.isEmpty) {
      // Pas de mouvements possibles = échec
      return maximizing ? -8000 : 8000;
    }
    
    if (maximizing) {
      int maxEval = -100000;
      final orderedMoves = orderMoves(List.from(moves), state, aiPlayer);
      
      for (var move in orderedMoves) {
        final newState = simulateMove(state, move);
        final eval = await _minimax(
          newState,
          depth - 1,
          false,
          aiPlayer,
          alpha,
          beta,
          useAlphaBeta,
        );
        
        maxEval = max(maxEval, eval);
        
        if (useAlphaBeta) {
          alpha = max(alpha, eval);
          if (beta <= alpha) {
            break; // Élagage beta
          }
        }
      }
      
      return maxEval;
    } else {
      int minEval = 100000;
      final orderedMoves = orderMoves(List.from(moves), state, 
        aiPlayer == Player.player1 ? Player.player2 : Player.player1);
      
      for (var move in orderedMoves) {
        final newState = simulateMove(state, move);
        final eval = await _minimax(
          newState,
          depth - 1,
          true,
          aiPlayer,
          alpha,
          beta,
          useAlphaBeta,
        );
        
        minEval = min(minEval, eval);
        
        if (useAlphaBeta) {
          beta = min(beta, eval);
          if (beta <= alpha) {
            break; // Élagage alpha
          }
        }
      }
      
      return minEval;
    }
  }
}