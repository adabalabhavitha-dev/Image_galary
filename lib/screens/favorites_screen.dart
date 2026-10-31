import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../models/photo_item.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import '../widgets/photo_tile.dart';
import 'full_screen_viewer.dart';

/// Screen dedicated to displaying photos marked as favorites by the user.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  /// Calculates responsive column count based on screen width
  int _getColumnCount(double screenWidth) {
    if (screenWidth >= 900) return 4;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  /// Opens the full-screen photo viewer
  void _openViewer(BuildContext context, List<PhotoItem> favorites, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullScreenViewer(
              initialPhotos: favorites,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<GalleryProvider>(context);
    final favorites = provider.favoritePhotos;
    final isMultiSelect = provider.isMultiSelectMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumnCount(screenWidth);

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Pinned App Bar with title and favorites count
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: isMultiSelect
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: provider.clearSelection,
                  )
                : null,
            title: isMultiSelect
                ? Text('${provider.selectedCount} Selected')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Favorites',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${favorites.length} saved photo${favorites.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
            actions: isMultiSelect
                ? [
                    IconButton(
                      icon: const Icon(Icons.favorite_rounded, color: AppConstants.favoriteColor),
                      tooltip: 'Toggle favorite',
                      onPressed: provider.toggleFavoriteSelected,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      tooltip: 'Share selected',
                      onPressed: provider.shareSelected,
                    ),
                  ]
                : [
                    IconButton(
                      icon: Icon(
                        provider.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      ),
                      tooltip: provider.isGridView ? 'Switch to List' : 'Switch to Grid',
                      onPressed: provider.toggleViewMode,
                    ),
                  ],
          ),

          // Content
          if (favorites.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites yet',
                subtitle: 'Tap the heart icon on any photo in your gallery to collect your favorite memories here.',
              ),
            )
          else if (provider.isGridView)
            SliverPadding(
              padding: AppConstants.screenPadding,
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: AppConstants.gridSpacing,
                crossAxisSpacing: AppConstants.gridSpacing,
                itemBuilder: (context, index) {
                  final photo = favorites[index];
                  final isSelected = provider.selectedIds.contains(photo.id);

                  return PhotoTile(
                    photo: photo,
                    index: index,
                    isGridView: true,
                    isSelected: isSelected,
                    isMultiSelectMode: isMultiSelect,
                    onTap: () {
                      if (isMultiSelect) {
                        provider.toggleSelect(photo.id);
                      } else {
                        _openViewer(context, favorites, index);
                      }
                    },
                    onLongPress: () {
                      if (!isMultiSelect) {
                        provider.enterMultiSelect(photo.id);
                      }
                    },
                    onToggleFavorite: () => provider.toggleFavorite(photo.id),
                  );
                },
                childCount: favorites.length,
              ),
            )
          else
            SliverPadding(
              padding: AppConstants.screenPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = favorites[index];
                    final isSelected = provider.selectedIds.contains(photo.id);

                    return PhotoTile(
                      photo: photo,
                      index: index,
                      isGridView: false,
                      isSelected: isSelected,
                      isMultiSelectMode: isMultiSelect,
                      onTap: () {
                        if (isMultiSelect) {
                          provider.toggleSelect(photo.id);
                        } else {
                          _openViewer(context, favorites, index);
                        }
                      },
                      onLongPress: () {
                        if (!isMultiSelect) {
                          provider.enterMultiSelect(photo.id);
                        }
                      },
                      onToggleFavorite: () => provider.toggleFavorite(photo.id),
                    );
                  },
                  childCount: favorites.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}
