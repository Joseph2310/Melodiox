import '../../core/constants/media_types.dart';
import '../../domain/entities/media_item.dart';

class MediaItemModel {
  const MediaItemModel._();

  static MediaItem fromMap(Map<String, Object?> map) {
    return MediaItem(
      id: map['id'] as int?,
      songId: map['songId'] as int?,
      mediaType: MediaTypeX.fromStorageValue(map['mediaType'] as String),
      localPath: map['localPath'] as String?,
      externalUrl: map['externalUrl'] as String?,
      title: map['title'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  static Map<String, Object?> toMap(MediaItem media, int songId) {
    return {
      'id': media.id,
      'songId': songId,
      'mediaType': media.mediaType.storageValue,
      'localPath': _blankToNull(media.localPath),
      'externalUrl': _blankToNull(media.externalUrl),
      'title': media.title.trim(),
      'sortOrder': media.sortOrder,
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
