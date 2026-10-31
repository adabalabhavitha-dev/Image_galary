import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/photo_item.dart';
import '../utils/constants.dart';

/// A reusable tile widget for presenting photos in either staggered/uniform grid
/// or list view.
///
/// Uses memory-efficient MediaStore thumbnails via [PhotoItem.thumbnailProvider],
/// supports Hero transitions ('photo_${photo.id}'), favorite toggling, and
/// Material 3 multi-select badges.
class PhotoTile extends StatelessWidget {
  final PhotoItem photo;
  final int index;
  final bool isGridView;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.index,
    required this.isGridView,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger animation delay slightly by index so tiles cascade gracefully
    final animDelay = (index % 12 * 35).ms;

    final child = isGridView
        ? _buildGridCard(context)
        : _buildListCard(context);

    return child
        .animate()
        .fade(duration: 350.ms, delay: animDelay, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          delay: animDelay,
          curve: Curves.easeOutCubic,
        );
  }

  /// Builds the grid card representation with MediaStore thumbnail
  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 3)
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius - (isSelected ? 2 : 0)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fast MediaStore thumbnail with Hero animation
                Hero(
                  tag: 'photo_${photo.id}',
                  child: _buildImageWidget(context),
                ),

                // Multi-select active overlay tint
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                    ),
                  ),

                // Bottom gradient for readable photo name & date
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 22, 8, 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          photo.formattedDate,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Right: Favorite heart indicator
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        photo.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        size: 17,
                        color: photo.isFavorite
                            ? AppConstants.favoriteColor
                            : Colors.white,
                      ),
                    ),
                  ),
                ),

                // Top Left: Multi-select indicator badge
                if (isMultiSelectMode)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the horizontal list card representation
  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // Left: Image Thumbnail with Hero
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'photo_${photo.id}',
                        child: _buildImageWidget(context),
                      ),
                      if (isSelected)
                        Container(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          child: const Center(
                            child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Middle: File Metadata details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${photo.formattedDate} • ${photo.formattedTime}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          photo.resolutionString,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        FutureBuilder<String>(
                          future: photo.formattedFileSize,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == 'Unknown size') {
                              return const SizedBox.shrink();
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  '•  ${snapshot.data}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: Multi-select indicator or Favorite heart
              if (isMultiSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    photo.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: photo.isFavorite
                        ? AppConstants.favoriteColor
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: onToggleFavorite,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders fast MediaStore thumbnail using photo.thumbnailProvider
  Widget _buildImageWidget(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Image(
      image: photo.thumbnailProvider,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return Container(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 32,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
