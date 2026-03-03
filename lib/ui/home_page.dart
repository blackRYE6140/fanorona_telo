import 'package:flutter/material.dart';
import '../game/constants.dart';
import 'ai_selection_page.dart';
import 'profile_page.dart';
import 'two_players_options_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 720;
    final isVerySmallScreen = screenHeight < 640;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            isVerySmallScreen
                ? 12.0
                : isSmallScreen
                ? 16.0
                : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Profil',
                    icon: Icon(
                      Icons.account_circle_outlined,
                      color: GameConstants.gridColor,
                      size: isSmallScreen ? 30 : 34,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Titre
                            Text(
                              'FANORONA TELO',
                              style: TextStyle(
                                fontSize: isVerySmallScreen
                                    ? 28.0
                                    : isSmallScreen
                                    ? 34.0
                                    : 48.0,
                                fontWeight: FontWeight.bold,
                                color: GameConstants.gridColor,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: GameConstants.gridColor.withAlpha(
                                      127,
                                    ),
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
                                fontSize: isVerySmallScreen
                                    ? 13.0
                                    : isSmallScreen
                                    ? 14.0
                                    : 18.0,
                                color: Colors.white.withAlpha(178),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(
                              height: isVerySmallScreen
                                  ? 26.0
                                  : isSmallScreen
                                  ? 48.0
                                  : 80.0,
                            ),

                            // Option 1: 2 Joueurs
                            _buildOptionCard(
                              context,
                              icon: Icons.people,
                              title: '2 JOUEURS',
                              subtitle: '1 téléphone, socket ou internet',
                              color: GameConstants.neonPink,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TwoPlayersOptionsPage(),
                                  ),
                                );
                              },
                            ),

                            SizedBox(
                              height: isVerySmallScreen
                                  ? 14.0
                                  : isSmallScreen
                                  ? 20.0
                                  : 30.0,
                            ),

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
                                    builder: (context) =>
                                        const AISelectionPage(),
                                  ),
                                );
                              },
                            ),

                            SizedBox(
                              height: isVerySmallScreen
                                  ? 24.0
                                  : isSmallScreen
                                  ? 40.0
                                  : 60.0,
                            ),

                            // Crédits
                            Text(
                              '© Jeu traditionnel malagasy \nDéveloppé par BlackRYE',
                              style: TextStyle(
                                fontSize: isVerySmallScreen
                                    ? 9.0
                                    : isSmallScreen
                                    ? 10.0
                                    : 12.0,
                                color: Colors.white.withAlpha(127),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 720;
    final isVerySmallScreen = screenHeight < 640;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(
          isVerySmallScreen
              ? 16.0
              : isSmallScreen
              ? 20.0
              : 24.0,
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                isVerySmallScreen
                    ? 10.0
                    : isSmallScreen
                    ? 12.0
                    : 16.0,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(51),
              ),
              child: Icon(
                icon,
                color: color,
                size: isVerySmallScreen
                    ? 24.0
                    : isSmallScreen
                    ? 28.0
                    : 32.0,
              ),
            ),

            SizedBox(
              width: isVerySmallScreen
                  ? 12.0
                  : isSmallScreen
                  ? 16.0
                  : 20.0,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isVerySmallScreen
                          ? 16.0
                          : isSmallScreen
                          ? 20.0
                          : 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isVerySmallScreen
                          ? 11.0
                          : isSmallScreen
                          ? 12.0
                          : 14.0,
                      color: Colors.white.withAlpha(178),
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: isVerySmallScreen
                  ? 16.0
                  : isSmallScreen
                  ? 18.0
                  : 20.0,
            ),
          ],
        ),
      ),
    );
  }
}
