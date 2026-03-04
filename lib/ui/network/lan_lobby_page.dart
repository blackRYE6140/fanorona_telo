import 'package:flutter/material.dart';

import '../../game/constants.dart';
import 'lan_host_page.dart';
import 'lan_join_page.dart';

class LanLobbyPage extends StatelessWidget {
  const LanLobbyPage({super.key});

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
                'RÉSEAU LOCAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 26 : 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Créez une partie puis partagez le QR code.\n'
                'Astuce: connectez les 2 téléphones au même Wi-Fi, ou activez '
                'le point d\'accès sur l\'un puis connectez l\'autre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
              SizedBox(height: isSmallScreen ? 28 : 50),
              _actionCard(
                context,
                title: 'CRÉER',
                subtitle: 'Créer une partie et afficher le QR code',
                icon: Icons.hub,
                color: GameConstants.neonBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanHostPage()),
                  );
                },
              ),
              SizedBox(height: isSmallScreen ? 16 : 22),
              _actionCard(
                context,
                title: 'REJOINDRE',
                subtitle: 'Scanner le QR code du créateur',
                icon: Icons.qr_code_scanner,
                color: GameConstants.neonPink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanJoinPage()),
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
