import 'game_state.dart';
import '../utils/position_utils.dart';
import 'constants.dart';

class GameLogic {
  static bool isValidPlacement(GameState state, GridPosition position) {
    // Position valide dans la grille 3x3
    if (position.x < 0 || position.x > 2 || position.y < 0 || position.y > 2) {
      return false;
    }
    
    // Case non occupée
    if (state.isPositionOccupied(position)) {
      return false;
    }
    
    // Phase placement et moins de 6 pièces placées
    return state.isPlacementPhase && state.pieces.length < 6;
  }
  
  static bool isValidMove(GameState state, GamePiece piece, GridPosition newPosition) {
    // Position valide dans la grille
    if (newPosition.x < 0 || newPosition.x > 2 || newPosition.y < 0 || newPosition.y > 2) {
      return false;
    }
    
    // Case non occupée
    if (state.isPositionOccupied(newPosition)) {
      return false;
    }
    
    // Vérifie que c'est une position adjacente
    final adjacentPositions = PositionUtils.getAdjacentPositions(piece.position);
    if (!adjacentPositions.contains(newPosition)) {
      return false;
    }
    
    // Vérifie que la pièce appartient au joueur courant
    if (piece.player != state.currentPlayer) {
      return false;
    }
    
    return true;
  }
  
  static bool checkWin(GameState state, Player player) {
    final playerPieces = state.pieces.where((p) => p.player == player).toList();
    
    if (playerPieces.length < 3) return false;
    
    // Récupère les positions
    final positions = playerPieces.map((p) => p.position).toList();
    
    // Vérifie toutes les lignes/colonnes/diagonales gagnantes
    final winningLines = [
      // Lignes horizontales
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
      
      // Lignes verticales
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
      
      // Diagonales
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
    
    for (var line in winningLines) {
      if (line.every((point) => positions.contains(point))) {
        return true;
      }
    }
    
    return false;
  }
  
  static GameState placePiece(GameState state, GridPosition position) {
    if (!isValidPlacement(state, position)) {
      return state;
    }
    
    final newPiece = GamePiece(
      player: state.currentPlayer,
      position: position,
    );
    
    var newPieces = List<GamePiece>.from(state.pieces)..add(newPiece);
    var newTurnsPlayed = state.turnsPlayed + 1;
    
    // Vérifie victoire immédiate
    var newStatus = state.status;
    if (checkWin(GameState(
      pieces: newPieces,
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: newTurnsPlayed,
    ), state.currentPlayer)) {
      newStatus = state.currentPlayer == Player.player1 
          ? GameStatus.player1Won 
          : GameStatus.player2Won;
    }
    
    // Change de joueur
    final nextPlayer = state.currentPlayer == Player.player1 
        ? Player.player2 
        : Player.player1;
    
    // Passe à la phase mouvement après 6 placements
    GamePhase nextPhase = state.phase;
    if (newPieces.length >= 6 && newStatus == GameStatus.playing) {
      nextPhase = GamePhase.movement;
    }
    
    return state.copyWith(
      pieces: newPieces,
      currentPlayer: nextPlayer,
      turnsPlayed: newTurnsPlayed,
      status: newStatus,
      phase: nextPhase,
    );
  }
  
  static GameState movePiece(GameState state, GamePiece piece, GridPosition newPosition) {
    if (!isValidMove(state, piece, newPosition)) {
      return state;
    }
    
    // Met à jour la position de la pièce
    var newPieces = state.pieces.map((p) {
      if (p == piece) {
        return p.copyWith(newPosition: newPosition);
      }
      return p;
    }).toList();
    
    var newTurnsPlayed = state.turnsPlayed + 1;
    
    // Vérifie victoire
    var newStatus = state.status;
    if (checkWin(GameState(
      pieces: newPieces,
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: newTurnsPlayed,
    ), state.currentPlayer)) {
      newStatus = state.currentPlayer == Player.player1 
          ? GameStatus.player1Won 
          : GameStatus.player2Won;
    }
    
    // Vérifie si le prochain joueur est bloqué
    final nextPlayer = state.currentPlayer == Player.player1 
        ? Player.player2 
        : Player.player1;
    
    // Si le jeu continue, vérifie blocage
    if (newStatus == GameStatus.playing) {
      final nextState = GameState(
        pieces: newPieces,
        currentPlayer: nextPlayer,
        phase: state.phase,
        status: newStatus,
        turnsPlayed: newTurnsPlayed,
      );
      
      if (nextState.isPlayerBlocked(nextPlayer)) {
        // Le prochain joueur est bloqué, donc le joueur courant gagne
        newStatus = state.currentPlayer == Player.player1 
            ? GameStatus.player1Won 
            : GameStatus.player2Won;
      }
    }
    
    return state.copyWith(
      pieces: newPieces,
      currentPlayer: nextPlayer,
      turnsPlayed: newTurnsPlayed,
      status: newStatus,
      selectedPiece: null,
    );
  }
  
  static GameState selectPiece(GameState state, GamePiece? piece) {
    return state.copyWith(selectedPiece: piece);
  }
  
  static GameState resetGame() {
    return GameState.initial();
  }
}