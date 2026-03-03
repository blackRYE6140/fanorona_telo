import 'dart:math';

import 'package:fanorona_telo/game/game_logic.dart';

import 'constants.dart';
import 'game_state.dart';
import '../utils/position_utils.dart';

typedef PositionEvaluator = int Function(GameState state, Player aiPlayer);

class AIMove {
  final GamePiece piece;
  final GridPosition newPosition;

  AIMove(this.piece, this.newPosition);

  @override
  String toString() => '${piece.position} -> $newPosition';
}

class AIGameLogic {
  static const int _infinity = 100000000;

  static final Map<GridPosition, int> _positionValues = {
    const GridPosition(1, 1): 160,
    const GridPosition(0, 0): 95,
    const GridPosition(2, 0): 95,
    const GridPosition(0, 2): 95,
    const GridPosition(2, 2): 95,
    const GridPosition(1, 0): 70,
    const GridPosition(0, 1): 70,
    const GridPosition(2, 1): 70,
    const GridPosition(1, 2): 70,
  };

  static final List<List<GridPosition>> _winningLines = [
    [
      const GridPosition(0, 0),
      const GridPosition(1, 0),
      const GridPosition(2, 0),
    ],
    [
      const GridPosition(0, 1),
      const GridPosition(1, 1),
      const GridPosition(2, 1),
    ],
    [
      const GridPosition(0, 2),
      const GridPosition(1, 2),
      const GridPosition(2, 2),
    ],
    [
      const GridPosition(0, 0),
      const GridPosition(0, 1),
      const GridPosition(0, 2),
    ],
    [
      const GridPosition(1, 0),
      const GridPosition(1, 1),
      const GridPosition(1, 2),
    ],
    [
      const GridPosition(2, 0),
      const GridPosition(2, 1),
      const GridPosition(2, 2),
    ],
    [
      const GridPosition(0, 0),
      const GridPosition(1, 1),
      const GridPosition(2, 2),
    ],
    [
      const GridPosition(2, 0),
      const GridPosition(1, 1),
      const GridPosition(0, 2),
    ],
  ];

  static final GridPosition _center = const GridPosition(1, 1);

  // Obtenir tous les coups de placement possibles.
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

  // Obtenir tous les coups de mouvement possibles.
  static List<AIMove> getMovementMoves(GameState state, Player player) {
    final List<AIMove> moves = [];

    final playerPieces = state.pieces.where((p) => p.player == player).toList();

    for (var piece in playerPieces) {
      final adjacentPositions = PositionUtils.getAdjacentPositions(
        piece.position,
      );

      for (var newPos in adjacentPositions) {
        if (!state.isPositionOccupied(newPos)) {
          moves.add(AIMove(piece, newPos));
        }
      }
    }

    return moves;
  }

  // Évaluation tactique standard.
  static int evaluatePosition(GameState state, Player aiPlayer) {
    return _evaluateTacticalPosition(state, aiPlayer, aggressive: false);
  }

  // Variante agressive pour le niveau Maître.
  static int evaluateAggressivePosition(GameState state, Player aiPlayer) {
    return _evaluateTacticalPosition(state, aiPlayer, aggressive: true);
  }

  // Ordonner les coups pour meilleur élagage alpha-bêta.
  static List<AIMove> orderMoves(
    List<AIMove> moves,
    GameState state,
    Player aiPlayer, {
    PositionEvaluator? evaluator,
    bool maximizing = true,
  }) {
    final scoreMove = evaluator ?? evaluatePosition;

    moves.sort((a, b) {
      final scoreA = _orderingScore(state, a, aiPlayer, scoreMove);
      final scoreB = _orderingScore(state, b, aiPlayer, scoreMove);
      return maximizing ? scoreB.compareTo(scoreA) : scoreA.compareTo(scoreB);
    });

    return moves;
  }

  // Simuler un coup.
  static GameState simulateMove(GameState state, AIMove move) {
    if (state.isPlacementPhase) {
      return GameLogic.placePiece(state, move.newPosition);
    }
    return GameLogic.movePiece(state, move.piece, move.newPosition);
  }

