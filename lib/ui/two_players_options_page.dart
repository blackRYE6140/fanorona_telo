import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../profile/profile_service.dart';
import 'game_page.dart';
import 'profile_page.dart';
import 'network/internet_lobby_page.dart';
import 'network/lan_lobby_page.dart';

class TwoPlayersOptionsPage extends StatelessWidget {
  const TwoPlayersOptionsPage({super.key});

  Future<void> _openNetworkLobbyWithProfileGate(
    BuildContext context,
    Widget lobbyPage,
  ) async {
    var isConfigured = await ProfileService.isNetworkProfileReady();
    if (!context.mounted) {
      return;
    }

    if (!isConfigured) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );

      if (!context.mounted) {
        return;
      }

      isConfigured = await ProfileService.isNetworkProfileReady();
      if (!context.mounted) {
        return;
      }

      if (!isConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez ajouter une photo de profil pour jouer en réseau.',
            ),
          ),
        );
        return;
      }
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => lobbyPage));
  }

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
                '2 JOUEURS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 26 : 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 14),
              Text(
                'Choisissez le type de connexion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: isSmallScreen ? 13 : 15,
                ),
              ),
              SizedBox(height: isSmallScreen ? 22 : 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildModeCard(
                        context,
                        icon: Icons.phone_android,
                        title: '2 AMIS SUR 1 TÉLÉPHONE',
                        subtitle: 'Jouer localement sur le même appareil',
                        color: GameConstants.gridColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const GamePage(mode: GameMode.twoPlayers),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      _buildModeCard(
                        context,
                        icon: Icons.wifi,
                        title: 'SOCKET RÉSEAU LOCAL',
                        subtitle: '2 téléphones sur le même Wi-Fi',
                        color: GameConstants.neonBlue,
                        onTap: () async {
                          await _openNetworkLobbyWithProfileGate(
                            context,
                            const LanLobbyPage(),
                          );
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      _buildModeCard(
                        context,
                        icon: Icons.public,
                        title: 'CONNEXION INTERNET',
                        subtitle: '2 téléphones à distance',
                        color: GameConstants.neonPink,
                        onTap: () async {
                          await _openNetworkLobbyWithProfileGate(
                            context,
                            const InternetLobbyPage(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
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
        padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
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
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(50),
              ),
              child: Icon(icon, color: color, size: isSmallScreen ? 26 : 30),
            ),
            SizedBox(width: isSmallScreen ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(170),
                      fontSize: isSmallScreen ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: isSmallScreen ? 16 : 18,
            ),
          ],
        ),
      ),
    );
  }
}
