import 'dart:math';

import '../game/ai_game_logic.dart';
import '../game/constants.dart';
import '../game/game_logic.dart';
import '../game/game_state.dart';
import 'fanorona_ai.dart';
import 'pattern_recognizer.dart';

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

    final immediateWin = _findImmediateWinningPlacement(state, Player.player2);
    if (immediateWin != null) {
      return immediateWin;
    }

    final immediateBlock = _findImmediateWinningPlacement(
      state,
      Player.player1,
    );
    if (immediateBlock != null) {
      return immediateBlock;
    }

    final scoredPlacements = emptyPositions.map((position) {
      final nextState = GameLogic.placePiece(state, position);
      final score = _scorePlacementCandidate(position, nextState);
      return MapEntry(position, score);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    final selectedIndex = _pickImperfectIndex(
      scoredPlacements.length,
      baseImprecision: 0.22,
      maxOffset: 2,
    );
    return scoredPlacements[selectedIndex].key;
  }

  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();

    // 1) Jouer la victoire immédiate.
    final winningMoves = PatternRecognizer.findWinningMoves(
      state,
      Player.player2,
    );
    if (winningMoves.isNotEmpty) {
      return _pickBestByEvaluation(state, winningMoves);
    }

    // 2) Bloquer les menaces adverses immédiates.
    final defensiveMove = _findBestDefensiveMove(state);
    if (defensiveMove != null) {
      return defensiveMove;
    }

    // 3) Minimax alpha-bêta standard (moins fort que Maître).
    final bestMove = await AIGameLogic.findBestMove(
      state,
      Player.player2, // L'IA est toujours le joueur 2
      GameConstants.strategistDepth,
      true, // Utiliser élagage alpha-bêta
      evaluator: AIGameLogic.evaluatePosition,
    );

    if (bestMove != null) {
      final imperfectAlternative = _chooseImperfectAlternative(state, bestMove);
      if (imperfectAlternative != null) {
        return imperfectAlternative;
      }

      return bestMove;
    }

    // 4) Fallback: choisir parmi les meilleurs coups heuristiques.
    final fallbackMoves = AIGameLogic.orderMoves(
      AIGameLogic.getMovementMoves(state, Player.player2),
      state,
      Player.player2,
      evaluator: AIGameLogic.evaluatePosition,
      maximizing: true,
    );

    if (fallbackMoves.isEmpty) return null;
    final pickCount = min(3, fallbackMoves.length);
    return fallbackMoves[_random.nextInt(pickCount)];
  }

  GridPosition? _findImmediateWinningPlacement(GameState state, Player player) {
    final emptyPositions = _getEmptyPositions(state);

    for (final pos in emptyPositions) {
      final simulated = GameState(
        pieces: List<GamePiece>.from(state.pieces)
          ..add(GamePiece(player: player, position: pos)),
        currentPlayer: state.currentPlayer,
        phase: state.phase,
        status: state.status,
        turnsPlayed: state.turnsPlayed,
      );

      if (GameLogic.checkWin(simulated, player)) {
        return pos;
      }
    }

    return null;
  }

  int _scorePlacementCandidate(GridPosition position, GameState state) {
    int score = AIGameLogic.evaluatePosition(state, Player.player2);

    if (position == const GridPosition(1, 1)) {
      score += 200;
    } else if ((position.x == 0 || position.x == 2) &&
        (position.y == 0 || position.y == 2)) {
      score += 90;
    } else {
      score += 60;
    }

    final aiWinningChances = PatternRecognizer.findWinningMoves(
      state,
      Player.player2,
    ).length;
    final opponentWinningChances = PatternRecognizer.findWinningMoves(
      state,
      Player.player1,
    ).length;

    score += aiWinningChances * 350;
    score -= opponentWinningChances * 450;
    return score;
  }

  AIMove? _findBestDefensiveMove(GameState state) {
    final opponentThreats = PatternRecognizer.findWinningMoves(
      state,
      Player.player1,
    );
    if (opponentThreats.isEmpty) return null;

    final moves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (moves.isEmpty) return null;

    AIMove? bestBlockingMove;
    int bestBlockingScore = -100000000;

    AIMove? bestDamageControlMove;
    int bestRemainingThreats = 100000000;
    int bestDamageControlScore = -100000000;

    for (final move in moves) {
      final simulated = AIGameLogic.simulateMove(state, move);
      final remainingThreats = PatternRecognizer.findWinningMoves(
        simulated,
        Player.player1,
      ).length;
      final eval = AIGameLogic.evaluatePosition(simulated, Player.player2);

      if (remainingThreats == 0 && eval > bestBlockingScore) {
        bestBlockingScore = eval;
        bestBlockingMove = move;
      }

      if (remainingThreats < bestRemainingThreats ||
          (remainingThreats == bestRemainingThreats &&
              eval > bestDamageControlScore)) {
        bestRemainingThreats = remainingThreats;
        bestDamageControlScore = eval;
        bestDamageControlMove = move;
      }
    }

    return bestBlockingMove ?? bestDamageControlMove;
  }

  AIMove _pickBestByEvaluation(GameState state, List<AIMove> moves) {
    AIMove bestMove = moves.first;
    int bestScore = -100000000;

    for (final move in moves) {
      final simulated = AIGameLogic.simulateMove(state, move);
      final score = AIGameLogic.evaluatePosition(simulated, Player.player2);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  AIMove? _chooseImperfectAlternative(GameState state, AIMove bestMove) {
    if (_random.nextDouble() > 0.28) {
      return null;
    }

    final orderedMoves = AIGameLogic.orderMoves(
      AIGameLogic.getMovementMoves(state, Player.player2),
      state,
      Player.player2,
      evaluator: AIGameLogic.evaluatePosition,
      maximizing: true,
    );

    final alternatives = <AIMove>[];
    for (final move in orderedMoves) {
      if (_sameMove(move, bestMove)) continue;

      final simulated = AIGameLogic.simulateMove(state, move);
      final givesImmediateWin = PatternRecognizer.findWinningMoves(
        simulated,
        Player.player1,
      ).isNotEmpty;
      if (givesImmediateWin) continue;

      alternatives.add(move);
      if (alternatives.length >= 2) break;
    }

    if (alternatives.isEmpty) {
      return null;
    }

    return alternatives[_random.nextInt(alternatives.length)];
  }

  bool _sameMove(AIMove a, AIMove b) {
    return a.piece.position == b.piece.position &&
        a.newPosition == b.newPosition;
  }

  int _pickImperfectIndex(
    int length, {
    required double baseImprecision,
    required int maxOffset,
  }) {
    if (length <= 1 || _random.nextDouble() > baseImprecision) {
      return 0;
    }

    final highestIndex = min(length - 1, maxOffset);
    return 1 + _random.nextInt(highestIndex);
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