  // Trouver le meilleur coup avec minimax + alpha-bêta + cache.
  static Future<AIMove?> findBestMove(
    GameState state,
    Player aiPlayer,
    int depth,
    bool useAlphaBeta, {
    PositionEvaluator? evaluator,
  }) async {
    final scorePosition = evaluator ?? evaluatePosition;

    if (state.isPlacementPhase) {
      final moves = getPlacementMoves(state);
      if (moves.isEmpty) return null;

      GridPosition? bestPosition;
      int bestScore = -_infinity;

      for (var pos in moves) {
        final nextState = GameLogic.placePiece(state, pos);
        if (identical(nextState, state)) continue;

        int score = scorePosition(nextState, aiPlayer);
        score += _positionValues[pos] ?? 0;

        if (score > bestScore) {
          bestScore = score;
          bestPosition = pos;
        }
      }

      bestPosition ??= moves.first;

      return AIMove(
        GamePiece(player: aiPlayer, position: const GridPosition(-1, -1)),
        bestPosition,
      );
    }

    if (state.currentPlayer != aiPlayer) {
      return null;
    }

    final candidateMoves = getMovementMoves(state, aiPlayer);
    if (candidateMoves.isEmpty) return null;

    final transpositionTable = <String, _TranspositionEntry>{};
    final orderedMoves = orderMoves(
      List<AIMove>.from(candidateMoves),
      state,
      aiPlayer,
      evaluator: scorePosition,
      maximizing: true,
    );

    AIMove? bestMove;
    int bestScore = -_infinity;
    int alpha = -_infinity;
    int beta = _infinity;

    for (var move in orderedMoves) {
      final newState = simulateMove(state, move);
      final score = _minimax(
        newState,
        max(0, depth - 1),
        aiPlayer,
        alpha,
        beta,
        useAlphaBeta,
        scorePosition,
        transpositionTable,
      );

      if (score > bestScore || bestMove == null) {
        bestScore = score;
        bestMove = move;
      }

      if (useAlphaBeta) {
        alpha = max(alpha, bestScore);
      }
    }

    return bestMove;
  }

  static int _minimax(
    GameState state,
    int depth,
    Player aiPlayer,
    int alpha,
    int beta,
    bool useAlphaBeta,
    PositionEvaluator evaluator,
    Map<String, _TranspositionEntry> transpositionTable,
  ) {
    if (depth == 0 || state.status != GameStatus.playing) {
      return evaluator(state, aiPlayer);
    }

    final cacheKey = _buildCacheKey(state, aiPlayer, depth);
    if (useAlphaBeta) {
      final cached = transpositionTable[cacheKey];
      if (cached != null && cached.depth >= depth) {
        return cached.score;
      }
    }

    final currentPlayer = state.currentPlayer;
    final moves = getMovementMoves(state, currentPlayer);

    if (moves.isEmpty) {
      final terminalScore = 85000 + (depth * 25);
      return currentPlayer == aiPlayer ? -terminalScore : terminalScore;
    }

    final maximizing = currentPlayer == aiPlayer;
    final orderedMoves = orderMoves(
      List<AIMove>.from(moves),
      state,
      aiPlayer,
      evaluator: evaluator,
      maximizing: maximizing,
    );

    int bestScore = maximizing ? -_infinity : _infinity;

    for (var move in orderedMoves) {
      final newState = simulateMove(state, move);
      final eval = _minimax(
        newState,
        depth - 1,
        aiPlayer,
        alpha,
        beta,
        useAlphaBeta,
        evaluator,
        transpositionTable,
      );

      if (maximizing) {
        bestScore = max(bestScore, eval);
        if (useAlphaBeta) {
          alpha = max(alpha, bestScore);
          if (alpha >= beta) break;
        }
      } else {
        bestScore = min(bestScore, eval);
        if (useAlphaBeta) {
          beta = min(beta, bestScore);
          if (beta <= alpha) break;
        }
      }
    }

    if (useAlphaBeta) {
      transpositionTable[cacheKey] = _TranspositionEntry(depth, bestScore);
    }

    return bestScore;
  }

  static int _evaluateTacticalPosition(
    GameState state,
    Player aiPlayer, {
    required bool aggressive,
  }) {
    final opponent = _opponentOf(aiPlayer);

    if (GameLogic.checkWin(state, aiPlayer)) {
      return 100000 - state.turnsPlayed;
    }

    if (GameLogic.checkWin(state, opponent)) {
      return -100000 + state.turnsPlayed;
    }

    if (state.isMovementPhase) {
      if (state.isPlayerBlocked(opponent)) {
        return 90000;
      }

      if (state.isPlayerBlocked(aiPlayer)) {
        return -90000;
      }
    }

    int score = 0;

    score += _scoreLines(state, aiPlayer, opponent, aggressive: aggressive);

    final aiWinningLines = _countImmediateWinningLines(state, aiPlayer);
    final opponentWinningLines = _countImmediateWinningLines(state, opponent);

    score += aiWinningLines * (aggressive ? 1850 : 1450);
    score -= opponentWinningLines * (aggressive ? 2450 : 2050);

    final aiForkSquares = _countForkSquares(state, aiPlayer);
    final opponentForkSquares = _countForkSquares(state, opponent);

    score += aiForkSquares * (aggressive ? 620 : 420);
    score -= opponentForkSquares * (aggressive ? 700 : 480);

    final aiMoves = getMovementMoves(state, aiPlayer).length;
    final opponentMoves = getMovementMoves(state, opponent).length;
    score += (aiMoves - opponentMoves) * (aggressive ? 24 : 18);

    score += _scorePiecePlacement(
      state,
      aiPlayer,
      opponent,
      aggressive: aggressive,
    );

    return score;
  }

