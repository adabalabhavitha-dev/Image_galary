import 'package:flutter/material.dart';

/// Application-wide constants, keys, and theme settings.
class AppConstants {
  // Application details
  static const String appName = 'My Gallery';
  static const String appVersion = '1.0.0';

  // SharedPreferences keys for persistent storage
  static const String prefsPhotosKey = 'gallery_saved_photos_v1';
  static const String prefsFavoritesKey = 'gallery_favorite_ids_v1';
  static const String prefsThemeModeKey = 'gallery_theme_mode_key';
  static const String prefsIsGridKey = 'gallery_is_grid_view_key';

  // UI layout constants
  static const double cardRadius = 16.0;
  static const double gridSpacing = 12.0;
  static const EdgeInsets screenPadding = EdgeInsets.all(12.0);

  // Modern Material 3 seed colors
  static const Color primarySeedColor = Color(0xFF6750A4); // Deep Purple
  static const Color secondarySeedColor = Color(0xFF00897B); // Teal
  static const Color favoriteColor = Color(0xFFE91E63); // Vibrant Pink/Red
}

/// Sort options available in the gallery.
enum SortOption {
  dateDesc('Newest First', Icons.arrow_downward_rounded),
  dateAsc('Oldest First', Icons.arrow_upward_rounded),
  nameAsc('Name (A-Z)', Icons.sort_by_alpha_rounded),
  nameDesc('Name (Z-A)', Icons.sort_by_alpha_rounded),
  sizeDesc('Largest Size', Icons.data_usage_rounded);

  final String label;
  final IconData icon;
  const SortOption(this.label, this.icon);
}
