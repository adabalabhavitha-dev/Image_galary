import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// Represents a device photo album / folder wrapping an [AssetPathEntity].
class AlbumItem {
  /// The underlying platform album / collection entity.
  final AssetPathEntity pathEntity;

  /// User-friendly name of the album (e.g. "Recent", "Camera", "Screenshots").
  final String name;

  /// Total count of media assets contained in this album.
  final int count;

  /// The first / latest asset used as a thumbnail cover for the album.
  final AssetEntity? coverAsset;

  const AlbumItem({
    required this.pathEntity,
    required this.name,
    required this.count,
    this.coverAsset,
  });

  /// The unique identifier of the album entity.
  String get id => pathEntity.id;

  /// Whether this album represents the root "All / Recent" photo collection.
  bool get isAll => pathEntity.isAll;

  /// Thumbnail ImageProvider for the album's cover image.
  ImageProvider? get coverThumbnailProvider {
    if (coverAsset == null) return null;
    return AssetEntityImageProvider(
      coverAsset!,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize(300, 300),
    );
  }

  /// Creates a copy of this AlbumItem with updated values.
  AlbumItem copyWith({
    AssetPathEntity? pathEntity,
    String? name,
    int? count,
    AssetEntity? coverAsset,
  }) {
    return AlbumItem(
      pathEntity: pathEntity ?? this.pathEntity,
      name: name ?? this.name,
      count: count ?? this.count,
      coverAsset: coverAsset ?? this.coverAsset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlbumItem &&
          runtimeType == other.runtimeType &&
          pathEntity.id == other.pathEntity.id &&
          count == other.count;

  @override
  int get hashCode => pathEntity.id.hashCode ^ count.hashCode;
}
