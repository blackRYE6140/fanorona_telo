import '../game/constants.dart';
import '../game/game_state.dart';

class NetworkCodec {
  static String playerToWire(Player player) {
    return player == Player.player1 ? 'player1' : 'player2';
  }

  static Player playerFromWire(String value) {
    return value == 'player2' ? Player.player2 : Player.player1;
  }

  static Map<String, dynamic> gameStateToMap(GameState state) {
    return {
      'pieces': state.pieces.map((piece) {
        return {
          'player': playerToWire(piece.player),
          'x': piece.position.x,
          'y': piece.position.y,
        };
      }).toList(),
      'currentPlayer': playerToWire(state.currentPlayer),
      'phase': state.phase.index,
      'status': state.status.index,
      'turnsPlayed': state.turnsPlayed,
    };
  }

  static GameState gameStateFromMap(Map<String, dynamic> map) {
    final rawPieces = (map['pieces'] as List<dynamic>? ?? const []);

    final pieces = <GamePiece>[];
    for (final raw in rawPieces) {
      if (raw is! Map) {
        continue;
      }

      final rawMap = raw.cast<String, dynamic>();
      pieces.add(
        GamePiece(
          player: playerFromWire((rawMap['player'] as String?) ?? 'player1'),
          position: GridPosition(
            (rawMap['x'] as num?)?.toInt() ?? 0,
            (rawMap['y'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }

    final phaseIndex = (map['phase'] as num?)?.toInt() ?? 0;
    final statusIndex = (map['status'] as num?)?.toInt() ?? 0;
    final clampedPhaseIndex = phaseIndex
        .clamp(0, GamePhase.values.length - 1)
        .toInt();
    final clampedStatusIndex = statusIndex
        .clamp(0, GameStatus.values.length - 1)
        .toInt();

    return GameState(
      pieces: pieces,
      currentPlayer: playerFromWire(
        (map['currentPlayer'] as String?) ?? 'player1',
      ),
      phase: GamePhase.values[clampedPhaseIndex],
      status: GameStatus.values[clampedStatusIndex],
      turnsPlayed: (map['turnsPlayed'] as num?)?.toInt() ?? 0,
      selectedPiece: null,
    );
  }
}
