import 'dart:async';
import 'dart:ui';
import 'package:fanorona_telo/ai/master_ai.dart';
import 'package:fanorona_telo/ai/strategist_ai.dart';

import '../game/game_state.dart';
import '../game/ai_game_logic.dart';
import '../game/constants.dart';

abstract class FanoronaAI {
  final String name;
  final String description;
  final int strength; // 1-5
  final Color color;
  
  FanoronaAI({
    required this.name,
    required this.description,
    required this.strength,
    required this.color,
  });
  
  // Obtenir un coup de placement
  Future<GridPosition?> getPlacementMove(GameState state);
  
  // Obtenir un coup de mouvement
  Future<AIMove?> getMovementMove(GameState state);
  
  // Simuler un délai de réflexion
  Future<void> think() async {
    // Délai proportionnel à la force
    final delay = 500 + (strength * 300);
    await Future.delayed(Duration(milliseconds: delay));
  }
}

// Factory pour créer les IA
class AIFactory {
  static FanoronaAI createAI(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.strategist:
        return StrategistAI();
      case AIDifficulty.master:
        return MasterAI();
    }
  }
  
  static String getDifficultyName(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.strategist:
        return 'Stratège';
      case AIDifficulty.master:
        return 'Maître';
    }
  }
  
  static String getDifficultyDescription(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.strategist:
        return 'Défi équilibré\nAnalyse 3 coups à l\'avance';
      case AIDifficulty.master:
        return 'Défi extrême\nAnalyse 5+ coups avec optimisations';
    }
  }
  
  static Color getDifficultyColor(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.strategist:
        return GameConstants.strategistColor;
      case AIDifficulty.master:
        return GameConstants.masterColor;
    }
  }
}