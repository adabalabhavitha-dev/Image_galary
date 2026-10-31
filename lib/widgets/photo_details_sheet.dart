import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/photo_item.dart';
import '../utils/constants.dart';

/// Modal bottom sheet displaying detailed technical & capture metadata for a photo.
class PhotoDetailsSheet extends StatelessWidget {
  final PhotoItem photo;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const PhotoDetailsSheet({
    super.key,
    required this.photo,
    this.onShare,
    this.onDelete,
  });

  /// Static helper to display the sheet easily from any screen
  static void show(
    BuildContext context, {
    required PhotoItem photo,
    VoidCallback? onShare,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoDetailsSheet(
        photo: photo,
        onShare: onShare,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        photo.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Metadata items
            _buildInfoRow(
              context,
              icon: Icons.title_rounded,
              title: 'File Name',
              value: photo.name,
            ),
            _buildInfoRow(
              context,
              icon: Icons.calendar_today_rounded,
              title: 'Date & Time Added',
              value: '${photo.formattedDate} at ${photo.formattedTime}',
            ),
            _buildInfoRow(
              context,
              icon: Icons.update_rounded,
              title: 'Date Modified',
              value: '${DateFormat.yMMMd().format(photo.asset.modifiedDateTime)} at ${DateFormat.jm().format(photo.asset.modifiedDateTime)}',
            ),
            _buildInfoRow(
              context,
              icon: Icons.aspect_ratio_rounded,
              title: 'Resolution',
              value: photo.resolutionString,
            ),
            FutureBuilder<String>(
              future: photo.formattedFileSize,
              builder: (context, snapshot) {
                return _buildInfoRow(
                  context,
                  icon: Icons.sd_card_outlined,
                  title: 'File Size',
                  value: snapshot.data ?? 'Calculating size...',
                );
              },
            ),
            _buildInfoRow(
              context,
              icon: Icons.category_outlined,
              title: 'Source',
              value: 'Device MediaStore',
            ),
            _buildInfoRow(
              context,
              icon: photo.isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              iconColor: photo.isFavorite ? AppConstants.favoriteColor : null,
              title: 'Favorite Status',
              value: photo.isFavorite ? 'Marked as Favorite' : 'Not Favorited',
            ),
            FutureBuilder<String?>(
              future: photo.filePath,
              builder: (context, snapshot) {
                final path = snapshot.data ?? photo.path;
                return _buildInfoRow(
                  context,
                  icon: Icons.folder_open_rounded,
                  title: 'File Path',
                  value: path.isNotEmpty ? path : 'Loading path...',
                  canCopy: snapshot.hasData && snapshot.data != null,
                );
              },
            ),

            const SizedBox(height: 20),

            // Quick Action Buttons
            Row(
              children: [
                if (onShare != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onShare!();
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (onShare != null && onDelete != null) const SizedBox(width: 12),
                if (onDelete != null)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
    bool canCopy = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: canCopy ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'Copy path',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Path copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
