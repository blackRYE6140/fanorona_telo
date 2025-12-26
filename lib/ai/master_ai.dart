import 'dart:async';
import 'dart:math';
import 'package:fanorona_telo/game/game_logic.dart';

import 'fanorona_ai.dart';
import '../game/game_state.dart';
import '../game/ai_game_logic.dart';
import '../game/constants.dart';
import '../utils/position_utils.dart';

class MasterAI extends FanoronaAI {
  MasterAI()
      : super(
          name: 'Maître',
          description: 'Défi extrême - Analyse 5+ coups',
          strength: 5,
          color: GameConstants.masterColor,
        );
  
  final Random _random = Random();
  final Map<String, int> _transpositionTable = {};
  
  @override
  Future<GridPosition?> getPlacementMove(GameState state) async {
    await think();
    
    // Stratégie de placement experte
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) return null;
    
    // Évaluer chaque position possible
    int bestScore = -10000;
    GridPosition? bestPosition;
    
    for (var pos in emptyPositions) {
      int score = _evaluatePlacementPosition(pos, state);
      
      // Bonus pour positions qui créent des menaces
      if (_createsThreat(pos, state)) {
        score += 50;
      }
      
      // Malus pour positions qui permettent des menaces adverses
      if (_allowsOpponentThreat(pos, state)) {
        score -= 40;
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestPosition = pos;
      } else if (score == bestScore && _random.nextBool()) {
        // Random tie-break
        bestPosition = pos;
      }
    }
    
