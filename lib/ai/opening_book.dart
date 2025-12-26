import '../game/game_state.dart';
import '../game/constants.dart';

class OpeningBook {
  
  // Meilleurs premiers coups pour Fanorona Telo
  static GridPosition getBestOpeningMove(GameState state) {
    final emptyPositions = _getEmptyPositions(state);
    
    // Priorité 1: Prendre le centre
    final center = GridPosition(1, 1);
    if (emptyPositions.contains(center)) {
      return center;
    }
    
    // Priorité 2: Si centre pris, prendre un coin adjacent
    final corners = [
      GridPosition(0, 0), GridPosition(2, 0),
      GridPosition(0, 2), GridPosition(2, 2),
    ];
    
    for (var corner in corners) {
      if (emptyPositions.contains(corner)) {
        return corner;
      }
    }
    
    // Priorité 3: Prendre n'importe quelle position
    return emptyPositions.first;
  }
  
  // Réponse aux ouvertures adverses
  static GridPosition? getResponseToOpponentOpening(GameState state, GridPosition opponentMove) {
    // Si adversaire prend centre, prendre coin adjacent
    if (opponentMove.x == 1 && opponentMove.y == 1) {
      return GridPosition(0, 0); // Coin haut-gauche
    }
    
    // Si adversaire prend coin, prendre centre ou coin opposé
    if ((opponentMove.x == 0 || opponentMove.x == 2) && 
        (opponentMove.y == 0 || opponentMove.y == 2)) {
      
      final center = GridPosition(1, 1);
      if (!state.isPositionOccupied(center)) {
        return center;
      }
      
      // Prendre coin opposé
      final oppositeCorner = GridPosition(2 - opponentMove.x, 2 - opponentMove.y);
      if (!state.isPositionOccupied(oppositeCorner)) {
        return oppositeCorner;
      }
    }
    
    return null; // Pas de réponse spécifique
  }
  
  static List<GridPosition> _getEmptyPositions(GameState state) {
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