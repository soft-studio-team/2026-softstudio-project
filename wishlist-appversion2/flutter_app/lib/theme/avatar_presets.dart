/// Built-in DiceBear thumbs avatars for profile picker.
class AvatarPresets {
  AvatarPresets._();

  static const _style = 'thumbs';

  /// Five fixed seeds so the choices stay the same for everyone.
  static const seeds = ['wishkit', 'peach', 'mint', 'stone', 'coral'];

  static List<String> get urls => [
        for (final seed in seeds) urlForSeed(seed),
      ];

  static String urlForSeed(String seed) =>
      'https://api.dicebear.com/7.x/$_style/png?seed=${Uri.encodeComponent(seed)}';

  static bool isPreset(String url) => urls.contains(url);
}

/// Same thumbs character as the default profile, with five mouth expressions.
class ReviewMood {
  const ReviewMood({
    required this.level,
    required this.label,
    required this.mouth,
  });

  final int level;
  final String label;
  final String mouth;

  String get url =>
      '${AvatarPresets.urlForSeed('wishkit')}&mouth=$mouth';

  static const all = [
    ReviewMood(level: 1, label: '아쉬워요', mouth: 'sad'),
    ReviewMood(level: 2, label: '그저 그래요', mouth: 'variant4'),
    ReviewMood(level: 3, label: '괜찮아요', mouth: 'variant2'),
    ReviewMood(level: 4, label: '좋아요', mouth: 'variant1'),
    ReviewMood(level: 5, label: '최고예요', mouth: 'smile'),
  ];

  static ReviewMood byLevel(int level) => all.firstWhere(
        (m) => m.level == level,
        orElse: () => all[2],
      );
}
