import 'package:flutter/material.dart';
import '../game/constants.dart';

class NeonBoardPainter extends CustomPainter {
  final List<Offset> piecePositions;
  final List<Color> pieceColors;
  final Offset? selectedPosition;
  
  NeonBoardPainter({
    required this.piecePositions,
    required this.pieceColors,
    this.selectedPosition,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawPieces(canvas, size);
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = GameConstants.gridColor
      ..strokeWidth = GameConstants.gridLineWidth
      ..style = PaintingStyle.stroke;
    
    final cellWidth = size.width / 2;
    final cellHeight = size.height / 2;
    
    // Lignes horizontales
    for (int i = 0; i <= 2; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Lignes verticales
    for (int i = 0; i <= 2; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Diagonales
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), gridPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), gridPaint);
    
    // Points d'intersection avec effet glow
    final pointPaint = Paint()
      ..color = GameConstants.gridColor
      ..style = PaintingStyle.fill;
    
    for (int x = 0; x <= 2; x++) {
      for (int y = 0; y <= 2; y++) {
        final pos = Offset(x * cellWidth, y * cellHeight);
        
        // Effet de glow
        final glowPaint = Paint()
          ..color = GameConstants.withAlpha(GameConstants.gridColor, 50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        
        canvas.drawCircle(pos, 8, glowPaint);
        canvas.drawCircle(pos, 4, pointPaint);
      }
    }
  }
  
  void _drawPieces(Canvas canvas, Size size) {
    for (int i = 0; i < piecePositions.length; i++) {
      _drawPieceWithGlow(
        canvas,
        piecePositions[i],
        pieceColors[i],
        isSelected: selectedPosition == piecePositions[i],
      );
    }
  }
  
  void _drawPieceWithGlow(Canvas canvas, Offset position, Color color, {bool isSelected = false}) {
    final radius = GameConstants.pieceRadius;
    
    // Effet de lueur (plusieurs cercles superposés)
    final glowColors = [
      GameConstants.withAlpha(color, 25),
      GameConstants.withAlpha(color, 50),
      GameConstants.withAlpha(color, 75),
    ];
    
    final glowSizes = [radius * 1.8, radius * 1.4, radius * 1.1];
    
    for (int i = 0; i < glowColors.length; i++) {
      final glowPaint = Paint()
        ..color = glowColors[i]
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      
      canvas.drawCircle(position, glowSizes[i], glowPaint);
    }
    
    // Cercle principal
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, radius, mainPaint);
    
    // Effet de lumière interne
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          GameConstants.withAlpha(color, 204), // 0.8 * 255
          GameConstants.withAlpha(color, 100),
        ],
      ).createShader(Rect.fromCircle(center: position, radius: radius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, radius * 0.7, innerPaint);
    
    // Bordure sélection
    if (isSelected) {
      final selectionPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
      canvas.drawCircle(position, radius + 2, selectionPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant NeonBoardPainter oldDelegate) {
    return oldDelegate.piecePositions != piecePositions ||
           oldDelegate.pieceColors != pieceColors ||
           oldDelegate.selectedPosition != selectedPosition;
  }
}