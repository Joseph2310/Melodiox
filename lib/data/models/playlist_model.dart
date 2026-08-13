import '../../domain/entities/playlist.dart';

class PlaylistModel {
  const PlaylistModel._();

  static Playlist fromMap(
    Map<String, Object?> map, {
    List<int> songIds = const [],
  }) {
    return Playlist(
      id: map['id'] as int?,
      playlistName: map['playlistName'] as String,
      songIds: songIds,
    );
  }

  static Map<String, Object?> toMap(Playlist playlist) {
    return {'id': playlist.id, 'playlistName': playlist.playlistName.trim()};
  }
}
