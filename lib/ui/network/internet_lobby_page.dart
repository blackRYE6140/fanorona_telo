import 'package:flutter/material.dart';

import '../../game/constants.dart';
import 'internet_host_page.dart';
import 'internet_join_page.dart';

class InternetLobbyPage extends StatelessWidget {
  const InternetLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(height: isSmallScreen ? 12 : 24),
              Text(
                'CONNEXION INTERNET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 24 : 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Inviter amis publie votre nom + ID.\nRejoindre amis affiche toutes les invitations en direct.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 42),
              _actionCard(
                context,
                title: 'INVITER AMIS',
                subtitle: 'Publier votre profil et attendre un ami',
                icon: Icons.public,
                color: GameConstants.neonBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InternetHostPage()),
                  );
                },
              ),
              SizedBox(height: isSmallScreen ? 16 : 22),
              _actionCard(
                context,
                title: 'REJOINDRE AMIS',
                subtitle: 'Choisir un ami dans la liste des invitations',
                icon: Icons.key,
                color: GameConstants.neonPink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InternetJoinPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(70),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 30 : 36),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: isSmallScreen ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color),
          ],
        ),
      ),
    );
  }
}
