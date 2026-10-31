import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/photo_item.dart';
import '../utils/constants.dart';

/// Main state management provider for the Image Gallery application.
///
/// Integrates with Android MediaStore via photo_manager to load device albums,
/// paginate photos, handle change callbacks for auto-refresh, group photos by date,
/// perform real deletion via PhotoManager.editor.deleteWithIds, and manage favorites.
class GalleryProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  PermissionState _permissionState = PermissionState.notDetermined;
  List<AlbumItem> _albums = [];
  AlbumItem? _currentAlbum;

  List<PhotoItem> _photos = [];
  final Set<String> _favoriteIds = {};
  final Set<String> _selectedIds = {};

  bool _isMultiSelectMode = false;
  bool _isGridView = true;
  SortOption _currentSort = SortOption.dateDesc;
  String _searchQuery = '';
  ThemeMode _themeMode = ThemeMode.system;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePhotos = true;
  int _currentPage = 0;
  static const int _pageSize = 60;

  bool _isChangeCallbackRegistered = false;

  // Getters
  PermissionState get permissionState => _permissionState;

  /// Exposes whether the app holds permission to read device media.
  bool get hasPermission =>
      _permissionState == PermissionState.authorized ||
      _permissionState == PermissionState.limited;

  List<AlbumItem> get albums => _albums;
  AlbumItem? get currentAlbum => _currentAlbum;

  List<PhotoItem> get photos => _photos;
  Set<String> get selectedIds => _selectedIds;
  Set<String> get favoriteIds => _favoriteIds;
  bool get isMultiSelectMode => _isMultiSelectMode;
  bool get isGridView => _isGridView;
  SortOption get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  bool get isLoadingAlbums => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePhotos => _hasMorePhotos;
  int get totalCount => _photos.length;
  int get favoriteCount => _photos.where((p) => p.isFavorite).length;
  int get selectedCount => _selectedIds.length;

  /// Returns photos marked as favorite
  List<PhotoItem> get favoritePhotos {
    return _filterAndSortPhotos(_photos.where((p) => p.isFavorite).toList());
  }

  /// Returns photos filtered by search query and sorted according to currentSort
  List<PhotoItem> get filteredPhotos {
    return _filterAndSortPhotos(_photos);
  }

  /// Returns the list of currently selected PhotoItems in multi-select mode
  List<PhotoItem> get selectedPhotos {
    return _photos.where((p) => _selectedIds.contains(p.id)).toList();
  }

  /// Groups currently filtered photos by date headers ('Today', 'Yesterday', or '12 Oct 2026').
  Map<String, List<PhotoItem>> get dateGroupedPhotos {
    final Map<String, List<PhotoItem>> groups = {};
    for (final photo in filteredPhotos) {
      final header = _formatDateHeader(photo.createDateTime);
      groups.putIfAbsent(header, () => []).add(photo);
    }
    return groups;
  }

  /// Formats date header according to requirement: 'Today', 'Yesterday', or '12 Oct 2026'
  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final photoDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (photoDate == today) {
      return 'Today';
    } else if (photoDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMM yyyy').format(dateTime);
    }
  }

  /// Initialize and load saved state from SharedPreferences and initialize MediaStore
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load ThemeMode preference
      final themeIndex = prefs.getInt(AppConstants.prefsThemeModeKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      }

      // Load Grid / List view preference
      _isGridView = prefs.getBool(AppConstants.prefsIsGridKey) ?? true;

      // Load favorites
      await _loadFavorites();

      // Register auto-refresh change callback
      _setupChangeNotify();

      // Request media permissions using photo_manager
      _permissionState = await PhotoManager.requestPermissionExtend();

      if (hasPermission) {
        await refreshGallery();
      }
    } catch (e) {
      debugPrint('Error loading gallery initialization: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request permissions using PhotoManager.requestPermissionExtend()
  Future<PermissionState> requestPermission() async {
    _permissionState = await PhotoManager.requestPermissionExtend();
    notifyListeners();
    if (hasPermission) {
      await refreshGallery();
    }
    return _permissionState;
  }

  /// Sets up change notification callback to automatically refresh when photos change
  void _setupChangeNotify() {
    if (_isChangeCallbackRegistered) return;
    _isChangeCallbackRegistered = true;

    PhotoManager.addChangeCallback(_onGalleryChanged);
    PhotoManager.startChangeNotify();
  }

  /// Callback executed when device photo library changes (e.g. new photo taken)
  void _onGalleryChanged(MethodCall call) {
    debugPrint('Device MediaStore change detected: ${call.method}');
    refreshGallery();
  }

  /// Reloads the latest albums and photos from device MediaStore
  Future<void> refreshGallery() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadAlbums();
      await _loadFirstPagePhotos();
    } catch (e) {
      debugPrint('Error refreshing gallery: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads device albums using PhotoManager.getAssetPathList(type: RequestType.image)
  Future<void> loadAlbums() async {
    try {
      final pathList = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      final List<AlbumItem> loadedAlbums = [];
      for (final path in pathList) {
        final count = await path.assetCountAsync;
        AssetEntity? cover;
        if (count > 0) {
          final firstAssets = await path.getAssetListPaged(page: 0, size: 1);
          if (firstAssets.isNotEmpty) {
            cover = firstAssets.first;
          }
        }
        loadedAlbums.add(
          AlbumItem(
            pathEntity: path,
            name: path.name,
            count: count,
            coverAsset: cover,
          ),
        );
      }

      _albums = loadedAlbums;
      if (_albums.isNotEmpty) {
        if (_currentAlbum == null || !_albums.any((a) => a.id == _currentAlbum!.id)) {
          _currentAlbum = _albums.first;
        } else {
          _currentAlbum = _albums.firstWhere((a) => a.id == _currentAlbum!.id);
        }
      } else {
        _currentAlbum = null;
      }
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
  }

  /// Select a specific album to display
  Future<void> selectAlbum(AlbumItem album) async {
    if (_currentAlbum?.id == album.id) return;
    _currentAlbum = album;
    _photos.clear();
    _currentPage = 0;
    _hasMorePhotos = true;
    notifyListeners();
    await _loadFirstPagePhotos();
  }

  /// Loads the first page of photos for the currently selected album (page 0, size 60)
  Future<void> _loadFirstPagePhotos() async {
    if (_currentAlbum == null) {
      _photos = [];
      _hasMorePhotos = false;
      notifyListeners();
      return;
    }

    _currentPage = 0;
    _hasMorePhotos = true;

    try {
      final assets = await _currentAlbum!.pathEntity.getAssetListPaged(
        page: 0,
        size: _pageSize,
      );

      _photos = assets
          .map((asset) => PhotoItem(
                asset: asset,
                isFavorite: _favoriteIds.contains(asset.id),
              ))
          .toList();

      _hasMorePhotos = assets.length == _pageSize;
      _currentPage = 1;
    } catch (e) {
      debugPrint('Error loading first page of photos: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Loads the next page of photos with pagination (album.getAssetListPaged(page: p, size: 60))
  Future<void> loadMorePhotos() async {
    if (_isLoadingMore || !_hasMorePhotos || _currentAlbum == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final assets = await _currentAlbum!.pathEntity.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      if (assets.isNotEmpty) {
        final newPhotos = assets
            .map((asset) => PhotoItem(
                  asset: asset,
                  isFavorite: _favoriteIds.contains(asset.id),
                ))
            .toList();

        _photos.addAll(newPhotos);
        _currentPage++;
        _hasMorePhotos = assets.length == _pageSize;
      } else {
        _hasMorePhotos = false;
      }
    } catch (e) {
      debugPrint('Error loading more photos: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Alias for loadMorePhotos
  Future<void> loadNextPage() => loadMorePhotos();

  /// Internal helper to load persisted favorite asset IDs
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(AppConstants.prefsFavoritesKey) ?? [];
      _favoriteIds.clear();
      _favoriteIds.addAll(list);
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  /// Internal helper to persist favorite asset IDs
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.prefsFavoritesKey, _favoriteIds.toList());
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  /// Toggle favorite status of a photo and persist
  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    await _saveFavorites();

    final index = _photos.indexWhere((p) => p.id == id);
    if (index != -1) {
      _photos[index] = _photos[index].copyWith(
        isFavorite: _favoriteIds.contains(id),
      );
    }
    notifyListeners();

    // Attempt system platform favorite synchronization if supported
    try {
      final photo = _photos.cast<PhotoItem?>().firstWhere((p) => p?.id == id, orElse: () => null);
      if (photo != null) {
        if (Platform.isAndroid) {
          await PhotoManager.editor.android.favoriteAsset(
            entity: photo.asset,
            favorite: _favoriteIds.contains(id),
          );
        } else if (Platform.isIOS || Platform.isMacOS) {
          await PhotoManager.editor.darwin.favoriteAsset(
            entity: photo.asset,
            favorite: _favoriteIds.contains(id),
          );
        }
      }
    } catch (_) {
      // Ignored if device platform does not allow direct favoriting without dialog
    }
  }

  /// Toggle favorite on all selected photos
  Future<void> toggleFavoriteSelected() async {
    if (_selectedIds.isEmpty) return;

    final anyNotFavorite = _photos.any((p) => _selectedIds.contains(p.id) && !p.isFavorite);

    for (final id in _selectedIds) {
      if (anyNotFavorite) {
        _favoriteIds.add(id);
      } else {
        _favoriteIds.remove(id);
      }
    }
    await _saveFavorites();

    for (var i = 0; i < _photos.length; i++) {
      if (_selectedIds.contains(_photos[i].id)) {
        _photos[i] = _photos[i].copyWith(isFavorite: anyNotFavorite);
      }
    }

    clearSelection();
    notifyListeners();
  }

  /// Real deletion of a photo using PhotoManager.editor.deleteWithIds
  Future<bool> deletePhoto(String id) async {
    try {
      final List<String> deletedIds = await PhotoManager.editor.deleteWithIds([id]);
      if (deletedIds.contains(id)) {
        _photos.removeWhere((p) => p.id == id);
        _selectedIds.remove(id);
        _favoriteIds.remove(id);
        await _saveFavorites();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting photo $id: $e');
      return false;
    }
  }

  /// Real deletion of all selected photos using PhotoManager.editor.deleteWithIds
  Future<int> deleteSelected() async {
    if (_selectedIds.isEmpty) return 0;
    try {
      final idsToDelete = _selectedIds.toList();
      final List<String> deletedIds = await PhotoManager.editor.deleteWithIds(idsToDelete);
      final deletedSet = deletedIds.toSet();

      _photos.removeWhere((p) => deletedSet.contains(p.id));
      _selectedIds.removeAll(deletedSet);
      _favoriteIds.removeAll(deletedSet);
      await _saveFavorites();

      if (_selectedIds.isEmpty) {
        _isMultiSelectMode = false;
      }
      notifyListeners();
      return deletedIds.length;
    } catch (e) {
      debugPrint('Error deleting selected photos: $e');
      return 0;
    }
  }

  /// Placeholder for undo deletion callback in UI (system deletions cannot be silently un-deleted)
  Future<void> undoDelete() async {
    notifyListeners();
  }

  /// Filters and sorts a photo list based on current active query & sort option
  List<PhotoItem> _filterAndSortPhotos(List<PhotoItem> source) {
    var result = List<PhotoItem>.from(source);

    // Apply search filter if query is present
    if (_searchQuery.isNotEmpty) {
      result = result.where((photo) {
        return photo.name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
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

  /// Capture a new photo using device camera and save to MediaStore
  Future<bool> capturePhotoFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (photo == null) return false;

      // Save into device MediaStore
      await PhotoManager.editor.saveImageWithPath(
        photo.path,
        title: p.basenameWithoutExtension(photo.name),
      );

      await refreshGallery();
      return true;
    } catch (e) {
      debugPrint('Error capturing photo from camera: $e');
      return false;
    }
  }

  /// Share a photo using share_plus
  Future<void> sharePhoto(PhotoItem photo) async {
    try {
      final file = await photo.file;
      if (file != null && await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: photo.name,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing photo: $e');
    }
  }

  /// Share all currently selected photos
  Future<void> shareSelected() async {
    final selected = selectedPhotos;
    if (selected.isEmpty) return;

    try {
      final files = <XFile>[];
      for (final photo in selected) {
        final file = await photo.file;
        if (file != null && await file.exists()) {
          files.add(XFile(file.path));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(files: files),
        );
      }
    } catch (e) {
      debugPrint('Error sharing selected photos: $e');
    }
  }

  /// Multi-select: toggle selection of a photo
  void toggleSelect(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) {
        _isMultiSelectMode = false;
      }
    } else {
      _selectedIds.add(id);
      _isMultiSelectMode = true;
    }
    notifyListeners();
  }

  /// Enter multi-select mode with an initial photo
  void enterMultiSelect(String initialId) {
    _isMultiSelectMode = true;
    _selectedIds.add(initialId);
    notifyListeners();
  }

  /// Select all currently filtered photos
  void selectAll() {
    _isMultiSelectMode = true;
    _selectedIds.clear();
    for (final photo in filteredPhotos) {
      _selectedIds.add(photo.id);
    }
    notifyListeners();
  }

  /// Clear all selections and exit multi-select mode
  void clearSelection() {
    _selectedIds.clear();
    _isMultiSelectMode = false;
    notifyListeners();
  }

  /// Toggle grid or list view
  Future<void> toggleViewMode() async {
    _isGridView = !_isGridView;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsIsGridKey, _isGridView);
  }

  /// Change sorting option
  void setSortOption(SortOption sort) {
    _currentSort = sort;
    notifyListeners();
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  /// Change theme mode and persist choice
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsThemeModeKey, mode.index);
  }

  /// Clear in-memory photos
  Future<void> clearAllPhotos() async {
    _photos.clear();
    clearSelection();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isChangeCallbackRegistered) {
      PhotoManager.removeChangeCallback(_onGalleryChanged);
      PhotoManager.stopChangeNotify();
      _isChangeCallbackRegistered = false;
    }
    super.dispose();
  }
}
