import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../profile/profile_service.dart';
import 'game_page.dart';
import 'profile_page.dart';
import 'network/internet_lobby_page.dart';
import 'network/lan_lobby_page.dart';

class TwoPlayersOptionsPage extends StatelessWidget {
  const TwoPlayersOptionsPage({super.key});

  Future<void> _showNetworkProfileRequiredPopup(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GameConstants.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: GameConstants.gridColor),
          ),
          title: Text(
            'Mise à jour profil',
            style: TextStyle(
              color: GameConstants.gridColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Avant d\'affronter vos amis en réseau, veuillez mettre à jour votre profil (photo obligatoire).',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNetworkLobbyWithProfileGate(
    BuildContext context,
    Widget lobbyPage,
  ) async {
    var isConfigured = await ProfileService.isNetworkProfileReady();
    if (!context.mounted) {
      return;
    }

    if (!isConfigured) {
      final shouldShowPrompt =
          await ProfileService.markNetworkProfilePromptIfFirstTime();
      if (!context.mounted) {
        return;
      }

      if (shouldShowPrompt) {
        await _showNetworkProfileRequiredPopup(context);
        if (!context.mounted) {
          return;
        }
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfilePage(requireAvatarForNetwork: true),
        ),
      );

      if (!context.mounted) {
        return;
      }

      isConfigured = await ProfileService.isNetworkProfileReady();
      if (!context.mounted) {
        return;
      }

      if (!isConfigured) {
        await _showNetworkProfileRequiredPopup(context);
        return;
      }
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => lobbyPage));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final isLargeScreen = screenHeight >= 800;
    final topSpacing = isSmallScreen
        ? 22.0
        : isLargeScreen
        ? 14.0
        : 24.0;
    final cardSpacing = isSmallScreen
        ? 16.0
        : isLargeScreen
        ? 14.0
        : 22.0;

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
              SizedBox(height: topSpacing),
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
                      SizedBox(height: cardSpacing),
                      _buildModeCard(
                        context,
                        icon: Icons.wifi,
                        title: 'RÉSEAU LOCAL (WI-FI)',
                        subtitle:
                            '2 téléphones sur le même Wi-Fi ou point d\'accès',
                        color: GameConstants.neonBlue,
                        onTap: () async {
                          await _openNetworkLobbyWithProfileGate(
                            context,
                            const LanLobbyPage(),
                          );
                        },
                      ),
                      SizedBox(height: cardSpacing),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final isLargeScreen = screenHeight >= 800;
    final cardPadding = isSmallScreen
        ? 18.0
        : isLargeScreen
        ? 20.0
        : 24.0;
    final iconPadding = isSmallScreen
        ? 10.0
        : isLargeScreen
        ? 12.0
        : 14.0;
    final iconSize = isSmallScreen
        ? 26.0
        : isLargeScreen
        ? 28.0
        : 30.0;
    final titleSize = isSmallScreen
        ? 16.0
        : isLargeScreen
        ? 18.0
        : 20.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(cardPadding),
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
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(50),
              ),
              child: Icon(icon, color: color, size: iconSize),
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
                      fontSize: titleSize,
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
