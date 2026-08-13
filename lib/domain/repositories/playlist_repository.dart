import '../entities/playlist.dart';

abstract class PlaylistRepository {
  Future<List<Playlist>> getPlaylists();
  Future<int> savePlaylist(Playlist playlist);
  Future<void> deletePlaylist(int id);
  Future<void> addSong(int playlistId, int songId);
  Future<void> removeSong(int playlistId, int songId);
  Future<void> reorderSongs(int playlistId, List<int> orderedSongIds);
}
