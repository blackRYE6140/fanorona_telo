import 'package:flutter/material.dart';
import '../game/constants.dart';

class PositionUtils {
  // Matrice d'adjacence CORRIGÉE pour la grille 3x3
  static final Map<GridPosition, List<GridPosition>> adjacencyMap = {
    // COINS
    const GridPosition(0, 0): [
      const GridPosition(1, 0),
      const GridPosition(0, 1),
      const GridPosition(1, 1),
    ],
    const GridPosition(2, 0): [
      const GridPosition(1, 0),
      const GridPosition(2, 1),
      const GridPosition(1, 1),
    ],
    const GridPosition(0, 2): [
      const GridPosition(0, 1),
      const GridPosition(1, 2),
      const GridPosition(1, 1),
    ],
    const GridPosition(2, 2): [
      const GridPosition(2, 1),
      const GridPosition(1, 2),
      const GridPosition(1, 1),
    ],
    
    // BORDS
    const GridPosition(1, 0): [
      const GridPosition(0, 0),
      const GridPosition(2, 0),
      const GridPosition(1, 1),
    ],
    const GridPosition(0, 1): [
      const GridPosition(0, 0),
      const GridPosition(0, 2),
      const GridPosition(1, 1),
    ],
    const GridPosition(2, 1): [
      const GridPosition(2, 0),
      const GridPosition(2, 2),
      const GridPosition(1, 1),
    ],
    const GridPosition(1, 2): [
      const GridPosition(0, 2),
      const GridPosition(2, 2),
      const GridPosition(1, 1),
    ],
    
    // CENTRE
    const GridPosition(1, 1): [
      const GridPosition(0, 0),
      const GridPosition(1, 0),
      const GridPosition(2, 0),
      const GridPosition(0, 1),
      const GridPosition(2, 1),
      const GridPosition(0, 2),
      const GridPosition(1, 2),
      const GridPosition(2, 2),
    ],
  };
  
  static List<GridPosition> getAdjacentPositions(GridPosition position) {
    return adjacencyMap[position] ?? [];
  }
  
  // Convertit les coordonnées de la grille (0-2, 0-2) en coordonnées d'écran AVEC PADDING
  static Offset gridToScreen(GridPosition gridPos, Size boardSize, {double padding = 20.0}) {
    final cellWidth = (boardSize.width - 2 * padding) / 2;
    final cellHeight = (boardSize.height - 2 * padding) / 2;
    
    return Offset(
      padding + gridPos.x * cellWidth,
      // Inversion Y pour avoir (0,0) en haut à gauche
      padding + (2 - gridPos.y) * cellHeight,
    );
  }
  
  // Convertit les coordonnées d'écran en coordonnées de grille AVEC PADDING
  static GridPosition? screenToGrid(Offset screenPos, Size boardSize, {double padding = 20.0}) {
    final cellWidth = (boardSize.width - 2 * padding) / 2;
    final cellHeight = (boardSize.height - 2 * padding) / 2;
    
    // Ajuster les coordonnées pour le padding
    final adjustedX = screenPos.dx - padding;
    final adjustedY = screenPos.dy - padding;
    
    if (adjustedX < 0 || adjustedY < 0) return null;
    
    final gridX = (adjustedX / cellWidth).round();
    final gridY = 2 - (adjustedY / cellHeight).round();
    
    if (gridX >= 0 && gridX <= 2 && gridY >= 0 && gridY <= 2) {
      return GridPosition(gridX, gridY);
    }
    return null;
  }
}