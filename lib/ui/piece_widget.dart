import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/constants.dart';

class PieceWidget extends StatelessWidget {
  final GamePiece piece;
  final bool isSelected;
  final bool isDraggable;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  
  const PieceWidget({
    super.key,
    required this.piece,
    this.isSelected = false,
    this.isDraggable = false,
    this.onTap,
    this.onDragStarted,
  });
  
  Color get pieceColor {
    return piece.player == Player.player1
        ? GameConstants.neonPink
        : GameConstants.neonBlue;
  }
  
  @override
  Widget build(BuildContext context) {
    final widget = Container(
      width: GameConstants.pieceRadius * 2,
      height: GameConstants.pieceRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GameConstants.withAlpha(pieceColor, 76), // 0.3 * 255
        border: Border.all(
          color: isSelected ? Colors.white : pieceColor,
          width: isSelected ? 3.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: GameConstants.withAlpha(pieceColor, 127), // 0.5 * 255
            blurRadius: 10.0,
            spreadRadius: 2.0,
          ),
          BoxShadow(
            color: GameConstants.withAlpha(pieceColor, 76), // 0.3 * 255
            blurRadius: 20.0,
            spreadRadius: 5.0,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: GameConstants.pieceRadius,
          height: GameConstants.pieceRadius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                pieceColor,
                GameConstants.withAlpha(pieceColor, 178), // 0.7 * 255
              ],
            ),
          ),
        ),
      ),
    );
    
    if (isDraggable) {
      return Draggable<GamePiece>(
        data: piece,
        feedback: Transform.scale(
          scale: 1.2,
          child: Opacity(
            opacity: 0.8,
            child: widget,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: widget,
        ),
        onDragStarted: onDragStarted,
        child: GestureDetector(
          onTap: onTap,
          child: widget,
        ),
      );
    }
    
    return GestureDetector(
      onTap: onTap,
      child: widget,
    );
  }
}