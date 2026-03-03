import 'package:flutter/material.dart';
import '../game/constants.dart';
import '../ai/fanorona_ai.dart';
import 'game_page.dart';

class AISelectionPage extends StatelessWidget {
  const AISelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 360;
    final horizontalPadding = isNarrowScreen
        ? 12.0
        : (isSmallScreen ? 16.0 : 24.0);

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (horizontalPadding * 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bouton retour
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: isSmallScreen ? 24.0 : 28.0,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 12.0 : 28.0),

                    // Titre
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'CHOISISSEZ LA DIFFICULTÉ',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 24.0 : 32.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: isNarrowScreen ? 0.8 : 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 8.0 : 16.0),

                    Text(
                      'Affrontez l\'intelligence artificielle',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.white.withAlpha(178),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 24.0 : 48.0),

                    // Option 1: Stratège
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: _buildDifficultyCard(
                          context,
                          difficulty: AIDifficulty.strategist,
                          icon: Icons.auto_awesome,
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16.0 : 24.0),

                    // Option 2: Maître
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: _buildDifficultyCard(
                          context,
                          difficulty: AIDifficulty.master,
                          icon: Icons.psychology,
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 24.0 : 40.0),

                    // Info
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: GameConstants.gridColor.withAlpha(76),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Conseil',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14.0 : 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Commencez par "Stratège" pour apprendre, '
                                'puis tentez le "Maître" pour un vrai défi !',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
                                  color: Colors.white.withAlpha(178),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context, {
    required AIDifficulty difficulty,
    required IconData icon,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final isNarrowScreen = screenSize.width < 360;
    final color = AIFactory.getDifficultyColor(difficulty);
    final name = AIFactory.getDifficultyName(difficulty);
    final description = AIFactory.getDifficultyDescription(difficulty);
    final strength = difficulty == AIDifficulty.strategist ? 3 : 5;
    final strengthIndicator = _buildStrengthIndicator(
      color,
      strength,
      isSmallScreen,
    );

    return GestureDetector(
      onTap: () => _showStarterChoiceDialog(context, difficulty, color),
      child: Container(
        padding: EdgeInsets.all(
          isNarrowScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0),
        ),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(76),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNarrowScreen)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withAlpha(51),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: isSmallScreen ? 24.0 : 28.0,
                        ),
                      ),

                      SizedBox(width: isSmallScreen ? 10.0 : 16.0),

                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20.0 : 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: strengthIndicator,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withAlpha(51),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: isSmallScreen ? 24.0 : 28.0,
                          ),
                        ),

                        SizedBox(width: isSmallScreen ? 12.0 : 16.0),

                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20.0 : 24.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                  strengthIndicator,
                ],
              ),

            SizedBox(height: isSmallScreen ? 12.0 : 16.0),

            Text(
              description,
              style: TextStyle(
                fontSize: isNarrowScreen ? 12.0 : (isSmallScreen ? 13.0 : 15.0),
                color: Colors.white.withAlpha(178),
                height: 1.4,
              ),
            ),

            SizedBox(height: isSmallScreen ? 12.0 : 16.0),

            // Caractéristiques
            Wrap(
              spacing: isNarrowScreen ? 6 : 8,
              runSpacing: isNarrowScreen ? 6 : 8,
              children: [
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist
                      ? 'Profondeur: 3 coups'
                      : 'Profondeur: 5+ coups',
                  color,
                  isSmallScreen || isNarrowScreen,
                ),
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist
                      ? 'Réaction tactique'
                      : 'Stratégie avancée',
                  color,
                  isSmallScreen || isNarrowScreen,
                ),
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist
                      ? 'Défi équilibré'
                      : 'Presque imbattable',
                  color,
                  isSmallScreen || isNarrowScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator(
    Color color,
    int strength,
    bool isSmallScreen,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isSmallScreen ? 6.0 : 8.0,
          height: isSmallScreen ? 6.0 : 8.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < strength ? color : Colors.white.withAlpha(51),
          ),
        );
      }),
    );
  }

  Future<void> _showStarterChoiceDialog(
    BuildContext context,
    AIDifficulty difficulty,
    Color accentColor,
  ) async {
    final difficultyName = AIFactory.getDifficultyName(difficulty);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: GameConstants.backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withAlpha(90),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QUI COMMENCE ?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mode $difficultyName',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStarterButton(
                  label: 'Humain commence',
                  icon: Icons.person,
                  color: GameConstants.neonPink,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GamePage(
                          mode: GameMode.vsAI,
                          aiDifficulty: difficulty,
                          aiStarts: false,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildStarterButton(
                  label: 'IA commence',
                  icon: Icons.smart_toy,
                  color: GameConstants.neonBlue,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GamePage(
                          mode: GameMode.vsAI,
                          aiDifficulty: difficulty,
                          aiStarts: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarterButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(38),
          foregroundColor: Colors.white,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String text, Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8.0 : 10.0,
        vertical: isSmallScreen ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(102), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 10.0 : 11.0,
          color: Colors.white.withAlpha(204),
        ),
      ),
    );
  }
}
