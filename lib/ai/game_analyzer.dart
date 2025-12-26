import '../game/game_state.dart';
import '../game/constants.dart';
import 'pattern_recognizer.dart';

class GameAnalyzer {
  final List<GameState> _gameHistory = [];
  final List<String> _moveDescriptions = [];
  
  void recordMove(GameState state, String description) {
    _gameHistory.add(GameState(
      pieces: List.from(state.pieces),
      currentPlayer: state.currentPlayer,
      phase: state.phase,
      status: state.status,
      turnsPlayed: state.turnsPlayed,
    ));
    _moveDescriptions.add(description);
  }
  
  void analyzeCriticalPosition(GameState state, Player playerToAnalyze) {
    print('\n=== ANALYSE DE POSITION CRITIQUE ===');
    
    // 1. Menaces immédiates
    final winningMoves = PatternRecognizer.findWinningMoves(state, playerToAnalyze);
    print('Coups gagnants: ${winningMoves.length}');
    
    // 2. Menaces adverses à bloquer
    final opponent = playerToAnalyze == Player.player1 ? Player.player2 : Player.player1;
    final threats = PatternRecognizer.findThreatsToBlock(state, opponent);
    print('Menaces adverses à bloquer: ${threats.length}');
    
    for (var threat in threats) {
      print('  - Menace sur position: (${threat.x},${threat.y})');
      
      // Vérifier pourquoi c'est une menace
      _analyzeThreatLine(state, threat, opponent);
    }
    
    // 3. Fourchettes possibles
    final forks = PatternRecognizer.findForkMoves(state, playerToAnalyze);
    print('Fourchettes possibles: ${forks.length}');
    
    // 4. Évaluation de la position
    final score = PatternRecognizer.quickEvaluate(state, playerToAnalyze);
    print('Score de position: $score');
    
    // 5. Afficher le plateau
    _printBoard(state);
  }
  
  void _analyzeThreatLine(GameState state, GridPosition threatPos, Player opponent) {
    // Trouver quelle ligne contient cette menace
    final allLines = PatternRecognizer.winningLines;
    
    for (var line in allLines) {
      if (line.contains(threatPos)) {
        // Compter les pièces sur cette ligne
        int opponentCount = 0;
        int emptyCount = 0;
        List<GridPosition> emptyPositions = [];
        
        for (var pos in line) {
          final piece = state.getPieceAt(pos);
          if (piece == null) {
            emptyCount++;
            emptyPositions.add(pos);
          } else if (piece.player == opponent) {
            opponentCount++;
          }
        }
        
        if (opponentCount == 2 && emptyCount == 1) {
          print('    → Ligne: ${_positionsToString(line)}');
          print('    → Pièces adverses: $opponentCount, Case vide: (${threatPos.x},${threatPos.y})');
        }
      }
    }
  }
  
  void _printBoard(GameState state) {
    print('\nPlateau:');
    print('  0 1 2 y');
    for (int y = 2; y >= 0; y--) {
      String row = '$y ';
      for (int x = 0; x <= 2; x++) {
        final piece = state.getPieceAt(GridPosition(x, y));
        if (piece == null) {
          row += '. ';
        } else if (piece.player == Player.player1) {
          row += 'R ';
        } else {
          row += 'B ';
        }
      }
      print(row);
    }
    print('x\n');
  }
  
  String _positionsToString(List<GridPosition> positions) {
    return positions.map((p) => '(${p.x},${p.y})').join(' - ');
  }
  
  void printGameHistory() {
    print('\n=== HISTORIQUE DE LA PARTIE ===');
    for (int i = 0; i < _gameHistory.length; i++) {
      print('Tour ${i + 1}: ${_moveDescriptions[i]}');
      _printBoard(_gameHistory[i]);
    }
  }
}