import '../entities/song.dart';

abstract class SongRepository {
  Future<List<Song>> getSongs();
  Future<Song?> getSong(int id);
  Future<int> saveSong(Song song);
  Future<void> deleteSong(int id);
  Future<void> toggleFavorite(int id, bool favorite);
  Future<void> setCompleted(int id, bool completed);
  Future<void> reorderSongs(List<int> songIds);
}
