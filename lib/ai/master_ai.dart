import 'dart:async';
import 'fanorona_ai.dart';
import '../game/game_state.dart';
import '../game/ai_game_logic.dart';
import '../game/constants.dart';
import '../utils/position_utils.dart';
import 'pattern_recognizer.dart';
import 'game_analyzer.dart';

class MasterAI extends FanoronaAI {
  MasterAI()
      : super(
          name: 'MAÎTRE ABSOLU',
          description: 'Défi extrême - Analyse tactique avancée',
          strength: 5,
          color: GameConstants.masterAIColor,
        );

  final GameAnalyzer _analyzer = GameAnalyzer();
  bool _debugMode = true;

  // Tables de valeurs positionnelles
  final Map<GridPosition, int> _positionalValues = {
    GridPosition(1, 1): 100, // Centre
    GridPosition(0, 1): 40,
    GridPosition(2, 1): 40, // Bords verticaux
    GridPosition(1, 0): 40,
    GridPosition(1, 2): 40, // Bords horizontaux
    GridPosition(0, 0): 30,
    GridPosition(2, 0): 30, // Coins
    GridPosition(0, 2): 30,
    GridPosition(2, 2): 30, // Coins
  };

  @override
  Future<GridPosition?> getPlacementMove(GameState state) async {
    await think();

    if (_debugMode) {
      _analyzer.analyzeCriticalPosition(state, Player.player2);
      print('=== DECISION DE PLACEMENT ===');
    }

    // VÉRIFIER D'ABORD LES MENACES CRITIQUES (toujours prioritaire)
    final opponentThreats = PatternRecognizer.findThreatsToBlock(state, Player.player1);
    if (opponentThreats.isNotEmpty) {
      // Prendre la menace la plus dangereuse
      final allThreats = PatternRecognizer.findAllThreats(state, Player.player1);
      if (allThreats.isNotEmpty) {
        final mostDangerous = allThreats.first;
        if (mostDangerous.emptyPosition != null) {
          if (_debugMode) {
            print('[MASTER_IA] BLOQUE MENACE CRITIQUE sur (${mostDangerous.emptyPosition!.x},${mostDangerous.emptyPosition!.y})');
            print('[MASTER_IA] Danger level: ${mostDangerous.dangerLevel}');
          }
          return mostDangerous.emptyPosition!;
        }
      }
      
      // Fallback simple
      if (_debugMode) print('[MASTER_IA] Blocage menace sur (${opponentThreats.first.x},${opponentThreats.first.y})');
      return opponentThreats.first;
    }

    // Phase d'ouverture (premiers 4 coups) - seulement s'il n'y a pas de menace
    if (state.turnsPlayed < 4) {
      final move = _getOpeningMove(state);

      if (_debugMode) {
        _analyzer.recordMove(state, 'IA Placement: (${move.x},${move.y})');
        print('Choix: (${move.x},${move.y}) - Ouverture\n');
      }

      return move;
    }

    // Phase milieu de jeu
    final move = _getMidgamePlacement(state);

    if (_debugMode) {
      _analyzer.recordMove(state, 'IA Placement: (${move.x},${move.y})');
      print('Choix: (${move.x},${move.y}) - Milieu de jeu\n');
    }

    return move;
  }

  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();

    if (_debugMode) {
      _analyzer.analyzeCriticalPosition(state, Player.player2);
      print('=== DECISION DE MOUVEMENT ===');
    }

    // ========== HIÉRARCHIE DES PRIORITÉS ==========

    // 1. GAGNER IMMÉDIATEMENT
    final winningMoves = PatternRecognizer.findWinningMoves(state, Player.player2);
    if (winningMoves.isNotEmpty) {
      final move = winningMoves.first;

      if (_debugMode) {
        _analyzer.recordMove(state, 'IA Gagne: ${move.piece.position}→(${move.newPosition.x},${move.newPosition.y})');
        print('Choix: Victoire immédiate!\n');
      }

      return move;
    }

    // 2. BLOQUER TOUTES les menaces adverses (AMÉLIORÉ)
    final opponentThreats = PatternRecognizer.findThreatsToBlock(state, Player.player1);
    if (opponentThreats.isNotEmpty) {
      if (_debugMode) {
        print('Menaces détectées: ${opponentThreats.map((t) => '(${t.x},${t.y})').join(', ')}');
      }

      // Essayer de bloquer CHAQUE menace
      for (var threat in opponentThreats) {
        final blockingMove = _findBlockingMove(state, threat);
        if (blockingMove != null) {
          if (_debugMode) {
            _analyzer.recordMove(state, 'IA Bloque: ${blockingMove.piece.position}→(${blockingMove.newPosition.x},${blockingMove.newPosition.y}) menace (${threat.x},${threat.y})');
            print('Choix: Blocage de menace sur (${threat.x},${threat.y})\n');
          }

          return blockingMove;
        }
      }
    }

