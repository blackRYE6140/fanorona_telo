import 'package:fanorona_telo/game/ai_game_logic.dart';

import '../game/game_state.dart';
import '../game/constants.dart';

class PatternRecognizer {
  
  // Patterns gagnants (toutes les lignes/colonnes/diagonales)
  static final List<List<GridPosition>> winningLines = [
    // Lignes horizontales
    [GridPosition(0,0), GridPosition(1,0), GridPosition(2,0)],
    [GridPosition(0,1), GridPosition(1,1), GridPosition(2,1)],
    [GridPosition(0,2), GridPosition(1,2), GridPosition(2,2)],
    
    // Lignes verticales
    [GridPosition(0,0), GridPosition(0,1), GridPosition(0,2)],
    [GridPosition(1,0), GridPosition(1,1), GridPosition(1,2)],
    [GridPosition(2,0), GridPosition(2,1), GridPosition(2,2)],
    
    // Diagonales
    [GridPosition(0,0), GridPosition(1,1), GridPosition(2,2)],
    [GridPosition(2,0), GridPosition(1,1), GridPosition(0,2)],
  ];
  
  // Trouver TOUTES les menaces
  static List<ThreatAnalysis> findAllThreats(GameState state, Player opponent) {
    final List<ThreatAnalysis> allThreats = [];
    
    for (var line in winningLines) {
      final analysis = _analyzeLine(state, line, opponent);
      // CORRECTION : Une menace réelle = 2 pièces adverses + 1 case vide
      if (analysis.opponentCount == 2 && analysis.emptyCount == 1) {
        allThreats.add(analysis);
      }
    }
    
    // Trier par dangerosité
    allThreats.sort((a, b) => b.dangerLevel.compareTo(a.dangerLevel));
    
    return allThreats;
  }
  
  // Trouver les menaces à bloquer
  static List<GridPosition> findThreatsToBlock(GameState state, Player opponent) {
    final threats = findAllThreats(state, opponent);
    
    // Retourner toutes les positions à bloquer
    return threats.map((t) => t.emptyPosition).where((p) => p != null).cast<GridPosition>().toList();
  }
  
  // Analyse détaillée d'une ligne
  static ThreatAnalysis _analyzeLine(GameState state, List<GridPosition> line, Player opponent) {
    int opponentCount = 0;
    int playerCount = 0;
    int emptyCount = 0;
    GridPosition? emptyPosition;
    List<GridPosition> opponentPositions = [];
    
    for (var pos in line) {
      final piece = state.getPieceAt(pos);
      if (piece == null) {
        emptyCount++;
        emptyPosition = pos;
      } else if (piece.player == opponent) {
        opponentCount++;
        opponentPositions.add(pos);
      } else {
        playerCount++;
      }
    }
    
    return ThreatAnalysis(
      line: line,
      isThreat: opponentCount == 2 && emptyCount == 1,
      isEmptyLine: opponentCount == 0 && playerCount == 0,
      emptyPosition: emptyPosition,
      opponentPositions: opponentPositions,
      opponentCount: opponentCount,
      playerCount: playerCount,
      emptyCount: emptyCount,
      dangerLevel: _calculateDangerLevel(opponentCount, emptyCount, line),
    );
  }
  
  // Calculer le niveau de danger d'une menace
  static int _calculateDangerLevel(int opponentCount, int emptyCount, List<GridPosition> line) {
    if (opponentCount == 2 && emptyCount == 1) {
      // Menace immédiate
      int baseScore = 100;
      
      // Bonus pour menace au centre
      if (line.contains(GridPosition(1, 1))) {
        baseScore += 50;
      }
      
      // Bonus pour menace sur ligne multiple
      return baseScore;
    }
    
    if (opponentCount == 1 && emptyCount == 2) {
      // Menace potentielle
      return 30;
    }
    
    return 0;
  }
  
  // Trouve tous les coups gagnants immédiats
  static List<AIMove> findWinningMoves(GameState state, Player player) {
    final List<AIMove> winningMoves = [];
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      final possibleMoves = _getPossibleMovesForPiece(state, piece);
      
      for (var move in possibleMoves) {
        final newState = _simulateMove(state, piece, move);
        
        if (_isWinningState(newState, player)) {
          winningMoves.add(AIMove(piece, move));
        }
      }
    }
    
