import 'package:flutter/material.dart';
import '../game/constants.dart';
import 'game_page.dart';
import 'ai_selection_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre
              Text(
                'FANORONA TELO',
                style: TextStyle(
                  fontSize: isSmallScreen ? 32.0 : 48.0,
                  fontWeight: FontWeight.bold,
                  color: GameConstants.gridColor,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: GameConstants.gridColor.withAlpha(127),
                      blurRadius: 10,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 8.0 : 16.0),
              
              Text(
                'Jeu Traditionnel Malagasy',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.0 : 18.0,
                  color: Colors.white.withAlpha(178),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 40.0 : 80.0),
              
              // Option 1: 2 Joueurs
              _buildOptionCard(
                context,
                icon: Icons.people,
                title: '2 JOUEURS',
                subtitle: 'Affrontez un ami',
                color: GameConstants.neonPink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GamePage(
                        mode: GameMode.twoPlayers,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: isSmallScreen ? 20.0 : 30.0),
              
              // Option 2: Contre IA
              _buildOptionCard(
                context,
                icon: Icons.computer,
                title: 'CONTRE IA',
                subtitle: 'Défiez l\'intelligence artificielle',
                color: GameConstants.neonBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AISelectionPage(),
                    ),
                  );
                },
              ),
              
              SizedBox(height: isSmallScreen ? 40.0 : 60.0),
              
              // Crédits
              Text(
                '© Jeu traditionnel malagasy \nDéveloppé par BlackRYE',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10.0 : 12.0,
                  color: Colors.white.withAlpha(127),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600;
    
    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(51),
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 28.0 : 32.0,
              ),
            ),
            
            SizedBox(width: isSmallScreen ? 16.0 : 20.0),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20.0 : 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 14.0,
                      color: Colors.white.withAlpha(178),
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: isSmallScreen ? 18.0 : 20.0,
            ),
          ],
        ),
      ),
    );
  }
}