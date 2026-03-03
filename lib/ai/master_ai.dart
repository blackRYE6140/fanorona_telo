import '../game/ai_game_logic.dart';
import '../game/constants.dart';
import '../game/game_logic.dart';
import '../game/game_state.dart';
import 'fanorona_ai.dart';
import 'game_analyzer.dart';
import 'opening_book.dart';
import 'pattern_recognizer.dart';

class MasterAI extends FanoronaAI {
  MasterAI()
    : super(
        name: 'MAÎTRE ABSOLU',
        description: 'Défi extrême - Analyse tactique avancée',
        strength: 5,
        color: GameConstants.masterAIColor,
      );

  static const bool _debugMode = false;

  final GameAnalyzer _analyzer = GameAnalyzer();

  final Map<GridPosition, int> _positionalValues = {
    const GridPosition(1, 1): 180,
    const GridPosition(0, 0): 100,
    const GridPosition(2, 0): 100,
    const GridPosition(0, 2): 100,
    const GridPosition(2, 2): 100,
    const GridPosition(1, 0): 75,
    const GridPosition(0, 1): 75,
    const GridPosition(2, 1): 75,
    const GridPosition(1, 2): 75,
  };

  @override
  Future<GridPosition?> getPlacementMove(GameState state) async {
    await think();

    if (_debugMode) {
      _analyzer.analyzeCriticalPosition(state, Player.player2);
    }

    final move = _selectBestPlacement(state);

    if (_debugMode) {
      _analyzer.recordMove(state, 'MAÎTRE placement (${move.x},${move.y})');
    }

    return move;
  }

  @override
  Future<AIMove?> getMovementMove(GameState state) async {
    await think();

    if (_debugMode) {
      _analyzer.analyzeCriticalPosition(state, Player.player2);
    }

    // 1) Gagner immédiatement si possible.
    final winningMoves = PatternRecognizer.findWinningMoves(
      state,
      Player.player2,
    );
    if (winningMoves.isNotEmpty) {
      return _pickBestMoveByEvaluation(state, winningMoves);
    }

    // 2) Bloquer les menaces immédiates adverses.
    final forcedDefense = _findBestDefensiveMove(state);
    if (forcedDefense != null) {
      return forcedDefense;
    }

    // 3) Chercher une fourchette tactique si disponible.
    final forkMoves = PatternRecognizer.findForkMoves(state, Player.player2);
    if (forkMoves.isNotEmpty) {
      return _pickBestMoveByEvaluation(state, forkMoves);
    }

    // 4) Minimax agressif profond + alpha-bêta + table de transposition.
    final bestMove = await AIGameLogic.findBestMove(
      state,
      Player.player2,
      GameConstants.masterDepth + 1,
      true,
      evaluator: AIGameLogic.evaluateAggressivePosition,
    );

    if (bestMove != null) {
      return bestMove;
    }

    // 5) Fallback robuste si jamais la recherche échoue.
    final allMoves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (allMoves.isEmpty) return null;

    return _pickBestMoveByEvaluation(state, allMoves);
  }

  GridPosition _selectBestPlacement(GameState state) {
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) {
      return const GridPosition(0, 0);
    }

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

    if (state.turnsPlayed <= 2) {
      final opening = OpeningBook.getBestOpeningMove(state);
      if (!state.isPositionOccupied(opening)) {
        return opening;
      }
    }

    GridPosition bestPosition = emptyPositions.first;
    int bestScore = -100000000;

    for (final pos in emptyPositions) {
      final nextState = GameLogic.placePiece(state, pos);
      if (identical(nextState, state)) continue;

      final score = _evaluatePlacement(pos, nextState);
      if (score > bestScore) {
        bestScore = score;
        bestPosition = pos;
      }
    }

    return bestPosition;
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

  int _evaluatePlacement(GridPosition placedPosition, GameState nextState) {
    int score = AIGameLogic.evaluateAggressivePosition(
      nextState,
      Player.player2,
    );
    score += _positionalValues[placedPosition] ?? 0;

    final aiWinningChances = PatternRecognizer.findWinningMoves(
      nextState,
      Player.player2,
    ).length;
    final opponentWinningChances = PatternRecognizer.findWinningMoves(
      nextState,
      Player.player1,
    ).length;

    score += aiWinningChances * 500;
    score -= opponentWinningChances * 850;

    return score;
  }

  AIMove? _findBestDefensiveMove(GameState state) {
    final opponentWinningMoves = PatternRecognizer.findWinningMoves(
      state,
      Player.player1,
    );
    if (opponentWinningMoves.isEmpty) return null;

    final allMoves = AIGameLogic.getMovementMoves(state, Player.player2);
    if (allMoves.isEmpty) return null;

    final fullySafeMoves = <AIMove>[];
    AIMove? bestDamageControlMove;
    int bestDamageControlScore = -100000000;

    for (final move in allMoves) {
      final simulated = AIGameLogic.simulateMove(state, move);
      final remainingThreats = PatternRecognizer.findWinningMoves(
        simulated,
        Player.player1,
      ).length;

      if (remainingThreats == 0) {
        fullySafeMoves.add(move);
      }

      final score =
          _evaluateMoveScore(simulated, move) - (remainingThreats * 4000);
      if (score > bestDamageControlScore) {
        bestDamageControlScore = score;
        bestDamageControlMove = move;
      }
    }

    if (fullySafeMoves.isNotEmpty) {
      return _pickBestMoveByEvaluation(state, fullySafeMoves);
    }

    return bestDamageControlMove;
  }

  AIMove _pickBestMoveByEvaluation(GameState currentState, List<AIMove> moves) {
    AIMove bestMove = moves.first;
    int bestScore = -100000000;

    for (final move in moves) {
      final simulated = AIGameLogic.simulateMove(currentState, move);
      final score = _evaluateMoveScore(simulated, move);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  int _evaluateMoveScore(GameState simulatedState, AIMove move) {
    int score = AIGameLogic.evaluateAggressivePosition(
      simulatedState,
      Player.player2,
    );

    final aiWinningChances = PatternRecognizer.findWinningMoves(
      simulatedState,
      Player.player2,
    ).length;
    final opponentWinningChances = PatternRecognizer.findWinningMoves(
      simulatedState,
      Player.player1,
    ).length;

    score += aiWinningChances * 800;
    score -= opponentWinningChances * 1200;

    score += _positionalValues[move.newPosition] ?? 0;

    return score;
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
