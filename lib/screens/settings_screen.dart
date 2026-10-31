import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';

/// Settings screen for theme customization, storage info,
/// sample data management, and gesture guide.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});



  /// Confirmation dialog before clearing all photos
  Future<void> _confirmClearAll(BuildContext context, GalleryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear All Photos?'),
        content: const Text(
          'This will remove all photos currently displayed in your gallery. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.clearAllPhotos();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All photos cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<GalleryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Appearance
          _buildSectionHeader(context, 'Appearance', Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how the gallery looks on your device',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {provider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      provider.setThemeMode(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section: Storage & Stats
          _buildSectionHeader(context, 'Gallery Storage & Stats', Icons.pie_chart_outline_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        title: 'Total Photos',
                        value: '${provider.totalCount}',
                        icon: Icons.photo_library_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      Container(height: 36, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                      _buildStatColumn(
                        context,
                        title: 'Favorites',
                        value: '${provider.favoriteCount}',
                        icon: Icons.favorite_rounded,
                        color: AppConstants.favoriteColor,
                      ),
                      Container(height: 36, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                      _buildStatColumn(
                        context,
                        title: 'Albums',
                        value: '${provider.albums.length}',
                        icon: Icons.folder_special_rounded,
                        color: AppConstants.secondarySeedColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    title: const Text('Clear All Photos', style: TextStyle(color: Colors.redAccent)),
                    subtitle: const Text('Remove all photos from your gallery'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _confirmClearAll(context, provider),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section: Gestures & Learning Tips
          _buildSectionHeader(context, 'Gestures & Shortcuts Guide', Icons.touch_app_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTipRow(
                    context,
                    icon: Icons.pinch_rounded,
                    title: 'Pinch & Double Tap',
                    desc: 'Zoom in and out smoothly inside the full-screen photo viewer.',
                  ),
                  const Divider(height: 20),
                  _buildTipRow(
                    context,
                    icon: Icons.swipe_down_rounded,
                    title: 'Swipe Down to Dismiss',
                    desc: 'Quickly close the full-screen viewer by dragging downwards.',
                  ),
                  const Divider(height: 20),
                  _buildTipRow(
                    context,
                    icon: Icons.touch_app_rounded,
                    title: 'Tap to Toggle Controls',
                    desc: 'Tap once anywhere on the image in full screen to hide or show toolbars.',
                  ),
                  const Divider(height: 20),
                  _buildTipRow(
                    context,
                    icon: Icons.check_box_outlined,
                    title: 'Long-press to Multi-select',
                    desc: 'Long press any photo on the grid to batch favorite, share, or delete.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section: About
          _buildSectionHeader(context, 'About Application', Icons.info_outline_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.photo_library_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Version ${AppConstants.appVersion} • Material 3 & Flutter',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Built with modern Flutter architecture including Provider state management, persistent storage, Hero transitions, and Masonry staggered grid.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTipRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
