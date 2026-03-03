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
    final searchDepth = _getAdaptiveMasterDepth(state);
    final bestMove = await AIGameLogic.findBestMove(
      state,
      Player.player2,
      searchDepth,
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

    // Renforce spécifiquement la réponse quand l'humain commence.
    final preferredOpeningCounter = _getPreferredOpeningCounterMove(state);
    return _findBestPlacementWithLookahead(
      state,
      preferredMove: preferredOpeningCounter,
    );
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

  GridPosition _findBestPlacementWithLookahead(
    GameState state, {
    GridPosition? preferredMove,
  }) {
    final emptyPositions = _getEmptyPositions(state);
    if (emptyPositions.isEmpty) {
      return const GridPosition(0, 0);
    }

    final lookaheadDepth = _getPlacementLookaheadDepth(state);
    GridPosition bestMove = emptyPositions.first;
    int bestScore = -100000000;
    int alpha = -100000000;
    const int beta = 100000000;

    for (final move in emptyPositions) {
      final nextState = GameLogic.placePiece(state, move);
      if (identical(nextState, state)) continue;

      int score = _placementMinimax(nextState, lookaheadDepth - 1, alpha, beta);
      score += _positionalValues[move] ?? 0;
      score += _evaluatePlacement(move, nextState) ~/ 4;

      if (preferredMove != null && move == preferredMove) {
        score += 260;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }

      alpha = alpha > bestScore ? alpha : bestScore;
    }

    return bestMove;
  }

  int _placementMinimax(GameState state, int depth, int alpha, int beta) {
    if (depth <= 0 ||
        state.status != GameStatus.playing ||
        !state.isPlacementPhase) {
      return AIGameLogic.evaluateAggressivePosition(state, Player.player2);
    }

    final moves = _getEmptyPositions(state);
    if (moves.isEmpty) {
      return AIGameLogic.evaluateAggressivePosition(state, Player.player2);
    }

    final maximizing = state.currentPlayer == Player.player2;
    int bestScore = maximizing ? -100000000 : 100000000;

    for (final move in moves) {
      final nextState = GameLogic.placePiece(state, move);
      if (identical(nextState, state)) continue;

      final score = _placementMinimax(nextState, depth - 1, alpha, beta);

      if (maximizing) {
        if (score > bestScore) bestScore = score;
        if (score > alpha) alpha = score;
        if (alpha >= beta) break;
      } else {
        if (score < bestScore) bestScore = score;
        if (score < beta) beta = score;
        if (beta <= alpha) break;
      }
    }

    return bestScore;
  }

  int _getPlacementLookaheadDepth(GameState state) {
    final remainingPlacements =
        (GameConstants.piecesPerPlayer * 2) - state.pieces.length;
    if (remainingPlacements <= 0) return 1;

    // Quand l'humain commence, on cherche plus loin sur l'ouverture.
    final isRespondingToHumanOpening =
        state.isPlacementPhase &&
        state.currentPlayer == Player.player2 &&
        state.turnsPlayed == 1;

    final baseDepth = isRespondingToHumanOpening ? 5 : 4;
    return remainingPlacements < baseDepth ? remainingPlacements : baseDepth;
  }

  GridPosition? _getPreferredOpeningCounterMove(GameState state) {
    final openingFallback = OpeningBook.getBestOpeningMove(state);
    GridPosition? preferred = openingFallback;

    final isRespondingToHumanOpening =
        state.isPlacementPhase &&
        state.currentPlayer == Player.player2 &&
        state.turnsPlayed == 1;

    if (!isRespondingToHumanOpening) {
      return preferred;
    }

    final firstHumanPiece = state.player1Pieces.isNotEmpty
        ? state.player1Pieces.first.position
        : null;
    if (firstHumanPiece != null) {
      final bookResponse = OpeningBook.getResponseToOpponentOpening(
        state,
        firstHumanPiece,
      );
      if (bookResponse != null && !state.isPositionOccupied(bookResponse)) {
        preferred = bookResponse;
      }
    }

    return preferred;
  }

  int _getAdaptiveMasterDepth(GameState state) {
    int depth = GameConstants.masterDepth + 1;

    // Si l'IA joue en second (humain commence), on pousse un peu la profondeur
    // en début de mouvement pour compenser l'initiative adverse.
    final humanStarted = state.turnsPlayed.isOdd;
    final earlyMovement = state.isMovementPhase && state.turnsPlayed <= 11;
    if (humanStarted && earlyMovement) {
      depth += 1;
    }

    return depth;
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