    return winningMoves;
  }
  
  // Trouve les fourchettes (créer multiple menaces)
  static List<AIMove> findForkMoves(GameState state, Player player) {
    final List<AIMove> forkMoves = [];
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      final possibleMoves = _getPossibleMovesForPiece(state, piece);
      
      for (var move in possibleMoves) {
        final newState = _simulateMove(state, piece, move);
        
        final threatsCreated = _countThreatsCreated(newState, player, piece);
        
        if (threatsCreated >= 2) {
          forkMoves.add(AIMove(piece, move));
        }
      }
    }
    
    return forkMoves;
  }
  
  // Évalue une position rapidement (pour trier les coups)
  static int quickEvaluate(GameState state, Player player) {
    int score = 0;
    
    // 1. Vérifier victoire immédiate
    if (findWinningMoves(state, player).isNotEmpty) {
      return 10000;
    }
    
    // 2. Vérifier menaces adverses (plus de poids)
    final opponent = player == Player.player1 ? Player.player2 : Player.player1;
    final opponentThreats = findThreatsToBlock(state, opponent).length;
    score -= opponentThreats * 1500;
    
    // 3. Compter les menaces que le joueur peut créer
    final playerThreats = _countPotentialThreats(state, player);
    score += playerThreats * 600;
    
    // 4. Contrôle du centre
    final center = GridPosition(1, 1);
    final centerPiece = state.getPieceAt(center);
    if (centerPiece?.player == player) score += 400;
    
    // 5. Mobilité
    final mobility = _calculateMobility(state, player);
    score += mobility * 15;
    
    // 6. Pénalité pour laisser des menaces adverses non bloquées
    final allThreats = findAllThreats(state, opponent);
    final immediateThreats = allThreats.where((t) => t.isThreat).length;
    score -= immediateThreats * 2000;
    
    return score;
  }
  
  // ========== MÉTHODES PRIVÉES ==========
  
  static List<GridPosition> _getPossibleMovesForPiece(GameState state, GamePiece piece) {
    final List<GridPosition> moves = [];
    
    // Vérifier les 8 directions (avec les règles de Fanorona)
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        
        // Règles spéciales Fanorona pour les diagonales
        if (dx.abs() == 1 && dy.abs() == 1) {
          if (piece.position.x == 1 || piece.position.y == 1) {
            // Depuis un bord, pas de diagonale vers autre bord
            continue;
          }
        }
        
        final newX = piece.position.x + dx;
        final newY = piece.position.y + dy;
        
        if (newX >= 0 && newX <= 2 && newY >= 0 && newY <= 2) {
          final newPos = GridPosition(newX, newY);
          if (!state.isPositionOccupied(newPos)) {
            moves.add(newPos);
          }
        }
      }
    }
    
    return moves;
  }
  
  static GameState _simulateMove(GameState state, GamePiece piece, GridPosition newPosition) {
    final newPieces = state.pieces.map((p) {
      if (p == piece) {
        return GamePiece(player: p.player, position: newPosition);
      }
      return p;
    }).toList();
    
    return GameState(
      pieces: newPieces,
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    );
  }
  
  static bool _isWinningState(GameState state, Player player) {
    final playerPositions = state.pieces
        .where((p) => p.player == player)
        .map((p) => p.position)
        .toSet();
    
    for (var line in winningLines) {
      if (line.every((pos) => playerPositions.contains(pos))) {
        return true;
      }
    }
    
    return false;
  }
  
  static int _countThreatsCreated(GameState newState, Player player, GamePiece movedPiece) {
    int threatCount = 0;
    
    for (var line in winningLines) {
      if (line.contains(movedPiece.position)) {
        final piecesOnLine = line.map((pos) => newState.getPieceAt(pos)).toList();
        
        int playerCount = 0;
        int emptyCount = 0;
        
        for (var piece in piecesOnLine) {
          if (piece == null) {
            emptyCount++;
          } else if (piece.player == player) {
            playerCount++;
          }
        }
        
        if (playerCount == 2 && emptyCount == 1) {
          threatCount++;
        }
      }
    }
    
    return threatCount;
  }
  
  static int _countPotentialThreats(GameState state, Player player) {
    int threatCount = 0;
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      final possibleMoves = _getPossibleMovesForPiece(state, piece);
      
      for (var move in possibleMoves) {
        final newState = _simulateMove(state, piece, move);
        if (_countThreatsCreated(newState, player, piece) > 0) {
          threatCount++;
          break;
        }
      }
    }
    
    return threatCount;
  }
  
  static int _calculateMobility(GameState state, Player player) {
    int mobility = 0;
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      mobility += _getPossibleMovesForPiece(state, piece).length;
    }
    
    return mobility;
  }
}

// Analyse détaillée d'une menace
class ThreatAnalysis {
  final List<GridPosition> line;
  final bool isThreat;
  final bool isEmptyLine;
  final GridPosition? emptyPosition;
  final List<GridPosition> opponentPositions;
  final int dangerLevel;
  final int opponentCount;
  final int playerCount;
  final int emptyCount;
  
  ThreatAnalysis({
    required this.line,
    required this.isThreat,
    required this.isEmptyLine,
    required this.emptyPosition,
    required this.opponentPositions,
    required this.dangerLevel,
    required this.opponentCount,
    required this.playerCount,
    required this.emptyCount,
  });
}