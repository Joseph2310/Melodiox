import 'package:sqflite/sqflite.dart';

import '../../core/constants/media_types.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/rhythm.dart';
import '../../domain/entities/rhythm_item.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_chord_item.dart';
import '../../domain/entities/tag.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../domain/repositories/song_repository.dart';
import '../database/database_provider.dart';
import '../models/media_item_model.dart';
import '../models/chord_tutorial_model.dart';
import '../models/rhythm_model.dart';
import '../models/song_model.dart';
import '../models/tag_model.dart';

class SqliteSongRepository implements SongRepository {
  SqliteSongRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<Song>> getSongs() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'songs',
      orderBy: 'updatedAt DESC, name COLLATE NOCASE',
    );
    final songs = <Song>[];
    for (final row in rows) {
      songs.add(await _hydrateSong(db, row));
    }
    return songs;
  }

  @override
  Future<Song?> getSong(int id) async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _hydrateSong(db, rows.first);
  }

  @override
  Future<int> saveSong(Song song) async {
    final db = await _databaseProvider.database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final normalizedQuarterTones = song.quarterTones
          .map((tone) => tone.trim())
          .where((tone) => tone.isNotEmpty)
          .toList();
      final position =
          song.id == null ? await _nextSongPosition(txn) : song.position;
      final effectiveSong = song.copyWith(
        quarterTones: normalizedQuarterTones,
        position: position,
        createdAt: song.id == null ? now : song.createdAt,
        updatedAt: now,
      );
      final row = SongModel.toMap(effectiveSong)..remove('id');

      final songId =
          song.id == null ? await txn.insert('songs', row) : song.id!;

      if (song.id != null) {
        await txn.update('songs', row, where: 'id = ?', whereArgs: [song.id]);
      }

      await _replaceChildren(txn, songId, effectiveSong);
      return songId;
    });
  }

  @override
  Future<void> deleteSong(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> toggleFavorite(int id, bool favorite) async {
    final db = await _databaseProvider.database;
    await db.update(
      'songs',
      {
        'favorite': favorite ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setCompleted(int id, bool completed) async {
    final db = await _databaseProvider.database;
    await db.update(
      'songs',
      {
        'completed': completed ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> reorderSongs(List<int> songIds) async {
    final db = await _databaseProvider.database;
    await db.transaction((txn) async {
      for (var index = 0; index < songIds.length; index++) {
        await txn.update(
          'songs',
          {
            'position': index,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [songIds[index]],
        );
      }
    });
  }

  Future<Song> _hydrateSong(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final songId = row['id'] as int;
    final quarterTones = await _loadQuarterTones(db, songId);
    final rhythmItems = await _loadRhythmItems(db, songId);
    final chordTutorials = await _loadChordTutorials(db, songId);
    final chordItems = await _loadChordItems(db, songId);
    final noteItems = await _loadNoteItems(db, songId);
    final media = await _loadMedia(db, songId);
    final tags = await _loadTags(db, songId);

    return SongModel.fromMap(
      row,
      quarterTones: quarterTones,
      rhythmItems: rhythmItems,
      chordTutorials: chordTutorials,
      chordItems: chordItems,
      noteItems: noteItems,
      media: media,
      tags: tags,
    );
  }

  Future<List<String>> _loadQuarterTones(
    DatabaseExecutor db,
    int songId,
  ) async {
    final rows = await db.query(
      'quarter_tones',
      columns: ['value'],
      where: 'songId = ?',
      whereArgs: [songId],
      orderBy: 'id ASC',
    );
    return rows.map((row) => row['value'] as String).toList();
  }

  Future<List<RhythmItem>> _loadRhythmItems(
    DatabaseExecutor db,
    int songId,
  ) async {
    final itemRows = await db.query(
      'song_rhythm_items',
      where: 'songId = ?',
      whereArgs: [songId],
      orderBy: 'position ASC, id ASC',
    );
    final items = <RhythmItem>[];
    for (final itemRow in itemRows) {
      final itemId = itemRow['id'] as int;
      final rhythms = await _loadRhythmsForItem(db, itemId);
      items.add(
        RhythmItem(
          id: itemId,
          songId: songId,
          position: itemRow['position'] as int? ?? 0,
          rhythms: rhythms,
        ),
      );
    }
    return items;
  }

  Future<List<Rhythm>> _loadRhythmsForItem(
    DatabaseExecutor db,
    int itemId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT rhythms.id,
             rhythms.rhythmName,
             rhythms.section
      FROM song_rhythm_item_rhythms
      INNER JOIN rhythms ON rhythms.id = song_rhythm_item_rhythms.rhythmId
      WHERE song_rhythm_item_rhythms.itemId = ?
      ORDER BY song_rhythm_item_rhythms.position ASC,
               rhythms.rhythmName COLLATE NOCASE
      ''',
      [itemId],
    );
    return rows.map(RhythmModel.fromMap).toList();
  }

  Future<List<MediaItem>> _loadMedia(DatabaseExecutor db, int songId) async {
    final rows = await db.query(
      'media',
      where: 'songId = ?',
      whereArgs: [songId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map(MediaItemModel.fromMap).toList();
  }

  Future<List<ChordTutorial>> _loadChordTutorials(
    DatabaseExecutor db,
    int songId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT chord_tutorials.id,
             chord_tutorials.name,
             chord_tutorials.type,
             chord_tutorials.keys,
             chord_tutorials.imagePath,
             chord_tutorials.videoPath,
             chord_tutorials.relativeChordId,
             chord_tutorials.inversions,
             chord_tutorials.notes,
             chord_tutorials.links,
             chord_tutorials.customFields,
             chord_tutorials.createdAt,
             chord_tutorials.updatedAt
      FROM song_chord_tutorials
      INNER JOIN chord_tutorials
        ON chord_tutorials.id = song_chord_tutorials.chordTutorialId
      WHERE song_chord_tutorials.songId = ?
      ORDER BY song_chord_tutorials.position ASC,
               chord_tutorials.name COLLATE NOCASE,
               chord_tutorials.type COLLATE NOCASE
      ''',
      [songId],
    );
    return rows.map(ChordTutorialModel.fromMap).toList();
  }

  Future<List<TutorialNote>> _loadNoteItems(
    DatabaseExecutor db,
    int songId,
  ) async {
    final rows = await db.query(
      'song_note_items',
      where: 'songId = ?',
      whereArgs: [songId],
      orderBy: 'position ASC, id ASC',
    );
    return rows
        .map(
          (row) => TutorialNote(
            title: row['title'] as String? ?? '',
            body: row['body'] as String? ?? '',
          ),
        )
        .where((note) => !note.isEmpty)
        .toList();
  }

  Future<List<SongChordItem>> _loadChordItems(
    DatabaseExecutor db,
    int songId,
  ) async {
    final rows = await db.query(
      'song_chord_items',
      where: 'songId = ?',
      whereArgs: [songId],
      orderBy: 'position ASC, id ASC',
    );
    final items = <SongChordItem>[];
    for (final row in rows) {
      final itemId = row['id'] as int;
      final chords = await _loadChordItemChords(db, itemId);
      final images = await _loadChordItemImages(db, itemId);
      items.add(
        SongChordItem(
          id: itemId,
          songId: songId,
          position: row['position'] as int? ?? items.length,
          chords: chords,
          images: images,
        ),
      );
    }
    return items.where((item) => !item.isEmpty).toList();
  }

  Future<List<SongChordSelection>> _loadChordItemChords(
    DatabaseExecutor db,
    int itemId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT song_chord_item_chords.inversionIndex,
             chord_tutorials.id,
             chord_tutorials.name,
             chord_tutorials.type,
             chord_tutorials.keys,
             chord_tutorials.imagePath,
             chord_tutorials.videoPath,
             chord_tutorials.relativeChordId,
             chord_tutorials.inversions,
             chord_tutorials.notes,
             chord_tutorials.links,
             chord_tutorials.customFields,
             chord_tutorials.createdAt,
             chord_tutorials.updatedAt
      FROM song_chord_item_chords
      INNER JOIN chord_tutorials
        ON chord_tutorials.id = song_chord_item_chords.chordTutorialId
      WHERE song_chord_item_chords.itemId = ?
      ORDER BY song_chord_item_chords.position ASC,
               chord_tutorials.name COLLATE NOCASE,
               chord_tutorials.type COLLATE NOCASE
      ''',
      [itemId],
    );
    return [
      for (final row in rows)
        SongChordSelection(
          chord: ChordTutorialModel.fromMap(row),
          inversionIndex: row['inversionIndex'] as int?,
        ),
    ];
  }

  Future<List<MediaItem>> _loadChordItemImages(
    DatabaseExecutor db,
    int itemId,
  ) async {
    final rows = await db.query(
      'song_chord_item_images',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return [
      for (final row in rows)
        MediaItem(
          id: row['id'] as int?,
          mediaType: MediaType.chordImage,
          localPath: row['localPath'] as String?,
          externalUrl: row['externalUrl'] as String?,
          title: row['title'] as String? ?? 'Chord image',
          sortOrder: row['sortOrder'] as int? ?? 0,
        ),
    ];
  }

  Future<List<Tag>> _loadTags(DatabaseExecutor db, int songId) async {
    final rows = await db.rawQuery(
      '''
      SELECT tags.id, tags.name, tags.color
      FROM song_tags
      INNER JOIN tags ON tags.id = song_tags.tagId
      WHERE song_tags.songId = ?
      ORDER BY tags.name COLLATE NOCASE
      ''',
      [songId],
    );
    return rows.map(TagModel.fromMap).toList();
  }

  Future<void> _replaceChildren(Transaction txn, int songId, Song song) async {
    await txn.delete('quarter_tones', where: 'songId = ?', whereArgs: [songId]);
    await txn.delete('song_tags', where: 'songId = ?', whereArgs: [songId]);
    await txn.delete(
      'song_rhythm_items',
      where: 'songId = ?',
      whereArgs: [songId],
    );
    await txn.delete(
      'song_chord_tutorials',
      where: 'songId = ?',
      whereArgs: [songId],
    );
    await txn.delete(
      'song_chord_items',
      where: 'songId = ?',
      whereArgs: [songId],
    );
    await txn.delete(
      'song_note_items',
      where: 'songId = ?',
      whereArgs: [songId],
    );
    await txn.delete('media', where: 'songId = ?', whereArgs: [songId]);

    for (final value in song.quarterTones) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      await txn.insert('quarter_tones', {'songId': songId, 'value': trimmed});
    }

    for (final tag in song.tags) {
      final tagId = tag.id;
      if (tagId == null) {
        continue;
      }
      await txn.insert(
          'song_tags',
          {
            'songId': songId,
            'tagId': tagId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (var itemIndex = 0; itemIndex < song.rhythmItems.length; itemIndex++) {
      final item = song.rhythmItems[itemIndex];
      if (item.rhythms.isEmpty) {
        continue;
      }
      final itemId = await txn.insert('song_rhythm_items', {
        'songId': songId,
        'position': itemIndex,
      });
      for (var rhythmIndex = 0;
          rhythmIndex < item.rhythms.length;
          rhythmIndex++) {
        final rhythm = item.rhythms[rhythmIndex];
        if (rhythm.rhythmName.trim().isEmpty) {
          continue;
        }
        final rhythmId = await _ensureRhythm(txn, rhythm);
        await txn.insert(
            'song_rhythm_item_rhythms',
            {
              'itemId': itemId,
              'rhythmId': rhythmId,
              'position': rhythmIndex,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final itemSelections = song.chordItems
        .expand((item) => item.chords)
        .where((selection) => selection.chord.id != null)
        .toList();
    final chordSelections = itemSelections.isEmpty
        ? [
            for (final chord in song.chordTutorials)
              SongChordSelection(chord: chord),
          ]
        : itemSelections;
    final seenChordIds = <int>{};
    for (final selection in chordSelections) {
      final chordId = selection.chord.id;
      if (chordId == null) {
        continue;
      }
      if (!seenChordIds.add(chordId)) {
        continue;
      }
      await txn.insert(
        'song_chord_tutorials',
        {
          'songId': songId,
          'chordTutorialId': chordId,
          'position': seenChordIds.length - 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (var noteIndex = 0; noteIndex < song.noteItems.length; noteIndex++) {
      final note = song.noteItems[noteIndex];
      if (note.isEmpty) {
        continue;
      }
      await txn.insert('song_note_items', {
        'songId': songId,
        'title': note.title.trim(),
        'body': note.body.trim(),
        'position': noteIndex,
      });
    }

    final effectiveChordItems = song.chordItems.isNotEmpty
        ? song.chordItems
        : [
            if (song.chordTutorials.isNotEmpty ||
                song.media
                    .any((item) => item.mediaType == MediaType.chordImage))
              SongChordItem(
                chords: [
                  for (final chord in song.chordTutorials)
                    SongChordSelection(chord: chord),
                ],
                images: song.media
                    .where((item) => item.mediaType == MediaType.chordImage)
                    .toList(),
              ),
          ];
    for (var itemIndex = 0;
        itemIndex < effectiveChordItems.length;
        itemIndex++) {
      final item = effectiveChordItems[itemIndex];
      final chords = item.chords
          .where((selection) => selection.chord.id != null)
          .toList(growable: false);
      final images = item.images
          .where((media) => media.hasSource && media.title.trim().isNotEmpty)
          .toList(growable: false);
      if (chords.isEmpty && images.isEmpty) {
        continue;
      }
      final itemId = await txn.insert('song_chord_items', {
        'songId': songId,
        'position': itemIndex,
      });
      for (var chordIndex = 0; chordIndex < chords.length; chordIndex++) {
        final selection = chords[chordIndex];
        await txn.insert('song_chord_item_chords', {
          'itemId': itemId,
          'chordTutorialId': selection.chord.id,
          'inversionIndex': selection.inversionIndex,
          'position': chordIndex,
        });
      }
      for (var imageIndex = 0; imageIndex < images.length; imageIndex++) {
        final media = images[imageIndex];
        await txn.insert('song_chord_item_images', {
          'itemId': itemId,
          'localPath': media.localPath,
          'externalUrl': media.externalUrl,
          'title': media.title.trim(),
          'sortOrder': imageIndex,
        });
      }
    }

    for (final media in song.media) {
      if (!media.hasSource || media.title.trim().isEmpty) {
        continue;
      }
      await txn.insert(
        'media',
        MediaItemModel.toMap(media, songId)..remove('id'),
      );
    }
  }

  Future<int> _ensureRhythm(Transaction txn, Rhythm rhythm) async {
    if (rhythm.id != null) {
      return rhythm.id!;
    }
    final name = rhythm.rhythmName.trim();
    await txn.insert(
      'rhythms',
      RhythmModel.toMap(rhythm)..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final rows = await txn.query(
      'rhythms',
      columns: ['id'],
      where: 'rhythmName = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.single['id'] as int;
  }

  Future<int> _nextSongPosition(DatabaseExecutor db) async {
    final maxPosition = Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(position) FROM songs'),
        ) ??
        -1;
    return maxPosition + 1;
  }
}