  static int _scoreLines(
    GameState state,
    Player aiPlayer,
    Player opponent, {
    required bool aggressive,
  }) {
    int score = 0;

    for (var line in _winningLines) {
      int aiCount = 0;
      int opponentCount = 0;
      int emptyCount = 0;

      for (var pos in line) {
        final piece = state.getPieceAt(pos);
        if (piece == null) {
          emptyCount++;
        } else if (piece.player == aiPlayer) {
          aiCount++;
        } else if (piece.player == opponent) {
          opponentCount++;
        }
      }

      if (aiCount > 0 && opponentCount > 0) {
        continue;
      }

      final includesCenter = line.contains(_center);

      if (aiCount == 2 && emptyCount == 1) {
        score += aggressive ? 2600 : 2200;
        if (includesCenter) score += 140;
      } else if (aiCount == 1 && emptyCount == 2) {
        score += aggressive ? 260 : 210;
      }

      if (opponentCount == 2 && emptyCount == 1) {
        score -= aggressive ? 3200 : 2800;
        if (includesCenter) score -= 160;
      } else if (opponentCount == 1 && emptyCount == 2) {
        score -= aggressive ? 300 : 230;
      }
    }

    return score;
  }

  static int _scorePiecePlacement(
    GameState state,
    Player aiPlayer,
    Player opponent, {
    required bool aggressive,
  }) {
    int score = 0;

    for (var piece in state.pieces) {
      final value = _positionValues[piece.position] ?? 0;
      final mobility = PositionUtils.getAdjacentPositions(
        piece.position,
      ).where((p) => !state.isPositionOccupied(p)).length;

      final mobilityWeight = aggressive ? 18 : 14;
      final total = value + (mobility * mobilityWeight);

      if (piece.player == aiPlayer) {
        score += total;
      } else if (piece.player == opponent) {
        score -= total;
      }
    }

    final centerPiece = state.getPieceAt(_center);
    if (centerPiece?.player == aiPlayer) {
      score += aggressive ? 260 : 200;
    } else if (centerPiece?.player == opponent) {
      score -= aggressive ? 300 : 220;
    }

    return score;
  }

  static int _countImmediateWinningLines(GameState state, Player player) {
    final opponent = _opponentOf(player);
    int count = 0;

    for (var line in _winningLines) {
      int playerCount = 0;
      int opponentCount = 0;
      int emptyCount = 0;

      for (var pos in line) {
        final piece = state.getPieceAt(pos);
        if (piece == null) {
          emptyCount++;
        } else if (piece.player == player) {
          playerCount++;
        } else if (piece.player == opponent) {
          opponentCount++;
        }
      }

      if (playerCount == 2 && opponentCount == 0 && emptyCount == 1) {
        count++;
      }
    }

    return count;
  }

  static int _countForkSquares(GameState state, Player player) {
    final opponent = _opponentOf(player);
    final emptyPositions = getPlacementMoves(state);
    int forkSquares = 0;

    for (var empty in emptyPositions) {
      int threateningLines = 0;

      for (var line in _winningLines) {
        if (!line.contains(empty)) continue;

        int playerCount = 0;
        int opponentCount = 0;

        for (var pos in line) {
          if (pos == empty) continue;

          final piece = state.getPieceAt(pos);
          if (piece == null) continue;

          if (piece.player == player) {
            playerCount++;
          } else if (piece.player == opponent) {
            opponentCount++;
          }
        }

        if (opponentCount == 0 && playerCount == 2) {
          threateningLines++;
        }
      }

      if (threateningLines >= 2) {
        forkSquares++;
      }
    }

    return forkSquares;
  }

  static int _orderingScore(
    GameState state,
    AIMove move,
    Player aiPlayer,
    PositionEvaluator evaluator,
  ) {
    final nextState = simulateMove(state, move);
    final mover = state.currentPlayer;

    if (GameLogic.checkWin(nextState, mover)) {
      return mover == aiPlayer ? 120000 : -120000;
    }

    int score = evaluator(nextState, aiPlayer);

    if (move.newPosition == _center) {
      score += mover == aiPlayer ? 120 : -120;
    }

    return score;
  }

  static String _buildCacheKey(GameState state, Player aiPlayer, int depth) {
    final sortedPieces = List<GamePiece>.from(state.pieces)
      ..sort((a, b) {
        final playerCompare = a.player.index.compareTo(b.player.index);
        if (playerCompare != 0) return playerCompare;

        final xCompare = a.position.x.compareTo(b.position.x);
        if (xCompare != 0) return xCompare;

        return a.position.y.compareTo(b.position.y);
      });

    final piecesKey = sortedPieces
        .map((p) => '${p.player.index}${p.position.x}${p.position.y}')
        .join();

    return '${state.phase.index}|${state.currentPlayer.index}|'
        '${state.status.index}|${aiPlayer.index}|$depth|$piecesKey';
  }

  static Player _opponentOf(Player player) {
    return player == Player.player1 ? Player.player2 : Player.player1;
  }
}

class _TranspositionEntry {
  final int depth;
  final int score;

  const _TranspositionEntry(this.depth, this.score);
}
