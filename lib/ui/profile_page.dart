import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../game/constants.dart';
import '../profile/player_profile.dart';
import '../profile/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _avatarPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.loadProfile();
    if (!mounted) return;

    setState(() {
      _nameController.text = profile.name;
      _avatarPath = profile.avatarPath;
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _avatarPath = image.path;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final normalizedName = name.isEmpty ? PlayerProfile.fallback.name : name;

    final profile = PlayerProfile(name: normalizedName, avatarPath: _avatarPath);
    await ProfileService.saveProfile(profile);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil enregistré.')),
    );
    Navigator.pop(context);
  }

  void _removeAvatar() {
    setState(() {
      _avatarPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: GameConstants.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: GameConstants.gridColor),
        ),
      );
    }

    final avatarFile =
        _avatarPath != null && _avatarPath!.isNotEmpty ? File(_avatarPath!) : null;

    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Profil Joueur',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: GameConstants.gridColor, width: 2),
                        color: Colors.black.withAlpha(55),
                      ),
                      child: ClipOval(
                        child: avatarFile != null && avatarFile.existsSync()
                            ? Image.file(avatarFile, fit: BoxFit.cover)
                            : Icon(
                                Icons.person,
                                color: Colors.white.withAlpha(170),
                                size: 64,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: GameConstants.gridColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (avatarFile != null)
                TextButton.icon(
                  onPressed: _removeAvatar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer l\'image'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
              const SizedBox(height: 16),
              Text(
                'Nom du joueur',
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Ethan',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  filled: true,
                  fillColor: Colors.black.withAlpha(70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: GameConstants.gridColor.withAlpha(130)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: GameConstants.gridColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameConstants.gridColor.withAlpha(45),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: GameConstants.gridColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
