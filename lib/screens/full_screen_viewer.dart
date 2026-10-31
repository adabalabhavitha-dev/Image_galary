import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import '../models/photo_item.dart';
import '../providers/gallery_provider.dart';
import '../utils/constants.dart';
import '../widgets/photo_details_sheet.dart';

/// Full-screen photo viewer featuring Hero transition, pinch-to-zoom,
/// double-tap zoom (2-stage cycle: zoom in / zoom out), pan before edge transition,
/// swipe down to dismiss (when not zoomed), instant adjacent precaching,
/// slideshow auto-play, real MediaStore deletion, and glassmorphic control overlays.
class FullScreenViewer extends StatefulWidget {
  final List<PhotoItem> initialPhotos;
  final int initialIndex;

  const FullScreenViewer({
    super.key,
    required this.initialPhotos,
    required this.initialIndex,
  });

  @override
  State<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _isSlideshowRunning = false;
  Timer? _slideshowTimer;

  // Zoom and scale-state controllers keyed by photo page index
  final Map<int, PhotoViewController> _controllers = {};
  final Map<int, PhotoViewScaleStateController> _scaleStateControllers = {};

  // Drag down to dismiss gesture state
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Enable edge-to-edge initially with dark status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<GalleryProvider>(context, listen: false);
    final photos = provider.filteredPhotos.isNotEmpty
        ? provider.filteredPhotos
        : provider.photos;
    _preloadAdjacentImages(_currentIndex, photos);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final sc in _scaleStateControllers.values) {
      sc.dispose();
    }
    _controllers.clear();
    _scaleStateControllers.clear();
    _pageController.dispose();

    // Restore standard UI mode when exiting viewer
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Retrieves or creates a PhotoViewController for a specific page index
  PhotoViewController _getController(int index) {
    return _controllers.putIfAbsent(index, () => PhotoViewController());
  }

  /// Retrieves or creates a PhotoViewScaleStateController for a specific page index
  PhotoViewScaleStateController _getScaleStateController(int index) {
    return _scaleStateControllers.putIfAbsent(index, () => PhotoViewScaleStateController());
  }

  /// Resets all zoom scales to 1.0 (fit to screen) so every adjacent photo opens zoomed out
  void _resetAllZoomScales() {
    for (final controller in _controllers.values) {
      try {
        controller.reset();
        controller.scale = 1.0;
      } catch (_) {}
    }
    for (final scaleController in _scaleStateControllers.values) {
      try {
        scaleController.reset();
      } catch (_) {}
    }
  }

  /// Checks if the currently displayed photo is zoomed in
  bool get _isCurrentPhotoZoomed {
    final controller = _controllers[_currentIndex];
    if (controller != null && controller.scale != null && controller.scale! > 1.01) {
      return true;
    }
    final scaleController = _scaleStateControllers[_currentIndex];
    if (scaleController != null && scaleController.scaleState != PhotoViewScaleState.initial) {
      return true;
    }
    return false;
  }

  /// Preloads adjacent previous and next images with precacheImage so swiping feels instant
  void _preloadAdjacentImages(int index, List<PhotoItem> photos) {
    if (!mounted || photos.isEmpty) return;

    final targets = [index, index - 1, index + 1];
    for (final targetIndex in targets) {
      if (targetIndex >= 0 && targetIndex < photos.length) {
        try {
          precacheImage(photos[targetIndex].fullImageProvider, context).catchError((_) {});
        } catch (_) {}
      }
    }
  }

  /// Toggle UI bars and immersive mode
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Start or pause slideshow
  void _toggleSlideshow(int totalPhotos) {
    if (totalPhotos <= 1) return;

    setState(() {
      _isSlideshowRunning = !_isSlideshowRunning;
    });

    if (_isSlideshowRunning) {
      _slideshowTimer?.cancel();
      _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;
        final nextIndex = (_currentIndex + 1) % totalPhotos;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slideshow started'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _slideshowTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slideshow paused'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Zoom In programmatically
  void _zoomIn() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.scale ?? 1.0;
    controller.scale = (currentScale * 1.4).clamp(1.0, 5.0);
  }

  /// Zoom Out programmatically
  void _zoomOut() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.scale ?? 1.0;
    controller.scale = (currentScale / 1.4).clamp(1.0, 5.0);
  }

  /// Show delete confirmation dialog and perform real MediaStore deletion
  Future<void> _confirmDelete(PhotoItem photo, GalleryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Photo?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${photo.name}"? This action will permanently remove it from your device.',
        ),
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
      final deletedName = photo.name;
      final currentList = provider.filteredPhotos.isNotEmpty
          ? provider.filteredPhotos
          : provider.photos;
      final int totalBefore = currentList.length;
      final int currentIndexBefore = _currentIndex;

      // Real deletion from device MediaStore using PhotoManager.editor.deleteWithIds
      final success = await provider.deletePhoto(photo.id);

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo could not be deleted from device.')),
        );
        return;
      }

      // If no photos remain, pop back to gallery immediately
      if (totalBefore <= 1) {
        Navigator.of(context).pop();
        return;
      }

      // Cleanly dispose and reset controllers
      for (final c in _controllers.values) {
        c.dispose();
      }
      for (final sc in _scaleStateControllers.values) {
        sc.dispose();
      }
      _controllers.clear();
      _scaleStateControllers.clear();

      // Automatically advance to the next photo
      setState(() {
        if (currentIndexBefore >= totalBefore - 1) {
          _currentIndex = totalBefore - 2;
        }
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }

      final remaining = provider.filteredPhotos.isNotEmpty
          ? provider.filteredPhotos
          : provider.photos;
      _preloadAdjacentImages(_currentIndex, remaining);

      // Show confirmation SnackBar
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "$deletedName"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryProvider>(
      builder: (context, provider, child) {
        // Filter list based on current active list from home screen
        final photos = provider.filteredPhotos.isNotEmpty
            ? provider.filteredPhotos
            : provider.photos;

        if (photos.isEmpty) {
          // If all photos deleted, automatically pop
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(backgroundColor: Colors.black);
        }

        // Clamp currentIndex
        if (_currentIndex >= photos.length) {
          _currentIndex = photos.length - 1;
        }

        final currentPhoto = photos[_currentIndex];

        // Background opacity during vertical drag dismiss gesture
        final double dragProgress = (_dragOffsetY.abs() / 250).clamp(0.0, 1.0);
        final Color backgroundColor = Colors.black.withValues(alpha: 1.0 - (dragProgress * 0.6));

        return Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Main Interactive Gallery with Swipe-Down Dismiss Gesture
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  // Only allow swipe down to dismiss when NOT zoomed in; when zoomed in, dragging pans the image!
                  if (_isCurrentPhotoZoomed) return;
                  if (details.delta.dy > 0 || _dragOffsetY > 0) {
                    setState(() {
                      _dragOffsetY += details.delta.dy;
                    });
                  }
                },
                onVerticalDragEnd: (details) {
                  if (_isCurrentPhotoZoomed) {
                    if (_dragOffsetY != 0.0) setState(() => _dragOffsetY = 0.0);
                    return;
                  }
                  // If dragged down past threshold or flung quickly, dismiss
                  if (_dragOffsetY > 120 || (details.primaryVelocity != null && details.primaryVelocity! > 600)) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _dragOffsetY = 0.0;
                    });
                  }
                },
                child: Transform.translate(
                  offset: Offset(0, _dragOffsetY),
                  child: Transform.scale(
                    scale: 1.0 - (dragProgress * 0.15),
                    child: PhotoViewGallery.builder(
                      scrollPhysics: const BouncingScrollPhysics(),
                      builder: (BuildContext context, int index) {
                        final item = photos[index];
                        final controller = _getController(index);
                        final scaleStateController = _getScaleStateController(index);

                        return PhotoViewGalleryPageOptions(
                          imageProvider: item.fullImageProvider,
                          initialScale: PhotoViewComputedScale.contained,
                          minScale: PhotoViewComputedScale.contained * 0.8,
                          maxScale: PhotoViewComputedScale.covered * 3.5,
                          heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${item.id}'),
                          controller: controller,
                          scaleStateController: scaleStateController,
                          // 2-step cycle: Double-tap zooms in, and double-tap again zooms out
                          scaleStateCycle: (actual) {
                            if (actual == PhotoViewScaleState.initial) {
                              return PhotoViewScaleState.covering;
                            }
                            return PhotoViewScaleState.initial;
                          },
                          onTapUp: (c, _, d) => _toggleControls(),
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 56),
                          ),
                        );
                      },
                      itemCount: photos.length,
                      loadingBuilder: (context, event) => Center(
                        child: SizedBox(
                          width: 32.0,
                          height: 32.0,
                          child: CircularProgressIndicator(
                            value: event == null
                                ? 0
                                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                      pageController: _pageController,
                      // Reset zoom scale to 1.0 (fit to screen) on every swipe so new photos always open zoomed out
                      onPageChanged: (index) {
                        _resetAllZoomScales();
                        setState(() {
                          _currentIndex = index;
                        });
                        _preloadAdjacentImages(index, photos);
                      },
                    ),
                  ),
                ),
              ),

              // Glassmorphic Top Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: _buildGlassmorphicTopBar(context, photos.length),
              ),

              // Glassmorphic Bottom Action Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: _showControls ? 0 : -110,
                left: 0,
                right: 0,
                child: _buildGlassmorphicBottomBar(context, currentPhoto, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Top Glassmorphic App Bar
  Widget _buildGlassmorphicTopBar(BuildContext context, int totalCount) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 8, 8),
          child: Row(
            children: [
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(width: 8),

              // Counter (e.g. "3 / 25")
              Text(
                '${_currentIndex + 1} / $totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(),

              // Slideshow Auto-Play Button
              IconButton(
                icon: Icon(
                  _isSlideshowRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                  color: _isSlideshowRunning ? AppConstants.secondarySeedColor : Colors.white,
                  size: 24,
                ),
                tooltip: _isSlideshowRunning ? 'Pause Slideshow' : 'Start Slideshow',
                onPressed: () => _toggleSlideshow(totalCount),
              ),

              // Info / Details Button
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                tooltip: 'Photo Details',
                onPressed: () {
                  final provider = Provider.of<GalleryProvider>(context, listen: false);
                  final photos = provider.filteredPhotos.isNotEmpty
                      ? provider.filteredPhotos
                      : provider.photos;
                  if (photos.isNotEmpty && _currentIndex < photos.length) {
                    PhotoDetailsSheet.show(
                      context,
                      photo: photos[_currentIndex],
                      onShare: () => provider.sharePhoto(photos[_currentIndex]),
                      onDelete: () => _confirmDelete(photos[_currentIndex], provider),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom Glassmorphic Action Bar
  Widget _buildGlassmorphicBottomBar(
    BuildContext context,
    PhotoItem currentPhoto,
    GalleryProvider provider,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Zoom Out Button
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 24),
                tooltip: 'Zoom Out',
                onPressed: _zoomOut,
              ),

              // Zoom In Button
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                tooltip: 'Zoom In',
                onPressed: _zoomIn,
              ),

              // Favorite Heart Button
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    currentPhoto.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    key: ValueKey(currentPhoto.isFavorite),
                    color: currentPhoto.isFavorite ? AppConstants.favoriteColor : Colors.white,
                    size: 26,
                  ),
                ),
                tooltip: currentPhoto.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () => provider.toggleFavorite(currentPhoto.id),
              ),

              // Share Button
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                tooltip: 'Share Photo',
                onPressed: () => provider.sharePhoto(currentPhoto),
              ),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                tooltip: 'Delete Photo',
                onPressed: () => _confirmDelete(currentPhoto, provider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
