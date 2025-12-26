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
          name: 'MAÎTRE ABSOLU',
          description: 'Défi extrême - Analyse 7+ coups avec optimisations avancées',
          strength: 5,
          color: GameConstants.masterAIColor, // Utiliser la constante
        );
  
  // ignore: unused_field
  final Random _random = Random();
  final Map<String, _TTEntry> _transpositionTable = {};
  final Map<String, int> _killerMoves = {};
  final Map<String, int> _historyHeuristic = {};
  DateTime? _searchStartTime;
  static const int _maxTimeMs = 5000; // 5 secondes max
  
  // Tables de valeurs positionnelles (sans const pour éviter les problèmes avec GridPosition)
  final Map<GridPosition, int> _centerWeights = {
    GridPosition(1, 1): 4,  // Centre absolu
    GridPosition(0, 1): 2, GridPosition(2, 1): 2,  // Bords verticaux
    GridPosition(1, 0): 2, GridPosition(1, 2): 2,  // Bords horizontaux
    GridPosition(0, 0): 1, GridPosition(2, 0): 1,  // Coins proches
    GridPosition(0, 2): 1, GridPosition(2, 2): 1,  // Coins proches
  };
  
  final Map<GridPosition, int> _positionalValues = {
    GridPosition(1, 1): 100,  // Centre
    GridPosition(0, 1): 40, GridPosition(2, 1): 40,  // Bords verticaux
    GridPosition(1, 0): 40, GridPosition(1, 2): 40,  // Bords horizontaux
    GridPosition(0, 0): 30, GridPosition(2, 0): 30,  // Coins
    GridPosition(0, 2): 30, GridPosition(2, 2): 30,  // Coins
  };
  
  @override
  Future<GridPosition?> getPlacementMove(GameState state) async {
    await think();
    
    // STRATÉGIE DE PLACEMENT ULTRA-AGGRESSIVE
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) return null;
    
    // Évaluation approfondie avec lookahead
    final scoredPositions = await _evaluateAllPlacements(state, emptyPositions);
    
    // Prendre la meilleure position
    scoredPositions.sort((a, b) => b.score.compareTo(a.score));
    
    return scoredPositions.first.position;
  }
  
  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();
    
    _searchStartTime = DateTime.now();
    _killerMoves.clear();
    
    // RECHERCHE ITÉRATIVE APPROFONDIE avec aspiration windows
    AIMove? bestMove;
    int aspirationWindow = 50;
    
    for (int depth = 4; depth <= 8; depth++) {
      final currentBestMove = await _aspirationSearch(
        state,
        depth,
        aspirationWindow,
      );
      
      if (currentBestMove != null) {
        bestMove = currentBestMove;
      }
      
      // Vérifier le temps
      if (_isTimeUp()) break;
      
      // Augmenter la fenêtre d'aspiration pour les profondeurs supérieures
      if (depth >= 6) aspirationWindow = 100;
    }
    
    return bestMove ?? await _emergencyMove(state);
  }
  
  Future<AIMove?> _aspirationSearch(
    GameState state,
    int depth,
    int window,
  ) async {
    final moves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (moves.isEmpty) return null;
    
    // Ordonner avec toutes les heuristiques
    final orderedMoves = _orderMovesWithAllHeuristics(moves, state);
    
    AIMove? bestMove;
    int alpha = -100000;
    int beta = 100000;
    int bestScore = -100000;
    
    // Recherche avec fenêtre d'aspiration
    for (var move in orderedMoves) {
      if (_isTimeUp()) break;
      
      final newState = AIGameLogic.simulateMove(state, move);
      int score;
      
      try {
        score = -await _minimaxWithAllOptimizations(
          newState,
          depth - 1,
          false,
          Player.player2,
          -beta,
          -alpha,
          0, // null move count
        );
      } catch (e) {
        // En cas d'erreur, utiliser une recherche de secours
        score = await _quiescenceSearch(newState, 3, false, Player.player2, -100000, 100000);
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
        alpha = max(alpha, score);
        
        // Store killer move
        _storeKillerMove(move, depth);
        
        // Store history
        _storeHistory(move, depth);
      }
      
      if (score >= beta) {
        // Coup beta - très bon
        _storeKillerMove(move, depth);
        break;
      }
      
      // Recherche avec fenêtre réduite si score trop bas
      if (score < alpha - window) {
        continue; // Recherche échouée, essayer autre chose
      }
    }
    
    return bestMove;
  }
  
  Future<int> _minimaxWithAllOptimizations(
    GameState state,
    int depth,
    bool maximizing,
    Player aiPlayer,
    int alpha,
    int beta,
    int nullMoveCount,
  ) async {
    // Vérifier le temps
    if (_isTimeUp()) return maximizing ? -99999 : 99999;
    
    // Vérifier la table de transposition (avec drapeaux exact/bound)
    final hash = _hashState(state);
    final ttEntry = _transpositionTable[hash];
    if (ttEntry != null && ttEntry.depth >= depth) {
      if (ttEntry.flag == _TTFlag.exact) return ttEntry.score;
      if (ttEntry.flag == _TTFlag.lowerBound && ttEntry.score >= beta) return ttEntry.score;
      if (ttEntry.flag == _TTFlag.upperBound && ttEntry.score <= alpha) return ttEntry.score;
    }
    
    // Condition d'arrêt
    if (depth <= 0 || state.status != GameStatus.playing) {
      return await _quiescenceSearch(state, 3, maximizing, aiPlayer, alpha, beta);
    }
    
    // NULL MOVE PRUNING (optimisation majeure)
    if (nullMoveCount < 2 && 
        depth >= 3 && 
        !_isInCheck(state, aiPlayer) &&
        _hasSufficientMaterial(state)) {
      
      final nullScore = -await _minimaxWithAllOptimizations(
        state,
        depth - 1 - 2, // Réduction agressive
        !maximizing,
        aiPlayer,
        -beta,
        -beta + 1,
        nullMoveCount + 1,
      );
      
      if (nullScore >= beta) {
        _storeTTEntry(hash, depth, beta, _TTFlag.lowerBound);
        return beta;
      }
    }
    
    // RECHERCHE PRINCIPALE
    final currentPlayer = maximizing ? aiPlayer : 
      (aiPlayer == Player.player1 ? Player.player2 : Player.player1);
    
    var moves = AIGameLogic.getMovementMoves(state, currentPlayer);
    if (moves.isEmpty) {
      final score = _evaluateTerminal(state, aiPlayer);
      _storeTTEntry(hash, depth, score, _TTFlag.exact);
      return score;
    }
    
    // Ordonner avec toutes les techniques
    moves = _orderMovesWithAllHeuristics(moves, state);
    
    int bestScore = maximizing ? -100000 : 100000;
    _TTFlag flag = _TTFlag.upperBound;
    
    for (var move in moves) {
      if (_isTimeUp()) break;
      
      final newState = AIGameLogic.simulateMove(state, move);
      final score = await _minimaxWithAllOptimizations(
        newState,
        depth - 1,
        !maximizing,
        aiPlayer,
        maximizing ? alpha : -beta,
        maximizing ? beta : -alpha,
        0,
      );
      
      final adjustedScore = maximizing ? score : -score;
      
      if (maximizing) {
        if (adjustedScore > bestScore) {
          bestScore = adjustedScore;
          if (adjustedScore > alpha) {
            alpha = adjustedScore;
            flag = _TTFlag.exact;
          }
        }
      } else {
        if (adjustedScore < bestScore) {
          bestScore = adjustedScore;
          if (adjustedScore < beta) {
            beta = adjustedScore;
            flag = _TTFlag.exact;
          }
        }
      }
      
      // Élagage alpha-beta avec fenêtre de null window
      if (maximizing) {
        if (bestScore >= beta) {
          _storeKillerMove(move, depth);
          flag = _TTFlag.lowerBound;
          break;
        }
      } else {
        if (bestScore <= alpha) {
          _storeKillerMove(move, depth);
          flag = _TTFlag.upperBound;
          break;
        }
      }
      
      // LATE MOVE REDUCTION
      if (depth >= 3 && moves.indexOf(move) > 6) {
        final reducedDepth = depth - 2;
        if (reducedDepth > 0) {
          final reducedScore = await _minimaxWithAllOptimizations(
            newState,
            reducedDepth,
            !maximizing,
            aiPlayer,
            alpha,
            beta,
            0,
          );
          
          if ((maximizing && reducedScore <= alpha) ||
              (!maximizing && reducedScore >= beta)) {
            continue; // Skip full search
          }
        }
      }
    }
    
    _storeTTEntry(hash, depth, bestScore, flag);
    return bestScore;
  }
  
  Future<int> _quiescenceSearch(
    GameState state,
    int depth,
    bool maximizing,
    Player aiPlayer,
    int alpha,
    int beta,
  ) async {
    // Évaluation statique
    int standPat = _advancedEvaluate(state, aiPlayer);
    
    if (depth <= 0) return standPat;
    
    if (maximizing) {
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;
    } else {
      if (standPat <= alpha) return alpha;
      if (standPat < beta) beta = standPat;
    }
    
    // Générer seulement les coups "volatiles" (créant des menaces)
    final moves = AIGameLogic.getMovementMoves(state, 
      maximizing ? aiPlayer : (aiPlayer == Player.player1 ? Player.player2 : Player.player1));
    
    final volatileMoves = moves.where((move) => _isVolatileMove(move, state)).toList();
    
    if (volatileMoves.isEmpty) return standPat;
    
    // Ordonner par menace
    volatileMoves.sort((a, b) {
      final threatA = _evaluateMoveThreat(a, state);
      final threatB = _evaluateMoveThreat(b, state);
      return threatB.compareTo(threatA);
    });
    
    for (var move in volatileMoves.take(4)) { // Limiter à 4 meilleures menaces
      if (_isTimeUp()) break;
      
      final newState = AIGameLogic.simulateMove(state, move);
      final score = await _quiescenceSearch(
        newState,
        depth - 1,
        !maximizing,
        aiPlayer,
        maximizing ? alpha : -beta,
        maximizing ? beta : -alpha,
      );
      
      if (maximizing) {
        if (score > alpha) alpha = score;
        if (alpha >= beta) break;
      } else {
        if (score < beta) beta = score;
        if (beta <= alpha) break;
      }
    }
    
    return maximizing ? alpha : beta;
  }
  
  // ==================== HEURISTIQUES AVANCÉES ====================
  
  List<AIMove> _orderMovesWithAllHeuristics(List<AIMove> moves, GameState state) {
    // Ordonner par plusieurs critères combinés
    moves.sort((a, b) {
      // 1. Coups de la table de transposition
      final ttScoreA = _getTTMoveScore(a, state);
      final ttScoreB = _getTTMoveScore(b, state);
      if (ttScoreA != ttScoreB) return ttScoreB.compareTo(ttScoreA);
      
      // 2. Coups qui gagnent immédiatement
      final winA = _moveWinsImmediately(a, state);
      final winB = _moveWinsImmediately(b, state);
      if (winA != winB) {
        if (winA && !winB) return -1;
        if (!winA && winB) return 1;
      }
      
      // 3. Killer moves
      final killerA = _isKillerMove(a);
      final killerB = _isKillerMove(b);
      if (killerA != killerB) {
        if (killerA && !killerB) return -1;
        if (!killerA && killerB) return 1;
      }
      
      // 4. Menaces tactiques
      final threatA = _evaluateMoveThreat(a, state);
      final threatB = _evaluateMoveThreat(b, state);
      if (threatA != threatB) return threatB.compareTo(threatA);
      
      // 5. History heuristic
      final historyA = _getHistoryScore(a);
      final historyB = _getHistoryScore(b);
      if (historyA != historyB) return historyB.compareTo(historyA);
      
      // 6. Mobilité
      final mobA = _mobilityGain(a, state);
      final mobB = _mobilityGain(b, state);
      if (mobA != mobB) return mobB.compareTo(mobA);
      
      // 7. Position
      final posA = _positionalScore(a.newPosition);
      final posB = _positionalScore(b.newPosition);
      return posB.compareTo(posA);
    });
    
    return moves;
  }
  
  Future<List<_ScoredPosition>> _evaluateAllPlacements(
    GameState state,
    List<GridPosition> positions,
  ) async {
    final List<_ScoredPosition> scored = [];
    
    for (var pos in positions) {
      // Évaluation multi-critères
      int score = 0;
      
      // 1. Valeur positionnelle absolue
      score += _positionalScore(pos) * 10;
      
      // 2. Formation avec pièces existantes
      score += _formationPotential(pos, state) * 15;
      
      // 3. Blocage de l'adversaire
      score += _blockingPotential(pos, state) * 12;
      
      // 4. Menace future
      score += _futureThreatPotential(pos, state) * 20;
      
      // 5. Contrôle du centre
      score += _centerControl(pos) * 25;
      
      // 6. Lookahead à 1 coup
      final lookaheadScore = await _oneMoveLookahead(pos, state);
      score += lookaheadScore;
      
      scored.add(_ScoredPosition(pos, score));
    }
    
    return scored;
  }
  
  int _advancedEvaluate(GameState state, Player aiPlayer) {
    // ÉVALUATION TRÈS AVANCÉE - plus de 15 facteurs
    
    int score = 0;
    
    // === FACTEURS MATÉRIELS ===
    // 1. Victoire/défaite immédiate
    if (GameLogic.checkWin(state, aiPlayer)) return 1000000;
    if (GameLogic.checkWin(state, aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return -1000000;
    }
    
    // 2. Blocage
    if (state.isPlayerBlocked(aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return 500000; // Adversaire bloqué = presque victoire
    }
    if (state.isPlayerBlocked(aiPlayer)) {
      return -500000; // IA bloquée = presque défaite
    }
    
    // === FACTEURS DYNAMIQUES ===
    // 3. Mobilité différentielle (le plus important)
    final aiMobility = AIGameLogic.getMovementMoves(state, aiPlayer).length;
    final oppMobility = AIGameLogic.getMovementMoves(state, 
      aiPlayer == Player.player1 ? Player.player2 : Player.player1).length;
    score += (aiMobility - oppMobility) * 35;
    
    // 4. Mobilité potentielle (cases adjacentes libres)
    score += _potentialMobility(state, aiPlayer) * 20;
    
    // === FACTEURS POSITIONNELS ===
    // 5. Contrôle du centre
    score += _centerControlEvaluation(state, aiPlayer) * 40;
    
    // 6. Structure de pièces
    score += _pieceStructure(state, aiPlayer) * 25;
    
    // 7. Coordination des pièces
    score += _pieceCoordination(state, aiPlayer) * 30;
    
    // 8. Activité des pièces
    score += _pieceActivity(state, aiPlayer) * 15;
    
    // === FACTEURS STRATÉGIQUES ===
    // 9. Initiative (qui a le tempo)
    score += _tempoEvaluation(state, aiPlayer) * 10;
    
    // 10. Menaces multiples
    score += _multipleThreats(state, aiPlayer) * 50;
    
    // 11. Fourchettes potentielles
    score += _forkPotential(state, aiPlayer) * 40;
    
    // 12. Zugzwang potentiel
    score += _zugzwangPotential(state, aiPlayer) * 35;
    
    // === FACTEURS TACTIQUES ===
    // 13. Pièces en danger
    score -= _piecesInDanger(state, aiPlayer) * 25;
    
    // 14. Menaces immédiates
    score += _immediateThreats(state, aiPlayer) * 60;
    
    // 15. Stabilité positionnelle
    score += _positionalStability(state, aiPlayer) * 20;
    
    return score;
  }
  
  // ==================== MÉTHODES D'ÉVALUATION DÉTAILLÉES ====================
  
  int _centerControlEvaluation(GameState state, Player aiPlayer) {
    int control = 0;
    
    for (var piece in state.pieces) {
      final weight = _centerWeights[piece.position] ?? 0;
      if (piece.player == aiPlayer) {
        control += weight;
      } else {
        control -= weight;
      }
    }
    
    return control;
  }
  
  int _pieceStructure(GameState state, Player aiPlayer) {
    int structure = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    final oppPieces = state.pieces.where((p) => p.player != aiPlayer).toList();
    
    // Bonus pour pièces connectées
    for (var piece in aiPieces) {
      for (var other in aiPieces) {
        if (piece != other) {
          final dx = (piece.position.x - other.position.x).abs();
          final dy = (piece.position.y - other.position.y).abs();
          if (dx <= 1 && dy <= 1) {
            structure += 5; // Pièces adjacentes
          }
        }
      }
    }
    
    // Malus pour pièces adverses trop proches
    for (var aiPiece in aiPieces) {
      for (var oppPiece in oppPieces) {
        final dx = (aiPiece.position.x - oppPiece.position.x).abs();
        final dy = (aiPiece.position.y - oppPiece.position.y).abs();
        if (dx <= 1 && dy <= 1) {
          structure -= 3; // Trop près de l'adversaire
        }
      }
    }
    
    return structure;
  }
  
  int _multipleThreats(GameState state, Player aiPlayer) {
    int threats = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      int pieceThreats = 0;
      final adjacent = PositionUtils.getAdjacentPositions(piece.position);
      
      for (var pos in adjacent) {
        if (!state.isPositionOccupied(pos)) {
          // Simuler le mouvement
          final testState = AIGameLogic.simulateMove(state, AIMove(piece, pos));
          if (GameLogic.checkWin(testState, aiPlayer)) {
            pieceThreats++;
          }
        }
      }
      
      if (pieceThreats >= 2) {
        threats += 30; // Double menace
      } else if (pieceThreats == 1) {
        threats += 10; // Menace simple
      }
    }
    
    return threats;
  }
  
  int _forkPotential(GameState state, Player aiPlayer) {
    int forkScore = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      // Vérifier si la pièce peut créer une fourchette
      final moves = AIGameLogic.getMovementMoves(state, aiPlayer)
          .where((move) => move.piece == piece)
          .toList();
      
      for (var move in moves) {
        final newState = AIGameLogic.simulateMove(state, move);
        // Vérifier si cette nouvelle position crée plusieurs menaces
        final threats = _multipleThreats(newState, aiPlayer);
        if (threats > 20) { // Au moins une double menace
          forkScore += 25;
        }
      }
    }
    
    return forkScore;
  }
  
  // ==================== MÉTHODES UTILITAIRES ====================
  
  bool _isTimeUp() {
    if (_searchStartTime == null) return false;
    return DateTime.now().difference(_searchStartTime!).inMilliseconds > _maxTimeMs;
  }
  
  void _storeKillerMove(AIMove move, int depth) {
    final key = '${move.piece.position.x},${move.piece.position.y}_${move.newPosition.x},${move.newPosition.y}';
    _killerMoves[key] = (_killerMoves[key] ?? 0) + depth * depth;
  }
  
  bool _isKillerMove(AIMove move) {
    final key = '${move.piece.position.x},${move.piece.position.y}_${move.newPosition.x},${move.newPosition.y}';
    return _killerMoves.containsKey(key) && _killerMoves[key]! > 10;
  }
  
  void _storeHistory(AIMove move, int depth) {
    final key = '${move.piece.position.x},${move.piece.position.y}_${move.newPosition.x},${move.newPosition.y}';
    _historyHeuristic[key] = (_historyHeuristic[key] ?? 0) + depth * depth;
  }
  
  int _getHistoryScore(AIMove move) {
    final key = '${move.piece.position.x},${move.piece.position.y}_${move.newPosition.x},${move.newPosition.y}';
    return _historyHeuristic[key] ?? 0;
  }
  
  void _storeTTEntry(String hash, int depth, int score, _TTFlag flag) {
    _transpositionTable[hash] = _TTEntry(depth, score, flag);
    // Limiter la taille de la table
    if (_transpositionTable.length > 10000) {
      final keys = _transpositionTable.keys.toList();
      for (int i = 0; i < 1000; i++) {
        _transpositionTable.remove(keys[i]);
      }
    }
  }
  
  int _getTTMoveScore(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    final hash = _hashState(newState);
    final entry = _transpositionTable[hash];
    return entry?.score ?? 0;
  }
  
  bool _moveWinsImmediately(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    return GameLogic.checkWin(newState, Player.player2);
  }
  
  int _evaluateMoveThreat(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    
    // Vérifier victoire directe
    if (GameLogic.checkWin(newState, Player.player2)) return 1000;
    
    // Vérifier création de menace multiple
    final threats = _multipleThreats(newState, Player.player2);
    
    // Vérifier mobilité améliorée
    final mobility = AIGameLogic.getMovementMoves(newState, Player.player2).length;
    final oldMobility = AIGameLogic.getMovementMoves(state, Player.player2).length;
    final mobilityGain = mobility - oldMobility;
    
    return threats * 10 + mobilityGain * 5;
  }
  
  int _mobilityGain(AIMove move, GameState state) {
    final newState = AIGameLogic.simulateMove(state, move);
    final newMobility = AIGameLogic.getMovementMoves(newState, Player.player2).length;
    final oldMobility = AIGameLogic.getMovementMoves(state, Player.player2).length;
    return newMobility - oldMobility;
  }
  
  int _positionalScore(GridPosition pos) {
    return _positionalValues[pos] ?? 0;
  }
  
  bool _isVolatileMove(AIMove move, GameState state) {
    // Un coup est volatile s'il crée une menace ou bloque l'adversaire
    final newState = AIGameLogic.simulateMove(state, move);
    
    // Crée une menace de victoire
    if (GameLogic.checkWin(newState, move.piece.player)) return true;
    
    // Bloque une menace adverse
    final oldThreats = _immediateThreats(state, 
      move.piece.player == Player.player1 ? Player.player2 : Player.player1);
    final newThreats = _immediateThreats(newState, 
      move.piece.player == Player.player1 ? Player.player2 : Player.player1);
    
    return newThreats < oldThreats;
  }
  
  int _evaluateTerminal(GameState state, Player aiPlayer) {
    if (GameLogic.checkWin(state, aiPlayer)) return 1000000;
    if (GameLogic.checkWin(state, aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return -1000000;
    }
    if (state.isPlayerBlocked(aiPlayer)) return -500000;
    if (state.isPlayerBlocked(aiPlayer == Player.player1 ? Player.player2 : Player.player1)) {
      return 500000;
    }
    return _advancedEvaluate(state, aiPlayer);
  }
  
  bool _isInCheck(GameState state, Player player) {
    // Dans Fanorona, être "en échec" signifie avoir une menace immédiate
    return _immediateThreats(state, player) > 0;
  }
  
  bool _hasSufficientMaterial(GameState state) {
    // Toujours vrai pour Fanorona (toutes pièces égales)
    return true;
  }
  
  int _potentialMobility(GameState state, Player aiPlayer) {
    int potential = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      final adjacent = PositionUtils.getAdjacentPositions(piece.position);
      potential += adjacent.where((pos) => !state.isPositionOccupied(pos)).length;
    }
    
    return potential;
  }
  
  int _pieceCoordination(GameState state, Player aiPlayer) {
    int coordination = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    // Bonus pour pièces qui se protègent mutuellement
    for (var i = 0; i < aiPieces.length; i++) {
      for (var j = i + 1; j < aiPieces.length; j++) {
        final dx = (aiPieces[i].position.x - aiPieces[j].position.x).abs();
        final dy = (aiPieces[i].position.y - aiPieces[j].position.y).abs();
        final distance = dx + dy;
        
        if (distance == 1) {
          coordination += 10; // Adjacent
        } else if (distance == 2) {
          coordination += 5; // À distance de cavalier
        }
      }
    }
    
    return coordination;
  }
  
  int _pieceActivity(GameState state, Player aiPlayer) {
    int activity = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      // Bonus pour pièces au centre
      if (piece.position.x == 1 && piece.position.y == 1) {
        activity += 20;
      }
      
      // Bonus pour pièces avec beaucoup de mouvements
      final moves = AIGameLogic.getMovementMoves(state, aiPlayer)
          .where((move) => move.piece == piece)
          .length;
      activity += moves * 5;
    }
    
    return activity;
  }
  
  int _tempoEvaluation(GameState state, Player aiPlayer) {
    // L'IA a l'initiative si elle a plus d'options
    final aiMoves = AIGameLogic.getMovementMoves(state, aiPlayer).length;
    final oppMoves = AIGameLogic.getMovementMoves(state, 
      aiPlayer == Player.player1 ? Player.player2 : Player.player1).length;
    
    if (aiMoves > oppMoves) return 10;
    if (aiMoves < oppMoves) return -10;
    return 0;
  }
  
  int _zugzwangPotential(GameState state, Player aiPlayer) {
    // Vérifier si l'adversaire risque d'être en zugzwang
    final oppPlayer = aiPlayer == Player.player1 ? Player.player2 : Player.player1;
    final oppMoves = AIGameLogic.getMovementMoves(state, oppPlayer).length;
    
    if (oppMoves <= 1) {
      // L'adversaire a peu de mouvements
      return 30;
    }
    
    return 0;
  }
  
  int _piecesInDanger(GameState state, Player aiPlayer) {
    int danger = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    final oppPlayer = aiPlayer == Player.player1 ? Player.player2 : Player.player1;
    
    for (var piece in aiPieces) {
      // Vérifier si la pièce peut être "capturée" (dans Fanorona, bloquée)
      bool isSafe = true;
      final adjacent = PositionUtils.getAdjacentPositions(piece.position);
      
      for (var pos in adjacent) {
        final oppPiece = state.getPieceAt(pos);
        if (oppPiece != null && oppPiece.player == oppPlayer) {
          // Pièce adverse adjacente - danger potentiel
          isSafe = false;
          break;
        }
      }
      
      if (!isSafe) danger += 15;
    }
    
    return danger;
  }
  
  int _immediateThreats(GameState state, Player player) {
    int threats = 0;
    final pieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in pieces) {
      final moves = AIGameLogic.getMovementMoves(state, player)
          .where((move) => move.piece == piece)
          .toList();
      
      for (var move in moves) {
        final newState = AIGameLogic.simulateMove(state, move);
        if (GameLogic.checkWin(newState, player)) {
          threats++;
        }
      }
    }
    
    return threats;
  }
  
  int _positionalStability(GameState state, Player aiPlayer) {
    int stability = 0;
    final aiPieces = state.pieces.where((p) => p.player == aiPlayer).toList();
    
    for (var piece in aiPieces) {
      // Pièces au centre sont stables
      if (piece.position.x == 1 && piece.position.y == 1) {
        stability += 20;
      }
      
      // Pièces dans les coins sont stables (moins de directions d'attaque)
      if ((piece.position.x == 0 || piece.position.x == 2) &&
          (piece.position.y == 0 || piece.position.y == 2)) {
        stability += 15;
      }
      
      // Pièces avec peu de pièces adverses adjacentes
      final adjacent = PositionUtils.getAdjacentPositions(piece.position);
      int oppAdjacent = 0;
      for (var pos in adjacent) {
        final other = state.getPieceAt(pos);
        if (other != null && other.player != aiPlayer) {
          oppAdjacent++;
        }
      }
      stability -= oppAdjacent * 5;
    }
    
    return stability;
  }
  
  int _formationPotential(GridPosition pos, GameState state) {
    int potential = 0;
    final aiPieces = state.player2Pieces;
    
    for (var piece in aiPieces) {
      final dx = (pos.x - piece.position.x).abs();
      final dy = (pos.y - piece.position.y).abs();
      
      if (dx <= 1 && dy <= 1) {
        potential += 10; // Près d'une pièce alliée
      }
      
      // Bonus pour alignements potentiels
      if (dx == 0 || dy == 0 || dx == dy) {
        potential += 15; // Même ligne/colonne/diagonale
      }
    }
    
    return potential;
  }
  
  int _blockingPotential(GridPosition pos, GameState state) {
    int blocking = 0;
    final oppPieces = state.player1Pieces;
    
    for (var piece in oppPieces) {
      final dx = (pos.x - piece.position.x).abs();
      final dy = (pos.y - piece.position.y).abs();
      
      if (dx <= 1 && dy <= 1) {
        blocking += 8; // Bloque une pièce adverse
      }
      
      // Bloque un alignement potentiel
      final adjacentToOpp = PositionUtils.getAdjacentPositions(piece.position);
      if (adjacentToOpp.contains(pos)) {
        blocking += 12;
      }
    }
    
    return blocking;
  }
  
  int _futureThreatPotential(GridPosition pos, GameState state) {
    // Simuler le placement et voir les menaces futures
    final testState = GameState(
      pieces: [...state.pieces, GamePiece(player: Player.player2, position: pos)],
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    );
    
    return _multipleThreats(testState, Player.player2);
  }
  
  int _centerControl(GridPosition pos) {
    // Distance au centre (inverse)
    final dx = (pos.x - 1).abs();
    final dy = (pos.y - 1).abs();
    final distance = dx + dy;
    
    return (4 - distance) * 10; // Centre = 40, coins = 20, bords = 30
  }
  
  Future<int> _oneMoveLookahead(GridPosition pos, GameState state) async {
    // Simuler et évaluer après un coup adverse
    final testState = GameState(
      pieces: [...state.pieces, GamePiece(player: Player.player2, position: pos)],
      currentPlayer: Player.player1, // L'adversaire joue
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed + 1,
    );
    
    // Évaluer la pire réponse adverse
    int worstScore = 100000;
    final oppMoves = AIGameLogic.getMovementMoves(testState, Player.player1);
    
    for (var move in oppMoves.take(3)) { // Limiter à 3 meilleures réponses
      final newState = AIGameLogic.simulateMove(testState, move);
      final score = _advancedEvaluate(newState, Player.player2);
      if (score < worstScore) worstScore = score;
    }
    
    return worstScore;
  }
  
  Future<AIMove?> _emergencyMove(GameState state) async {
    // En cas d'urgence (temps écoulé), faire le meilleur coup simple
    final moves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (moves.isEmpty) return null;
    
    AIMove? bestMove;
    int bestScore = -100000;
    
    for (var move in moves) {
      final score = _evaluateMoveThreat(move, state);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove;
  }
  
  String _hashState(GameState state) {
    final pieces = state.pieces.map((p) => 
      '${p.player == Player.player1 ? 'R' : 'B'}${p.position.x}${p.position.y}'
    ).toList()..sort();
    
    return '${state.currentPlayer == Player.player1 ? 'P1' : 'P2'}_'
           '${state.phase == GamePhase.placement ? 'P' : 'M'}_'
           '${pieces.join('_')}';
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

// ==================== CLASSES AUXILIAIRES ====================

class _ScoredPosition {
  final GridPosition position;
  final int score;
  
  _ScoredPosition(this.position, this.score);
}

class _TTEntry {
  final int depth;
  final int score;
  final _TTFlag flag;
  
  _TTEntry(this.depth, this.score, this.flag);
}

enum _TTFlag { exact, lowerBound, upperBound }