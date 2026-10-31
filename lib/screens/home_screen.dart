import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../models/photo_item.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import '../widgets/photo_tile.dart';
import 'full_screen_viewer.dart';
import 'permission_screen.dart';

/// The primary gallery home screen featuring a modern collapsing SliverAppBar,
/// photos grouped by date section headers ("Today", "Yesterday", "12 Oct", etc.),
/// masonry grid / list view toggle, search bar, sort options, multi-select toolbar,
/// lazy loading scroll listener, and extended Floating Action Button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Lazy loading listener: loads next page when scrolling within 400px of bottom
  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 400) {
        final provider = Provider.of<GalleryProvider>(context, listen: false);
        if (!provider.isLoadingMore && provider.hasMorePhotos) {
          provider.loadNextPage();
        }
      }
    }
  }

  /// Calculates responsive column count based on screen width
  int _getColumnCount(double screenWidth) {
    if (screenWidth >= 900) return 4;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  /// Opens the full-screen photo viewer
  void _openViewer(BuildContext context, List<PhotoItem> photos, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullScreenViewer(
              initialPhotos: photos,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }

  /// Captures a photo using the device camera and adds it to the gallery
  Future<void> _clickPhoto(BuildContext context, GalleryProvider provider) async {
    try {
      final added = await provider.capturePhotoFromCamera();
      if (added && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo clicked and added to gallery!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Confirmation dialog for deleting multi-selected photos
  Future<void> _confirmDeleteSelected(GalleryProvider provider) async {
    final count = provider.selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Selected Photos?'),
        content: Text('Are you sure you want to delete $count selected photo${count > 1 ? 's' : ''}? You can undo this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deleteSelected();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted $count photo${count > 1 ? 's' : ''}'),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppConstants.primarySeedColor,
              onPressed: () => provider.undoDelete(),
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<GalleryProvider>(context);

    // If permission has not been granted, display friendly PermissionScreen
    if (!provider.hasPermission) {
      return const PermissionScreen();
    }

    final photos = provider.filteredPhotos;
    final isMultiSelect = provider.isMultiSelectMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumnCount(screenWidth);
    final grouped = provider.dateGroupedPhotos;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshGallery();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Modern Collapsing SliverAppBar
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: isMultiSelect ? 80.0 : (_isSearchExpanded ? 130.0 : 100.0),
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: isMultiSelect
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Exit selection',
                      onPressed: provider.clearSelection,
                    )
                  : null,
              title: isMultiSelect
                  ? Text(
                      '${provider.selectedCount} Selected',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${provider.totalCount} photo${provider.totalCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
              actions: isMultiSelect
                  ? [
                      IconButton(
                        icon: const Icon(Icons.select_all_rounded),
                        tooltip: 'Select All',
                        onPressed: provider.selectAll,
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_outline_rounded),
                        tooltip: 'Favorite Selected',
                        onPressed: provider.toggleFavoriteSelected,
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        tooltip: 'Share Selected',
                        onPressed: provider.shareSelected,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Delete Selected',
                        onPressed: () => _confirmDeleteSelected(provider),
                      ),
                    ]
                  : [
                      // Search button
                      IconButton(
                        icon: Icon(_isSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded),
                        tooltip: _isSearchExpanded ? 'Close Search' : 'Search Photos',
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = !_isSearchExpanded;
                            if (!_isSearchExpanded) {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            }
                          });
                        },
                      ),

                      // Grid vs List view toggle
                      IconButton(
                        icon: Icon(
                          provider.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        ),
                        tooltip: provider.isGridView ? 'Switch to List' : 'Switch to Grid',
                        onPressed: provider.toggleViewMode,
                      ),

                      // Sort options popup menu
                      PopupMenuButton<SortOption>(
                        icon: const Icon(Icons.sort_rounded),
                        tooltip: 'Sort photos',
                        onSelected: provider.setSortOption,
                        itemBuilder: (context) => SortOption.values.map((sort) {
                          final isSelected = provider.currentSort == sort;
                          return PopupMenuItem(
                            value: sort,
                            child: Row(
                              children: [
                                Icon(
                                  sort.icon,
                                  size: 18,
                                  color: isSelected ? colorScheme.primary : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  sort.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? colorScheme.primary : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
              // Optional expanding Search bar
              bottom: _isSearchExpanded && !isMultiSelect
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(56),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: provider.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Search photos by name...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),

            // Main Content Area
            if (provider.isLoading && photos.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (photos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  icon: provider.searchQuery.isNotEmpty
                      ? Icons.search_off_rounded
                      : Icons.camera_alt_outlined,
                  title: provider.searchQuery.isNotEmpty
                      ? 'No matching photos'
                      : 'No photos yet',
                  subtitle: provider.searchQuery.isNotEmpty
                      ? 'No photos matched "${provider.searchQuery}". Try a different keyword.'
                      : 'Click a photo with your camera to view it in your gallery.',
                  primaryButtonText: provider.searchQuery.isNotEmpty ? null : 'Click Photo',
                  primaryButtonIcon: Icons.camera_alt_rounded,
                  onPrimaryAction: provider.searchQuery.isNotEmpty
                      ? null
                      : () => _clickPhoto(context, provider),
                ),
              )
            else ...[
              // Date Group Sections with Sticky/Section Headers
              for (final entry in grouped.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          entry.key,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.value.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (provider.isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppConstants.gridSpacing,
                      crossAxisSpacing: AppConstants.gridSpacing,
                      itemBuilder: (context, index) {
                        final photo = entry.value[index];
                        final globalIndex = photos.indexOf(photo);
                        final isSelected = provider.selectedIds.contains(photo.id);

                        return PhotoTile(
                          photo: photo,
                          index: globalIndex,
                          isGridView: true,
                          isSelected: isSelected,
                          isMultiSelectMode: isMultiSelect,
                          onTap: () {
                            if (isMultiSelect) {
                              provider.toggleSelect(photo.id);
                            } else {
                              _openViewer(context, photos, globalIndex);
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
                      childCount: entry.value.length,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final photo = entry.value[index];
                          final globalIndex = photos.indexOf(photo);
                          final isSelected = provider.selectedIds.contains(photo.id);

                          return PhotoTile(
                            photo: photo,
                            index: globalIndex,
                            isGridView: false,
                            isSelected: isSelected,
                            isMultiSelectMode: isMultiSelect,
                            onTap: () {
                              if (isMultiSelect) {
                                provider.toggleSelect(photo.id);
                              } else {
                                _openViewer(context, photos, globalIndex);
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
                        childCount: entry.value.length,
                      ),
                    ),
                  ),
              ],

              // Lazy Loading indicator at the bottom when fetching next page
              if (provider.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                ),

              // Bottom padding for Extended FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ],
        ),
      ),
      // Extended Floating Action Button: Directly clicks photo via camera
      floatingActionButton: isMultiSelect
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _clickPhoto(context, provider),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Click Photo'),
            ),
    );
  }
}
