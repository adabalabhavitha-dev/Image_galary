import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/album_item.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import 'album_photos_screen.dart';
import 'permission_screen.dart';

/// Screen displaying all detected device albums (Camera, Screenshots,
/// WhatsApp Images, Download, etc.) in a responsive grid.
///
/// Features album cover thumbnail previews, live photo counts, search filtering,
/// and smooth transitions to [AlbumPhotosScreen].
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getColumnCount(double screenWidth) {
    if (screenWidth >= 900) return 4;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<GalleryProvider>(context);

    // If permission has not been granted yet, show friendly permission screen
    if (!provider.hasPermission) {
      return const PermissionScreen();
    }

    final albums = provider.albums;
    final filteredAlbums = _searchQuery.isEmpty
        ? albums
        : albums.where((a) => a.name.toLowerCase().contains(_searchQuery)).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumnCount(screenWidth);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadAlbums();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // SliverAppBar
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: _isSearchExpanded ? 130.0 : 100.0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Albums',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${albums.length} device albums',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(_isSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded),
                  tooltip: _isSearchExpanded ? 'Close Search' : 'Search Albums',
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
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Albums',
                  onPressed: () => provider.loadAlbums(),
                ),
                const SizedBox(width: 4),
              ],
              bottom: _isSearchExpanded
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
                            hintText: 'Search albums by name...',
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

            // Content
            if (provider.isLoadingAlbums)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredAlbums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.folder_open_rounded,
                  title: _searchQuery.isNotEmpty ? 'No matching albums' : 'No albums found',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'No device albums matched "$_searchQuery".'
                      : 'No media albums were detected on this device.',
                  primaryButtonText: 'Refresh Albums',
                  primaryButtonIcon: Icons.refresh_rounded,
                  onPrimaryAction: () => provider.loadAlbums(),
                ),
              )
            else
              SliverPadding(
                padding: AppConstants.screenPadding,
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppConstants.gridSpacing + 4,
                    crossAxisSpacing: AppConstants.gridSpacing + 4,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = filteredAlbums[index];
                      return _AlbumGridCard(
                        album: album,
                        index: index,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumPhotosScreen(
                                album: album.pathEntity,
                                albumName: album.name,
                                initialCount: album.count,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: filteredAlbums.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card representing a single device album with cover thumbnail and photo count
class _AlbumGridCard extends StatelessWidget {
  final AlbumItem album;
  final int index;
  final VoidCallback onTap;

  const _AlbumGridCard({
    required this.album,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final animDelay = (index % 12 * 40).ms;
    final coverProvider = album.coverThumbnailProvider;

    return Card(
      elevation: 3,
      shadowColor: isDark ? Colors.black54 : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Cover Image Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverProvider != null)
                    Image(
                      image: coverProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.folder_rounded,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.folder_rounded,
                          size: 44,
                          color: colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                  // Bottom gradient overlay
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Folder icon pill top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.folder_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Album Metadata Info Area
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${album.count} photos',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
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
}
