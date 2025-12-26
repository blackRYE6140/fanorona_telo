import 'package:flutter/material.dart';

// Classe de position personnalisée pour éviter les problèmes avec Point
class GridPosition {
  final int x;
  final int y;
  
  const GridPosition(this.x, this.y);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridPosition && x == other.x && y == other.y;
  }
  
  @override
  int get hashCode => Object.hash(x, y);
  
  @override
  String toString() => '($x, $y)';
}

// Enumérations
enum Player { player1, player2 }
enum GamePhase { placement, movement }
enum GameStatus { playing, player1Won, player2Won }

// Constantes de jeu
class GameConstants {
  // Couleurs style néon
  static const Color backgroundColor = Color(0xFF020014);
  static const Color gridColor = Color(0xFF0066FF);
  static const Color neonPink = Color(0xFFFF1493);
  static const Color neonBlue = Color(0xFF007FFF);
  
  // Tailles
  static const double boardPadding = 40.0;
  static const double gridLineWidth = 1.5;
  static const double pieceRadius = 18.0;
  
  // Nombre de pièces
  static const int piecesPerPlayer = 3;
  
  // Messages
  static const String player1Turn = "Tour du Joueur Rouge";
  static const String player2Turn = "Tour du Joueur Bleu";
  static const String placementPhase = "Phase Placement";
  static const String movementPhase = "Phase Mouvement";
  static const String player1Wins = "🎉 Joueur Rouge Gagne !";
  static const String player2Wins = "🎉 Joueur Bleu Gagne !";
  static const String playerBlocked = "Bloqué - Vous perdez !";
  
  // Méthode pour éviter la dépréciation withOpacity
  static Color withAlpha(Color color, int alpha) {
    return color.withAlpha(alpha);
  }
}