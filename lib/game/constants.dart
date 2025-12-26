import 'package:flutter/material.dart';

// Classe de position personnalisée
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
enum GameMode { twoPlayers, vsAI }
enum AIDifficulty { strategist, master }

// Constantes de jeu
class GameConstants {
  // Couleurs style néon
  static const Color backgroundColor = Color(0xFF020014);
  static const Color gridColor = Color(0xFF0066FF);
  static const Color neonPink = Color(0xFFFF1493);
  static const Color neonBlue = Color(0xFF007FFF);
  
  // Couleurs IA
  static const Color strategistColor = Color(0xFFFF9800);
  static const Color masterColor = Color(0xFF9C27B0);
  
  // Tailles
  static const double boardPadding = 40.0;
  static const double gridLineWidth = 1.5;
  static const double pieceRadius = 20.0;
  
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
  static const String aiThinking = "🤖 L'IA réfléchit...";
  static const String aiMove = "Tour de l'IA";
  static const String yourTurn = "À vous de jouer";
  static const String vsAI = "Contre IA";
  static const String vsPlayer = "2 Joueurs";
  static const String youWin = "🎉 Vous avez gagné !";
  static const String aiWins = "🤖 L'IA a gagné !";
  static const String draw = "Match nul !";
  
  // Paramètres IA
  static const int strategistDepth = 3;
  static const int masterDepth = 5;
  static const int aiThinkingDelay = 800; // ms
  
  // Méthode pour éviter la dépréciation withOpacity
  static Color withAlpha(Color color, int alpha) {
    return color.withAlpha(alpha);
  }
}