    // 3. CRÉER UNE FOURCHETTE
    final forkMoves = PatternRecognizer.findForkMoves(state, Player.player2);
    if (forkMoves.isNotEmpty) {
      final move = _selectBestFork(forkMoves, state);

      if (_debugMode) {
        _analyzer.recordMove(state, 'IA Fourchette: ${move.piece.position}→(${move.newPosition.x},${move.newPosition.y})');
        print('Choix: Création de fourchette\n');
      }

      return move;
    }

    // 4. MEILLEUR COUP STRATÉGIQUE
    final move = _getBestStrategicMove(state);

    if (_debugMode && move != null) {
      _analyzer.recordMove(state, 'IA Stratégique: ${move.piece.position}→(${move.newPosition.x},${move.newPosition.y})');
      print('Choix: Meilleur coup stratégique\n');
    }

    return move;
  }

  // ==================== MÉTHODES DE PLACEMENT ====================

  GridPosition _getOpeningMove(GameState state) {
  // NOUVELLE LOGIQUE D'OUVERTURE INTELLIGENTE
  
    // Si c'est le premier coup, prendre le centre
    if (state.pieces.isEmpty) {
      return GridPosition(1, 1);
    }
    
    // Vérifier si l'adversaire a pris le centre
    final center = GridPosition(1, 1);
    final centerPiece = state.getPieceAt(center);
    
    if (centerPiece?.player == Player.player1) {
      // L'adversaire a le centre - prendre un COIN
      final corners = [
        GridPosition(0, 0), GridPosition(2, 0),
        GridPosition(0, 2), GridPosition(2, 2),
      ];
      
      // Prendre le premier coin disponible
      for (var corner in corners) {
        if (!state.isPositionOccupied(corner)) {
          if (_debugMode) print('[MASTER_IA] Réponse: coin (${corner.x},${corner.y}) contre centre adverse');
          return corner;
        }
      }
    }
    
    // Si nous avons le centre, prendre un coin adjacent
    if (centerPiece?.player == Player.player2) {
      final corners = [
        GridPosition(0, 0), GridPosition(2, 0),
        GridPosition(0, 2), GridPosition(2, 2),
      ];
      
      for (var corner in corners) {
        if (!state.isPositionOccupied(corner)) {
          if (_debugMode) print('[MASTER_IA] Développement: coin (${corner.x},${corner.y}) depuis centre');
          return corner;
        }
      }
    }
    
    // Règle spéciale: si adversaire prend coin, prendre centre ou coin opposé
    final lastPiece = state.pieces.last;
    if (lastPiece.player == Player.player1) {
      final lastPos = lastPiece.position;
      // Vérifier si c'est un coin
      if ((lastPos.x == 0 || lastPos.x == 2) && (lastPos.y == 0 || lastPos.y == 2)) {
        // 1. Essayer de prendre le centre
        if (!state.isPositionOccupied(center)) {
          if (_debugMode) print('[MASTER_IA] Réponse: centre contre coin adverse (${lastPos.x},${lastPos.y})');
          return center;
        }
        
        // 2. Prendre coin opposé
        final oppositeCorner = GridPosition(2 - lastPos.x, 2 - lastPos.y);
        if (!state.isPositionOccupied(oppositeCorner)) {
          if (_debugMode) print('[MASTER_IA] Réponse: coin opposé (${oppositeCorner.x},${oppositeCorner.y})');
          return oppositeCorner;
        }
      }
    }
    
    // Sinon, prendre la meilleure position disponible
    return _getBestAvailablePosition(state);
  }

  GridPosition _getBestAvailablePosition(GameState state) {
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) return GridPosition(0, 0);
    
    // Priorité : coins > bords
    final corners = [
      GridPosition(0, 0), GridPosition(2, 0),
      GridPosition(0, 2), GridPosition(2, 2),
    ];
    
    final edges = [
      GridPosition(1, 0), GridPosition(0, 1),
      GridPosition(2, 1), GridPosition(1, 2),
    ];
    
    // Essayer un coin d'abord
    for (var corner in corners) {
      if (emptyPositions.contains(corner)) {
        return corner;
      }
    }
    
    // Puis un bord
    for (var edge in edges) {
      if (emptyPositions.contains(edge)) {
        return edge;
      }
    }
    
    // Fallback
    return emptyPositions.first;
  }

  GridPosition _getMidgamePlacement(GameState state) {
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) return GridPosition(0, 0); // Fallback

    // 1. Créer une menace gagnante
    for (var pos in emptyPositions) {
      if (_createsWinningThreat(pos, state)) {
        if (_debugMode) print('[MASTER_IA] Placement gagnant sur: (${pos.x},${pos.y})');
        return pos;
      }
    }

    // 2. Position stratégique
    return _getBestStrategicPosition(state, emptyPositions);
  }

  bool _createsWinningThreat(GridPosition pos, GameState state) {
    final testState = GameState(
      pieces: [...state.pieces, GamePiece(player: Player.player2, position: pos)],
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    );

    return PatternRecognizer.findWinningMoves(testState, Player.player2).isNotEmpty;
  }

  GridPosition _getBestStrategicPosition(GameState state, List<GridPosition> positions) {
    // Évaluer chaque position
    int bestScore = -10000;
    GridPosition bestPosition = positions.first;

    for (var pos in positions) {
      final score = _evaluateStrategicPosition(pos, state);
      if (score > bestScore) {
        bestScore = score;
        bestPosition = pos;
      }
    }

    return bestPosition;
  }

  int _evaluateStrategicPosition(GridPosition pos, GameState state) {
    int score = 0;

    // 1. Valeur positionnelle
    score += _positionalValues[pos] ?? 0;

    // 2. Formation avec pièces alliées
    final aiPieces = state.player2Pieces;
    for (var piece in aiPieces) {
      final distance = (pos.x - piece.position.x).abs() + (pos.y - piece.position.y).abs();
      if (distance == 1) score += 20; // Adjacent
      if (distance == 2) score += 10; // Proche
    }

    // 3. Mobilité future
    final adjacent = PositionUtils.getAdjacentPositions(pos);
    score += adjacent.where((p) => !state.isPositionOccupied(p)).length * 5;

    return score;
  }

  // ==================== MÉTHODES DE MOUVEMENT ====================

  AIMove? _findBlockingMove(GameState state, GridPosition threatPosition) {
    final aiPieces = state.player2Pieces;

    for (var piece in aiPieces) {
      final possibleMoves = _getPossibleMovesForPiece(state, piece);

      // Essayer de se placer sur la menace
      if (possibleMoves.contains(threatPosition)) {
        return AIMove(piece, threatPosition);
      }

      // Chercher un mouvement qui bloque la menace
      for (var move in possibleMoves) {
        final newState = AIGameLogic.simulateMove(state, AIMove(piece, move));
        final newThreats = PatternRecognizer.findThreatsToBlock(newState, Player.player1);
        if (!newThreats.contains(threatPosition)) {
          return AIMove(piece, move);
        }
      }
    }

    return null;
  }

  AIMove _selectBestFork(List<AIMove> forkMoves, GameState state) {
    // Prendre la fourchette qui donne le meilleur score
    AIMove? bestMove;
    int bestScore = -10000;

    for (var move in forkMoves) {
      final newState = AIGameLogic.simulateMove(state, move);
      final score = PatternRecognizer.quickEvaluate(newState, Player.player2);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? forkMoves.first;
  }

  AIMove? _getBestStrategicMove(GameState state) {
    final moves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (moves.isEmpty) return null;

    // Évaluer chaque coup
    AIMove? bestMove;
    int bestScore = -10000;

    for (var move in moves) {
      final newState = AIGameLogic.simulateMove(state, move);
      final score = _evaluateMove(move, newState, state);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? moves.first;
  }

  int _evaluateMove(AIMove move, GameState newState, GameState oldState) {
    int score = 0;
    
    // 1. Évaluation pattern-based
    score += PatternRecognizer.quickEvaluate(newState, Player.player2);
    
    // 2. Mobilité améliorée
    final newMobility = AIGameLogic.getMovementMoves(newState, Player.player2).length;
    final oldMobility = AIGameLogic.getMovementMoves(oldState, Player.player2).length;
    score += (newMobility - oldMobility) * 10;
    
    // 3. Position de la pièce déplacée
    score += _positionalValues[move.newPosition] ?? 0;
    
    // 4. Menaces créées
    final threats = PatternRecognizer.findThreatsToBlock(newState, Player.player1).length;
    score -= threats * 50;
    
    // 5. NOUVEAU: Éviter les positions "saturées" (peu de mouvements futurs)
    final futureMoves = _countFutureMovesFromPosition(newState, move.newPosition);
    score += futureMoves * 20; // Bonus pour positions avec beaucoup de mouvements futurs
    
    return score;
  }

  int _countFutureMovesFromPosition(GameState state, GridPosition position) {
    // Compter combien de mouvements sont possibles depuis cette position
    int count = 0;
    final adjacent = PositionUtils.getAdjacentPositions(position);
    
    for (var pos in adjacent) {
      if (!state.isPositionOccupied(pos)) {
        count++;
      }
    }
    
    return count;
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  List<GridPosition> _getPossibleMovesForPiece(GameState state, GamePiece piece) {
    final List<GridPosition> moves = [];
    final adjacent = PositionUtils.getAdjacentPositions(piece.position);

    for (var pos in adjacent) {
      if (!state.isPositionOccupied(pos)) {
        moves.add(pos);
      }
    }

    return moves;
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

  void printGameAnalysis() {
    if (_debugMode) {
      _analyzer.printGameHistory();
    }
  }
}