import 'package:flutter/material.dart';
import '../game/constants.dart';
import '../ai/fanorona_ai.dart';
import 'game_page.dart';

class AISelectionPage extends StatelessWidget {
  const AISelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
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
              
              SizedBox(height: isSmallScreen ? 20.0 : 40.0),
              
              // Titre
              Text(
                'CHOISISSEZ LA DIFFICULTÉ',
                style: TextStyle(
                  fontSize: isSmallScreen ? 24.0 : 32.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
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
              
              SizedBox(height: isSmallScreen ? 40.0 : 60.0),
              
              // Option 1: Stratège
              _buildDifficultyCard(
                context,
                difficulty: AIDifficulty.strategist,
                icon: Icons.auto_awesome,
              ),
              
              SizedBox(height: isSmallScreen ? 20.0 : 30.0),
              
              // Option 2: Maître
              _buildDifficultyCard(
                context,
                difficulty: AIDifficulty.master,
                icon: Icons.psychology,
              ),
              
              SizedBox(height: isSmallScreen ? 40.0 : 60.0),
              
              // Info
              Container(
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
                      '💡 Conseil',
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
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDifficultyCard(
    BuildContext context, {
    required AIDifficulty difficulty,
    required IconData icon,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600;
    final color = AIFactory.getDifficultyColor(difficulty);
    final name = AIFactory.getDifficultyName(difficulty);
    final description = AIFactory.getDifficultyDescription(difficulty);
    final strength = difficulty == AIDifficulty.strategist ? 3 : 5;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GamePage(
              mode: GameMode.vsAI,
              aiDifficulty: difficulty,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    
                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                    
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20.0 : 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Indicateur de force
                Row(
                  children: List.generate(5, (index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      width: isSmallScreen ? 6.0 : 8.0,
                      height: isSmallScreen ? 6.0 : 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < strength ? color : Colors.white.withAlpha(51),
                      ),
                    );
                  }),
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            
            Text(
              description,
              style: TextStyle(
                fontSize: isSmallScreen ? 13.0 : 15.0,
                color: Colors.white.withAlpha(178),
                height: 1.4,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            
            // Caractéristiques
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist 
                      ? 'Profondeur: 3 coups' 
                      : 'Profondeur: 5+ coups',
                  color,
                  isSmallScreen,
                ),
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist 
                      ? 'Réaction tactique' 
                      : 'Stratégie avancée',
                  color,
                  isSmallScreen,
                ),
                _buildFeatureChip(
                  difficulty == AIDifficulty.strategist 
                      ? 'Défi équilibré' 
                      : 'Presque imbattable',
                  color,
                  isSmallScreen,
                ),
              ],
            ),
          ],
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