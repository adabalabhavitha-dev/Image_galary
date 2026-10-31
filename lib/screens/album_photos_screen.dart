import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../models/photo_item.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import '../widgets/photo_tile.dart';
import 'full_screen_viewer.dart';

/// Screen displaying photos inside a specific device album
/// (e.g. Camera, Screenshots, WhatsApp Images, Downloads).
///
/// Features date section headers above grids, lazy loading pagination,
/// grid/list view toggles, search filter, and full-screen viewer integration.
class AlbumPhotosScreen extends StatefulWidget {
  final AssetPathEntity album;
  final String? albumName;
  final int? initialCount;

  const AlbumPhotosScreen({
    super.key,
    required this.album,
    this.albumName,
    this.initialCount,
  });

  @override
  State<AlbumPhotosScreen> createState() => _AlbumPhotosScreenState();
}

class _AlbumPhotosScreenState extends State<AlbumPhotosScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PhotoItem> _photos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 60;

  bool _isSearchExpanded = false;
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateDesc;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _totalCount = widget.initialCount ?? 0;
    _scrollController.addListener(_onScroll);
    _loadInitialAlbumData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 400 && !_isLoadingMore && _hasMore) {
        _loadNextAlbumPage();
      }
    }
  }

  Future<void> _loadInitialAlbumData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final total = await widget.album.assetCountAsync;
      final assets = await widget.album.getAssetListPaged(
        page: 0,
        size: _pageSize,
      );

      if (!mounted) return;

      final provider = Provider.of<GalleryProvider>(context, listen: false);
      final items = assets.map((asset) => PhotoItem(
        asset: asset,
        isFavorite: provider.favoriteIds.contains(asset.id),
      )).toList();

      setState(() {
        _photos = items;
        _totalCount = total;
        _isLoading = false;
        if (assets.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading album photos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNextAlbumPage() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final assets = await widget.album.getAssetListPaged(
        page: nextPage,
        size: _pageSize,
      );

      if (!mounted) return;

      final provider = Provider.of<GalleryProvider>(context, listen: false);
      final newItems = assets.map((asset) => PhotoItem(
        asset: asset,
        isFavorite: provider.favoriteIds.contains(asset.id),
      )).toList();

      setState(() {
        _photos.addAll(newItems);
        _currentPage = nextPage;
        _isLoadingMore = false;
        if (assets.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading next album page: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  List<PhotoItem> _getFilteredAndSortedPhotos() {
    var result = List<PhotoItem>.from(_photos);

    if (_searchQuery.isNotEmpty) {
      result = result.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
    }

    switch (_currentSort) {
      case SortOption.dateDesc:
        result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
      case SortOption.dateAsc:
        result.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        break;
      case SortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.sizeDesc:
        result.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
        break;
    }

    return result;
  }

  int _getColumnCount(double screenWidth) {
    if (screenWidth >= 900) return 4;
    if (screenWidth >= 600) return 3;
    return 2;
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<GalleryProvider>(context);
    final isMultiSelect = provider.isMultiSelectMode;
    final displayPhotos = _getFilteredAndSortedPhotos();
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumnCount(screenWidth);
    final displayName = widget.albumName ?? widget.album.name;

    // Group photos by dateHeader
    final Map<String, List<PhotoItem>> grouped = {};
    for (final photo in displayPhotos) {
      final header = photo.dateHeader;
      grouped.putIfAbsent(header, () => []).add(photo);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadInitialAlbumData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // SliverAppBar
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: isMultiSelect ? 80.0 : (_isSearchExpanded ? 130.0 : 90.0),
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: isMultiSelect
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Exit selection',
                      onPressed: provider.clearSelection,
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
              title: isMultiSelect
                  ? Text(
                      '${provider.selectedCount} Selected',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$_totalCount photos',
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
                        onPressed: () {
                          for (final p in displayPhotos) {
                            if (!provider.selectedIds.contains(p.id)) {
                              provider.toggleSelect(p.id);
                            }
                          }
                        },
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
                    ]
                  : [
                      IconButton(
                        icon: Icon(_isSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded),
                        tooltip: _isSearchExpanded ? 'Close Search' : 'Search Photos',
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = !_isSearchExpanded;
                            if (!_isSearchExpanded) {
                              _searchController.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                        tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                        onPressed: () {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        },
                      ),
                      PopupMenuButton<SortOption>(
                        icon: const Icon(Icons.sort_rounded),
                        tooltip: 'Sort photos',
                        onSelected: (sort) {
                          setState(() {
                            _currentSort = sort;
                          });
                        },
                        itemBuilder: (context) => SortOption.values.map((sort) {
                          final isSelected = _currentSort == sort;
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
              bottom: _isSearchExpanded && !isMultiSelect
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(56),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search photos in $displayName...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
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

            // Loading state
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (displayPhotos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.photo_outlined,
                  title: _searchQuery.isNotEmpty ? 'No matching photos' : 'Album is empty',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'No photos matched "$_searchQuery".'
                      : 'This album does not contain any photos.',
                ),
              )
            else ...[
              // Date group sections with sticky/section headers
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
                if (_isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppConstants.gridSpacing,
                      crossAxisSpacing: AppConstants.gridSpacing,
                      itemBuilder: (context, idx) {
                        final photo = entry.value[idx];
                        final globalIndex = displayPhotos.indexOf(photo);
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
                              _openViewer(context, displayPhotos, globalIndex);
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
                        (context, idx) {
                          final photo = entry.value[idx];
                          final globalIndex = displayPhotos.indexOf(photo);
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
                                _openViewer(context, displayPhotos, globalIndex);
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

              // Loading more spinner at bottom
              if (_isLoadingMore)
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

              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
