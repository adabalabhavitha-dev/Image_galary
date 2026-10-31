import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';

/// A friendly, Material 3 styled permission screen displayed when
/// photo/media storage permission has not been granted.
///
/// Clearly explains why access is needed and provides actions to grant
/// permission directly or navigate to system settings.
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> _handleGrantPermission(BuildContext context) async {
    final provider = Provider.of<GalleryProvider>(context, listen: false);
    await provider.requestPermission();
    if (!provider.hasPermission && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Permission was not granted. You can enable it in Settings.',
          ),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () => PhotoManager.openSetting(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Top Hero Icon Container
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.secondaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      size: 54,
                      color: colorScheme.primary,
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fade(duration: 400.ms),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Access Your Photos',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, delay: 150.ms),

                  const SizedBox(height: 14),

                  // Subtitle Explanation
                  Text(
                    'To view, organize, and browse your device photos and albums, '
                    'My Gallery needs permission to access your media storage.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms),

                  const SizedBox(height: 32),

                  // Feature Cards
                  _buildFeatureTile(
                    context,
                    icon: Icons.collections_rounded,
                    title: 'Browse Device Albums',
                    subtitle: 'Camera, Screenshots, Downloads, and custom folders.',
                    delayMs: 350,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureTile(
                    context,
                    icon: Icons.bolt_rounded,
                    title: 'Fast MediaStore Thumbnails',
                    subtitle: 'Hardware-accelerated loading with minimal memory usage.',
                    delayMs: 450,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureTile(
                    context,
                    icon: Icons.lock_outline_rounded,
                    title: '100% Private & On-Device',
                    subtitle: 'Your media never leaves your phone or gets uploaded.',
                    delayMs: 550,
                  ),

                  const SizedBox(height: 40),

                  // Grant Permission Primary Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _handleGrantPermission(context),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Grant Permission',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 650.ms, duration: 400.ms)
                      .slideY(begin: 0.15, end: 0, delay: 650.ms),

                  const SizedBox(height: 14),

                  // Open Settings Secondary Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => PhotoManager.openSetting(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text(
                        'Open Settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 750.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Small Helper Hint
                  Text(
                    'If you previously selected "Don\'t ask again", tap "Open Settings" to enable permissions manually.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int delayMs,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 350.ms)
        .slideX(begin: 0.08, end: 0, delay: delayMs.ms);
  }
}
