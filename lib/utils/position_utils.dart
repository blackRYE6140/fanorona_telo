import 'dart:math';
import 'package:flutter/material.dart';
import '../game/constants.dart';

class PositionUtils {
  // Matrice d'adjacence pour la grille 3x3
  static final Map<GridPosition, List<GridPosition>> adjacencyMap = {
    // Coins
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
    
    // Bords (sans coins)
    const GridPosition(1, 0): [
      const GridPosition(0, 0),
      const GridPosition(2, 0),
      const GridPosition(1, 1),
      const GridPosition(0, 1),
      const GridPosition(2, 1),
    ],
    const GridPosition(0, 1): [
      const GridPosition(0, 0),
      const GridPosition(0, 2),
      const GridPosition(1, 1),
      const GridPosition(1, 0),
      const GridPosition(1, 2),
    ],
    const GridPosition(2, 1): [
      const GridPosition(2, 0),
      const GridPosition(2, 2),
      const GridPosition(1, 1),
      const GridPosition(1, 0),
      const GridPosition(1, 2),
    ],
    const GridPosition(1, 2): [
      const GridPosition(0, 2),
      const GridPosition(2, 2),
      const GridPosition(1, 1),
      const GridPosition(0, 1),
      const GridPosition(2, 1),
    ],
    
    // Centre
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
  
  // Convertit les coordonnées de la grille (0-2, 0-2) en coordonnées d'écran
  static Offset gridToScreen(GridPosition gridPos, Size boardSize) {
    final cellWidth = boardSize.width / 2;
    final cellHeight = boardSize.height / 2;
    
    return Offset(
      gridPos.x * cellWidth,
      // Inversion Y pour avoir (0,0) en haut à gauche
      2 * cellHeight - gridPos.y * cellHeight,
    );
  }
  
  // Convertit les coordonnées d'écran en coordonnées de grille
  static GridPosition? screenToGrid(Offset screenPos, Size boardSize) {
    final cellWidth = boardSize.width / 2;
    final cellHeight = boardSize.height / 2;
    
    final gridX = (screenPos.dx / cellWidth).round();
    final gridY = 2 - (screenPos.dy / cellHeight).round();
    
    if (gridX >= 0 && gridX <= 2 && gridY >= 0 && gridY <= 2) {
      return GridPosition(gridX, gridY);
    }
    return null;
  }
  
  // Convertit Point<int> en GridPosition
  static GridPosition fromPoint(Point<int> point) {
    return GridPosition(point.x, point.y);
  }
  
  // Convertit GridPosition en Point<int>
  static Point<int> toPoint(GridPosition pos) {
    return Point(pos.x, pos.y);
  }
}