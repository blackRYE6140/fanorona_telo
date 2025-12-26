import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/game_logic.dart';
import '../game/constants.dart';
import 'neon_board_painter.dart';
import 'piece_widget.dart';
import '../utils/position_utils.dart';

class GameBoard extends StatefulWidget {
  final GameState gameState;
  final Function(GameState) onStateChanged;
  
  const GameBoard({
    super.key,
    required this.gameState,
    required this.onStateChanged,
  });
  
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  // ignore: unused_field
  Size _boardSize = Size.zero;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        
        return Container(
          decoration: BoxDecoration(
            color: GameConstants.backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Plateau de fond
              CustomPaint(
                size: boardSize,
                painter: _buildBoardPainter(boardSize),
              ),
              
              // Pièces
              ..._buildPieces(boardSize),
              
              // Zones de drop pour le drag & drop
              if (widget.gameState.isMovementPhase)
                ..._buildDropTargets(boardSize),
              
              // Overlay pour les clics (phase placement)
              if (widget.gameState.isPlacementPhase &&
                  widget.gameState.status == GameStatus.playing)
                _buildPlacementOverlay(boardSize),
            ],
          ),
        );
      },
    );
  }
  
  NeonBoardPainter _buildBoardPainter(Size boardSize) {
    final piecePositions = widget.gameState.pieces.map((piece) {
      return PositionUtils.gridToScreen(piece.position, boardSize);
    }).toList();
    
    final pieceColors = widget.gameState.pieces.map((piece) {
      return piece.player == Player.player1
          ? GameConstants.neonPink
          : GameConstants.neonBlue;
    }).toList();
    
    final selectedPosition = widget.gameState.selectedPiece != null
        ? PositionUtils.gridToScreen(
            widget.gameState.selectedPiece!.position,
            boardSize,
          )
        : null;
    
    return NeonBoardPainter(
      piecePositions: piecePositions,
      pieceColors: pieceColors,
      selectedPosition: selectedPosition,
    );
  }
  
  List<Widget> _buildPieces(Size boardSize) {
    _boardSize = boardSize;
    
    return widget.gameState.pieces.map((piece) {
      final screenPos = PositionUtils.gridToScreen(piece.position, boardSize);
      final isSelected = widget.gameState.selectedPiece == piece;
      final isDraggable = widget.gameState.isMovementPhase &&
          piece.player == widget.gameState.currentPlayer &&
          widget.gameState.status == GameStatus.playing;
      
      return Positioned(
        left: screenPos.dx - GameConstants.pieceRadius,
        top: screenPos.dy - GameConstants.pieceRadius,
        child: PieceWidget(
          piece: piece,
          isSelected: isSelected,
          isDraggable: isDraggable,
          onTap: () => _onPieceTapped(piece),
          onDragStarted: () => _onDragStarted(piece),
        ),
      );
    }).toList();
  }
  
  List<Widget> _buildDropTargets(Size boardSize) {
    List<Widget> targets = [];
    
    // Crée une zone de drop pour chaque position adjacente possible
    if (widget.gameState.selectedPiece != null) {
      final adjacentPositions = PositionUtils.getAdjacentPositions(
        widget.gameState.selectedPiece!.position,
      );
      
      for (var gridPos in adjacentPositions) {
        // Vérifie si la position est libre
        if (!widget.gameState.isPositionOccupied(gridPos)) {
          final screenPos = PositionUtils.gridToScreen(gridPos, boardSize);
          
          targets.add(
            Positioned(
              left: screenPos.dx - 25,
              top: screenPos.dy - 25,
              child: DragTarget<GamePiece>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GameConstants.withAlpha(Colors.white, 25),
                      border: Border.all(
                        color: GameConstants.withAlpha(Colors.white, 76),
                        width: 2,
                      ),
                    ),
                  );
                },
                onAccept: (piece) {
                  _onPieceDropped(piece, gridPos);
                },
              ),
            ),
          );
        }
      }
    }
    
    return targets;
  }
  
  Widget _buildPlacementOverlay(Size boardSize) {
    return GestureDetector(
      onTapDown: (details) {
        final localPos = details.localPosition;
        final gridPos = PositionUtils.screenToGrid(localPos, boardSize);
        
        if (gridPos != null) {
          _onBoardTapped(gridPos);
        }
      },
      child: Container(
        color: Colors.transparent,
      ),
    );
  }
  
  void _onBoardTapped(GridPosition gridPos) {
    if (widget.gameState.isPlacementPhase &&
        widget.gameState.status == GameStatus.playing) {
      final newState = GameLogic.placePiece(widget.gameState, gridPos);
      widget.onStateChanged(newState);
    }
  }
  
  void _onPieceTapped(GamePiece piece) {
    if (widget.gameState.isMovementPhase &&
        piece.player == widget.gameState.currentPlayer &&
        widget.gameState.status == GameStatus.playing) {
      
      final newState = GameLogic.selectPiece(
        widget.gameState,
        widget.gameState.selectedPiece == piece ? null : piece,
      );
      widget.onStateChanged(newState);
    }
  }
  
  void _onDragStarted(GamePiece piece) {
    if (widget.gameState.isMovementPhase &&
        piece.player == widget.gameState.currentPlayer &&
        widget.gameState.status == GameStatus.playing) {
      
      final newState = GameLogic.selectPiece(widget.gameState, piece);
      widget.onStateChanged(newState);
    }
  }
  
  void _onPieceDropped(GamePiece piece, GridPosition newGridPos) {
    if (widget.gameState.isMovementPhase &&
        widget.gameState.status == GameStatus.playing) {
      
      final newState = GameLogic.movePiece(
        widget.gameState,
        piece,
        newGridPos,
      );
      widget.onStateChanged(newState);
    }
  }
}