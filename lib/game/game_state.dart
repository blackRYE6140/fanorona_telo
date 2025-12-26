import 'constants.dart';
import '../utils/position_utils.dart';

class GamePiece {
  final Player player;
  final GridPosition position;
  
  GamePiece({required this.player, required this.position});
  
  GamePiece copyWith({GridPosition? newPosition}) {
    return GamePiece(
      player: player,
      position: newPosition ?? position,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GamePiece &&
        player == other.player &&
        position == other.position;
  }
  
  @override
  int get hashCode => Object.hash(player, position);
}

class GameState {
  List<GamePiece> pieces;
  Player currentPlayer;
  GamePhase phase;
  GameStatus status;
  int turnsPlayed;
  GamePiece? selectedPiece;
  
  GameState({
    required this.pieces,
    required this.currentPlayer,
    required this.phase,
    required this.status,
    this.turnsPlayed = 0,
    this.selectedPiece,
  });
  
  factory GameState.initial() {
    return GameState(
      pieces: [],
      currentPlayer: Player.player1, // Rouge commence
      phase: GamePhase.placement,
      status: GameStatus.playing,
      turnsPlayed: 0,
    );
  }
  
  GameState copyWith({
    List<GamePiece>? pieces,
    Player? currentPlayer,
    GamePhase? phase,
    GameStatus? status,
    int? turnsPlayed,
    GamePiece? selectedPiece,
  }) {
    return GameState(
      pieces: pieces ?? this.pieces,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      turnsPlayed: turnsPlayed ?? this.turnsPlayed,
      selectedPiece: selectedPiece ?? this.selectedPiece,
    );
  }
  
  // Getters utiles
  List<GamePiece> get player1Pieces =>
      pieces.where((p) => p.player == Player.player1).toList();
      
  List<GamePiece> get player2Pieces =>
      pieces.where((p) => p.player == Player.player2).toList();
  
  bool get isPlacementPhase => phase == GamePhase.placement;
  bool get isMovementPhase => phase == GamePhase.movement;
  
  bool isPositionOccupied(GridPosition position) {
    return pieces.any((piece) => piece.position == position);
  }
  
  GamePiece? getPieceAt(GridPosition position) {
    for (var piece in pieces) {
      if (piece.position == position) {
        return piece;
      }
    }
    return null;
  }
  
  bool isPlayerBlocked(Player player) {
    // Vérifie si le joueur a au moins un mouvement possible
    final playerPieces = pieces.where((p) => p.player == player).toList();
    
    for (var piece in playerPieces) {
      final adjacentPositions = PositionUtils.getAdjacentPositions(piece.position);
      for (var pos in adjacentPositions) {
        if (!isPositionOccupied(pos)) {
          return false; // Au moins un mouvement possible
        }
      }
    }
    return true; // Aucun mouvement possible = bloqué
  }
  
  int get remainingPlacements {
    return GameConstants.piecesPerPlayer * 2 - pieces.length;
  }
}