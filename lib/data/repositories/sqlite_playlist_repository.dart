import 'package:sqflite/sqflite.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../database/database_provider.dart';
import '../models/playlist_model.dart';

class SqlitePlaylistRepository implements PlaylistRepository {
  SqlitePlaylistRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<Playlist>> getPlaylists() async {
    final db = await _databaseProvider.database;
    final playlistRows = await db.query(
      'playlists',
      orderBy: 'playlistName COLLATE NOCASE',
    );
    final playlists = <Playlist>[];
    for (final row in playlistRows) {
      final id = row['id'] as int;
      playlists.add(
        PlaylistModel.fromMap(row, songIds: await _loadSongIds(db, id)),
      );
    }
    return playlists;
  }

  @override
  Future<int> savePlaylist(Playlist playlist) async {
    final db = await _databaseProvider.database;
    final row = PlaylistModel.toMap(playlist)..remove('id');
    if (playlist.id == null) {
      return db.insert('playlists', row);
    }
    await db.update(
      'playlists',
      row,
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
    return playlist.id!;
  }

  @override
  Future<void> deletePlaylist(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> addSong(int playlistId, int songId) async {
    final db = await _databaseProvider.database;
    final maxPosition = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT MAX(position) FROM playlist_songs WHERE playlistId = ?',
            [playlistId],
          ),
        ) ??
        -1;
    await db.insert(
        'playlist_songs',
        {
          'playlistId': playlistId,
          'songId': songId,
          'position': maxPosition + 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> removeSong(int playlistId, int songId) async {
    final db = await _databaseProvider.database;
    await db.delete(
      'playlist_songs',
      where: 'playlistId = ? AND songId = ?',
      whereArgs: [playlistId, songId],
    );
    await reorderSongs(playlistId, await _loadSongIds(db, playlistId));
  }

  @override
  Future<void> reorderSongs(int playlistId, List<int> orderedSongIds) async {
    final db = await _databaseProvider.database;
    await db.transaction((txn) async {
      for (var index = 0; index < orderedSongIds.length; index++) {
        await txn.update(
          'playlist_songs',
          {'position': index},
          where: 'playlistId = ? AND songId = ?',
          whereArgs: [playlistId, orderedSongIds[index]],
        );
      }
    });
  }

  Future<List<int>> _loadSongIds(DatabaseExecutor db, int playlistId) async {
    final rows = await db.query(
      'playlist_songs',
      columns: ['songId'],
      where: 'playlistId = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    return rows.map((row) => row['songId'] as int).toList();
  }
}
