import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// Represents a single photo inside the gallery app wrapping an [AssetEntity] from photo_manager.
class PhotoItem {
  /// The underlying platform media asset.
  final AssetEntity asset;

  /// Whether this photo is marked as a user favorite.
  final bool isFavorite;

  PhotoItem({
    required this.asset,
    this.isFavorite = false,
  });

  /// Factory constructor to create a PhotoItem wrapping an [AssetEntity].
  factory PhotoItem.fromAsset(
    AssetEntity asset, {
    bool isFavorite = false,
  }) {
    return PhotoItem(
      asset: asset,
      isFavorite: isFavorite,
    );
  }

  /// The unique identifier of the media asset in Android MediaStore / iOS PhotoKit.
  String get id => asset.id;

  /// The display title / filename of the asset.
  String? get title => asset.title;

  /// User-facing display name for the photo.
  String get name {
    if (asset.title != null && asset.title!.isNotEmpty) {
      return asset.title!;
    }
    return 'IMG_${asset.id}';
  }

  /// Creation date and time of the photo asset.
  DateTime get createDateTime => asset.createDateTime;

  /// Date added getter for backwards compatibility.
  DateTime get dateAdded => asset.createDateTime;

  /// Image pixel width.
  int get width => asset.width;

  /// Image pixel height.
  int get height => asset.height;

  /// Formatted date string (e.g. "Oct 19, 2026").
  String get formattedDate => DateFormat.yMMMd().format(createDateTime);

  /// Formatted time string (e.g. "7:30 PM").
  String get formattedTime => DateFormat.jm().format(createDateTime);

  /// Date header string for grouping (e.g. "Today", "Yesterday", or "12 Oct 2026").
  String get dateHeader {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(createDateTime.year, createDateTime.month, createDateTime.day);

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMM yyyy').format(createDateTime);
    }
  }

  /// Resolution string (e.g. "1920 × 1080").
  String get resolutionString {
    if (width > 0 && height > 0) {
      return '$width × $height';
    }
    return 'Resolution unknown';
  }

  /// Calculates aspect ratio (width / height) clamped for masonry grid aesthetics.
  double get aspectRatio {
    if (width > 0 && height > 0) {
      final ratio = width / height;
      return ratio.clamp(0.5, 2.0);
    }
    return 1.0;
  }

  /// Thumbnail ImageProvider (300x300) for fast gallery grid/list display.
  ImageProvider get thumbnailProvider => AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(300, 300),
      );

  /// Full-resolution ImageProvider for fullscreen zooming view.
  ImageProvider get fullImageProvider => AssetEntityImageProvider(
        asset,
        isOriginal: true,
      );

  /// General ImageProvider default (full-resolution).
  ImageProvider get imageProvider => fullImageProvider;

  /// Asynchronously loads the [File] object for this asset.
  Future<File?> get file => asset.file;

  /// Asynchronously loads the original [File] object preserving all EXIF metadata.
  Future<File?> get originFile => asset.originFile;

  /// Asynchronous helper to retrieve the absolute file path on disk.
  Future<String?> get filePath async {
    final f = await asset.file;
    return f?.path;
  }

  /// Asynchronous helper to retrieve the file size in bytes.
  Future<int> get fileSize async {
    try {
      return await asset.fileSize;
    } catch (_) {
      final f = await asset.file;
      return (await f?.length()) ?? 0;
    }
  }

  /// Asynchronously formats the file size (e.g. "2.4 MB" or "850 KB").
  Future<String> get formattedFileSize async {
    final size = await fileSize;
    if (size <= 0) return 'Unknown size';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Synchronous fallback path representation.
  String get path => asset.relativePath ?? asset.id;

  /// Indicates whether the photo is from a remote network (always false for local MediaStore).
  bool get isNetwork => false;

  /// Creates a copy of this PhotoItem with updated properties.
  PhotoItem copyWith({
    AssetEntity? asset,
    bool? isFavorite,
  }) {
    return PhotoItem(
      asset: asset ?? this.asset,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoItem &&
          runtimeType == other.runtimeType &&
          asset.id == other.asset.id &&
          isFavorite == other.isFavorite;

  @override
  int get hashCode => asset.id.hashCode ^ isFavorite.hashCode;
}