    return bestPosition ?? emptyPositions[_random.nextInt(emptyPositions.length)];
  }
  
  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();
    
    // Utiliser Minimax avancé avec plus de profondeur
    final bestMove = await _advancedMinimaxSearch(state);
    
    if (bestMove != null) {
      return bestMove;
    }
    
    // Fallback: utiliser la logique de base
    return await AIGameLogic.findBestMove(
      state,
      Player.player2,
      GameConstants.masterDepth,
      true,
    );
  }
  
  Future<AIMove?> _advancedMinimaxSearch(GameState state) async {
    // Recherche itérative approfondie
    final startTime = DateTime.now();
    AIMove? bestMove;
    
    for (int depth = 2; depth <= GameConstants.masterDepth; depth++) {
      final currentBestMove = await _minimaxWithTimeLimit(
        state,
        depth,
        startTime,
      );
      
      if (currentBestMove != null) {
        bestMove = currentBestMove;
      }
      
      // Vérifier le temps
      if (DateTime.now().difference(startTime).inMilliseconds > 3000) {
        break; // Ne pas dépasser 3 secondes
      }
    }
    
    return bestMove;
  }
  
  Future<AIMove?> _minimaxWithTimeLimit(
    GameState state,
    int depth,
    DateTime startTime,
  ) async {
    final moves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (moves.isEmpty) return null;
    
    AIMove? bestMove;
    int bestScore = -100000;
    
    // Ordonner les coups intelligemment
    final orderedMoves = _orderMovesIntelligently(moves, state);
    
    for (var move in orderedMoves) {
      // Vérifier le temps à chaque itération
      if (DateTime.now().difference(startTime).inMilliseconds > 3000) {
        break;
      }
      
      final newState = AIGameLogic.simulateMove(state, move);
      final score = await _minimax(
        newState,
        depth - 1,
        false,
        Player.player2,
        -100000,
        100000,
        startTime,
      );
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove;
  }
  
  Future<int> _minimax(
    GameState state,
    int depth,
    bool maximizing,
    Player aiPlayer,
    int alpha,
    int beta,
    DateTime startTime,
  ) async {
    // Vérifier le temps
    if (DateTime.now().difference(startTime).inMilliseconds > 3000) {
      return maximizing ? -10000 : 10000;
    }
    
    // Vérifier la table de transposition
    final hash = _hashState(state);
    if (_transpositionTable.containsKey(hash) && depth <= 3) {
      return _transpositionTable[hash]!;
    }
    
    // Condition d'arrêt
    if (depth == 0 || state.status != GameStatus.playing) {
      final score = _advancedEvaluate(state, aiPlayer);
      _transpositionTable[hash] = score;
      return score;
    }
    
    final currentPlayer = maximizing ? aiPlayer : 
      (aiPlayer == Player.player1 ? Player.player2 : Player.player1);
    
    final moves = AIGameLogic.getMovementMoves(state, currentPlayer);
    if (moves.isEmpty) {
      final score = maximizing ? -8000 : 8000;
      _transpositionTable[hash] = score;
      return score;
    }
    
    final orderedMoves = maximizing 
        ? _orderMovesIntelligently(moves, state)
        : moves;
    
    if (maximizing) {
      int maxEval = -100000;
      
      for (var move in orderedMoves) {
        final newState = AIGameLogic.simulateMove(state, move);
        final eval = await _minimax(
          newState,
          depth - 1,
          false,
          aiPlayer,
          alpha,
          beta,
          startTime,
        );
        
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        
        if (beta <= alpha) {
          break; // Élagage beta
        }
      }
      
      _transpositionTable[hash] = maxEval;
      return maxEval;
    } else {
      int minEval = 100000;
      
      for (var move in orderedMoves) {
        final newState = AIGameLogic.simulateMove(state, move);
        final eval = await _minimax(
          newState,
          depth - 1,
          true,
          aiPlayer,
          alpha,
          beta,
          startTime,
        );
        
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        
        if (beta <= alpha) {
          break; // Élagage alpha
        }
      }
      
      _transpositionTable[hash] = minEval;
      return minEval;
    }
  }
  
  // Dans la méthode _orderMovesIntelligently, remplacer :
List<AIMove> _orderMovesIntelligently(List<AIMove> moves, GameState state) {
  // Ordonner par plusieurs critères
  moves.sort((a, b) {
    // 1. Coups qui créent des menaces immédiates
    final threatA = _moveCreatesThreat(a, state);
    final threatB = _moveCreatesThreat(b, state);
    if (threatA != threatB) {
      // CORRECTION : Comparer les booléens directement
      // Un coup qui crée une menace vient en premier
      if (threatA && !threatB) return -1;  // a avant b
      if (!threatA && threatB) return 1;   // b avant a
    }
    
    // 2. Coups vers le centre (distance plus petite = meilleur)
    final centerA = _distanceToCenter(a.newPosition);
    final centerB = _distanceToCenter(b.newPosition);
    if (centerA != centerB) return centerA.compareTo(centerB);
    
    // 3. Mobilité après le coup (plus de mobilité = meilleur)
    final mobilityA = _mobilityAfterMove(a, state);
    final mobilityB = _mobilityAfterMove(b, state);
    return mobilityB.compareTo(mobilityA);
  });
  
  return moves;
}
  
  int _advancedEvaluate(GameState state, Player aiPlayer) {
    int score = AIGameLogic.evaluatePosition(state, aiPlayer);
    
    // Facteurs avancés
    score += _evaluatePieceActivity(state, aiPlayer) * 5;
    score += _evaluateControl(state, aiPlayer) * 8;
    score += _evaluateTempo(state, aiPlayer) * 3;
    
    return score;
  }
  
  // Méthodes d'évaluation auxiliaires
  bool _createsThreat(GridPosition pos, GameState state) {
    // Vérifie si placer une pièce ici crée une menace
    final testState = GameState(
      pieces: [...state.pieces, GamePiece(player: Player.player2, position: pos)],
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    );
    
    return GameLogic.checkWin(testState, Player.player2);
  }
  
  bool _allowsOpponentThreat(GridPosition pos, GameState state) {
    // Vérifie si cette position permet à l'adversaire de créer une menace
    final opponent = state.currentPlayer == Player.player1 ? Player.player2 : Player.player1;
    final testState = GameState(
      pieces: [...state.pieces, GamePiece(player: opponent, position: pos)],
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    );
    
    return GameLogic.checkWin(testState, opponent);
  }
  
  int _evaluatePlacementPosition(GridPosition pos, GameState state) {
    int score = 0;
    
    // Centre = meilleur
    if (pos.x == 1 && pos.y == 1) score += 100;
    
    // Coins = bon
    if ((pos.x == 0 || pos.x == 2) && (pos.y == 0 || pos.y == 2)) score += 60;
    
    // Bords centraux = moyen
    if ((pos.x == 1 && (pos.y == 0 || pos.y == 2)) ||
        (pos.y == 1 && (pos.x == 0 || pos.x == 2))) {
      score += 40;
    }
    
    // Proximité aux pièces alliées (pour formation)
    final aiPieces = state.player2Pieces;
    for (var piece in aiPieces) {
      final distance = (pos.x - piece.position.x).abs() + 
                      (pos.y - piece.position.y).abs();
      if (distance == 1) score += 20; // Adjacent à une pièce alliée
    }
    
    // Éloignement des pièces adverses
    final opponentPieces = state.player1Pieces;
    for (var piece in opponentPieces) {
      final distance = (pos.x - piece.position.x).abs() + 
                      (pos.y - piece.position.y).abs();
      if (distance == 1) score -= 15; // Trop près de l'adversaire
    }
    
    return score;
  }
  
  bool _moveCreatesThreat(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    return GameLogic.checkWin(newState, Player.player2);
  }
  
  double _distanceToCenter(GridPosition pos) {
    return ((pos.x - 1).abs() + (pos.y - 1).abs()).toDouble();
  }
  
  int _mobilityAfterMove(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    return AIGameLogic.getMovementMoves(newState, Player.player2).length;
  }
  
  int _evaluatePieceActivity(GameState state, Player aiPlayer) {
    int activity = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      final moves = PositionUtils.getAdjacentPositions(piece.position)
          .where((pos) => !state.isPositionOccupied(pos))
          .length;
      activity += moves;
    }
    
    return activity;
  }
  
  int _evaluateControl(GameState state, Player aiPlayer) {
    int control = 0;
    
    // Contrôle des cases importantes
    for (int x = 0; x <= 2; x++) {
      for (int y = 0; y <= 2; y++) {
        final pos = GridPosition(x, y);
        final piece = state.getPieceAt(pos);
        
        if (piece != null && piece.player == aiPlayer) {
          // Pièce alliée - contrôle positif
          control += 5;
          
          // Contrôle des cases adjacentes
          final adjacent = PositionUtils.getAdjacentPositions(pos);
          control += adjacent.length;
        } else if (piece != null) {
          // Pièce adverse - contrôle négatif
          control -= 3;
        }
      }
    }
    
    return control;
  }
  
  int _evaluateTempo(GameState state, Player aiPlayer) {
    // Évalue qui a l'initiative
    final aiMoves = AIGameLogic.getMovementMoves(state, aiPlayer).length;
    final opponentMoves = AIGameLogic.getMovementMoves(state, 
      aiPlayer == Player.player1 ? Player.player2 : Player.player1).length;
    
    return aiMoves - opponentMoves;
  }
  
  String _hashState(GameState state) {
    // Hash simple de l'état
    final pieces = state.pieces.map((p) => 
      '${p.player == Player.player1 ? 'R' : 'B'}${p.position.x}${p.position.y}'
    ).toList()..sort();
    
    return '${state.currentPlayer == Player.player1 ? 'P1' : 'P2'}_${pieces.join('_')}';
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
}