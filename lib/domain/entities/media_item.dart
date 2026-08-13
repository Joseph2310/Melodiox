import '../../core/constants/media_types.dart';

class MediaItem {
  const MediaItem({
    this.id,
    this.songId,
    required this.mediaType,
    this.localPath,
    this.externalUrl,
    required this.title,
    this.sortOrder = 0,
  });

  final int? id;
  final int? songId;
  final MediaType mediaType;
  final String? localPath;
  final String? externalUrl;
  final String title;
  final int sortOrder;

  bool get isExternal => externalUrl != null && externalUrl!.trim().isNotEmpty;

  bool get hasSource {
    final hasLocal = localPath != null && localPath!.trim().isNotEmpty;
    final hasUrl = externalUrl != null && externalUrl!.trim().isNotEmpty;
    return hasLocal || hasUrl;
  }

  MediaItem copyWith({
    int? id,
    int? songId,
    MediaType? mediaType,
    String? localPath,
    String? externalUrl,
    String? title,
    int? sortOrder,
    bool clearLocalPath = false,
    bool clearExternalUrl = false,
  }) {
    return MediaItem(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      mediaType: mediaType ?? this.mediaType,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      externalUrl: clearExternalUrl ? null : externalUrl ?? this.externalUrl,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
