class PlayerProfile {
  final String name;
  final String? avatarPath;

  const PlayerProfile({
    required this.name,
    this.avatarPath,
  });

  PlayerProfile copyWith({
    String? name,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return PlayerProfile(
      name: name ?? this.name,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  static const PlayerProfile fallback = PlayerProfile(name: 'Joueur');
}
