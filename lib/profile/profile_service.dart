import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';

class ProfileService {
  static const String _nameKey = 'profile_name';
  static const String _avatarPathKey = 'profile_avatar_path';
  static const String _setupDoneKey = 'profile_setup_done';

  static Future<PlayerProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = (prefs.getString(_nameKey) ?? '').trim();
    final savedAvatarPath = prefs.getString(_avatarPathKey);

    String? avatarPath = savedAvatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (!file.existsSync()) {
        avatarPath = null;
      }
    } else {
      avatarPath = null;
    }

    return PlayerProfile(
      name: savedName.isEmpty ? PlayerProfile.fallback.name : savedName,
      avatarPath: avatarPath,
    );
  }

  static Future<void> saveProfile(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, profile.name.trim());

    final avatarPath = profile.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      await prefs.setString(_avatarPathKey, avatarPath);
    } else {
      await prefs.remove(_avatarPathKey);
    }

    await prefs.setBool(_setupDoneKey, true);
  }

  static Future<bool> isProfileConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final explicitFlag = prefs.getBool(_setupDoneKey);
    if (explicitFlag != null) {
      return explicitFlag;
    }

    // Backward compatibility: infer setup for users who already had a profile
    // before this flag existed.
    final savedName = (prefs.getString(_nameKey) ?? '').trim();
    final savedAvatarPath = (prefs.getString(_avatarPathKey) ?? '').trim();
    final hasCustomName =
        savedName.isNotEmpty && savedName != PlayerProfile.fallback.name;
    final hasAvatar = savedAvatarPath.isNotEmpty;
    return hasCustomName || hasAvatar;
  }

  static Future<bool> isNetworkProfileReady() async {
    final profile = await loadProfile();
    final avatarPath = profile.avatarPath;
    return avatarPath != null && avatarPath.isNotEmpty;
  }

  static Future<String?> avatarPathToBase64(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final file = File(avatarPath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }
}
