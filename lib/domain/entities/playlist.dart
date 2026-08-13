class Playlist {
  const Playlist({
    this.id,
    required this.playlistName,
    this.songIds = const [],
  });

  final int? id;
  final String playlistName;
  final List<int> songIds;

  Playlist copyWith({int? id, String? playlistName, List<int>? songIds}) {
    return Playlist(
      id: id ?? this.id,
      playlistName: playlistName ?? this.playlistName,
      songIds: songIds ?? this.songIds,
    );
  }
}
