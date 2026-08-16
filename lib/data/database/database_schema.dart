import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/constants/default_chords.dart';
import '../../core/constants/default_scales.dart';
import '../../core/utils/relative_chords.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../models/tutorial_field_codec.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static const databaseName = 'personal_hymns_library.db';
  static const version = 21;

  static Future<void> reset(Database db) async {
    final batch = db.batch();
    for (final table in [
      'playlist_songs',
      'song_rhythm_item_rhythms',
      'song_rhythm_items',
      'song_chord_item_chords',
      'song_chord_item_images',
      'song_chord_items',
      'song_note_items',
      'scale_chord_tutorials',
      'song_chord_tutorials',
      'song_tags',
      'quarter_tones',
      'media',
      'note_images',
      'general_notes',
      'circle_tutorials',
      'lyrics_library_entries',
      'musical_scales',
      'songs',
      'playlists',
      'chord_tutorials',
      'rhythms',
      'tags',
    ]) {
      batch.execute('DROP TABLE IF EXISTS $table');
    }
    await batch.commit(noResult: true);
    await create(db);
    await seed(db);
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await reset(db);
      return;
    }
    final batch = db.batch();
    if (oldVersion < 4) {
      _createGeneralNotesTables(batch);
    }
    if (oldVersion < 5) {
      _createMusicalScalesTable(batch);
    }
    await batch.commit(noResult: true);
    if (oldVersion >= 5) {
      await _ensureScaleFormulaColumn(db);
      await _ensureScaleTutorialColumns(db);
    }
    if (oldVersion >= 5 && oldVersion < 6) {
      await _rebuildMusicalScalesTableForTypes(db);
    }
    if (oldVersion < 6) {
      await _seedDefaultScales(db);
    }
    if (oldVersion < 7) {
      await _ensureScaleFormulaColumn(db);
      await _seedDefaultScales(db, replaceDetails: true);
    }
    if (oldVersion < 8) {
      await _rebuildChordTutorialsTable(db);
      await _seedDefaultChords(db);
    }
    if (oldVersion < 9) {
      await _ensureScaleTutorialColumns(db);
      await _ensureChordTutorialColumns(db);
      final batch = db.batch();
      _createCircleTutorialsTable(batch);
      await batch.commit(noResult: true);
      await _seedDefaultScales(db, replaceDetails: true);
      await _seedDefaultChords(db, replaceDetails: true);
      await _seedDefaultCircleTutorials(db);
    }
    if (oldVersion < 10) {
      await _ensureChordTutorialColumns(db);
      await _seedDefaultChordInversions(db);
    }
    if (oldVersion < 11) {
      final batch = db.batch();
      _createSongChordTutorialsTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 12) {
      await _ensureChordTutorialColumns(db);
      await _seedDefaultChords(db);
    }
    if (oldVersion < 13) {
      await _ensureChordTutorialColumns(db);
      await _seedDefaultChords(db);
      await _refreshDefaultDiminishedChordInversions(db);
    }
    if (oldVersion < 14) {
      await _ensureChordTutorialColumns(db);
      await _seedDefaultRelativeChords(db);
    }
    if (oldVersion < 15) {
      await _ensureScaleTutorialColumns(db);
      await _ensureChordTutorialColumns(db);
      final batch = db.batch();
      _createScaleChordTutorialsTable(batch);
      await batch.commit(noResult: true);
      await _seedDefaultScaleChords(db);
    }
    if (oldVersion < 16) {
      final batch = db.batch();
      _createSongNoteItemsTable(batch);
      _createSongChordItemsTables(batch);
      await batch.commit(noResult: true);
      await _migrateSongNotesToItems(db);
      await _migrateSongChordsToItems(db);
    }
    if (oldVersion < 17) {
      await _ensureSongPositionColumn(db);
    }
    if (oldVersion < 18) {
      await _ensureSongCompletedColumn(db);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_songs_completed ON songs(completed)',
      );
      final batch = db.batch();
      _createLyricsLibraryTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 19) {
      await _ensureLyricsLibrarySourceColumns(db);
    }
    if (oldVersion < 20) {
      await _ensureLyricsLibrarySlideCountColumn(db);
    }
    if (oldVersion < 21) {
      await _ensureRhythmItemBpmColumn(db);
      await _migrateSongBpmToRhythmItems(db);
      await _seedDefaultScales(db, replaceDetails: true);
      await _seedDefaultScaleChords(db);
      await _reorderDefaultScaleChords(db);
    }
  }

  static Future<void> create(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE rhythms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rhythmName TEXT NOT NULL UNIQUE,
        section TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        myStartingKey TEXT NOT NULL,
        transposeValue INTEGER NOT NULL,
        originalScale TEXT,
        myScale TEXT,
        originalStartingKey TEXT,
        bpm INTEGER,
        lyrics TEXT,
        notes TEXT,
        primaryRhythm TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        favorite INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE song_tags (
        songId INTEGER NOT NULL,
        tagId INTEGER NOT NULL,
        PRIMARY KEY (songId, tagId),
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE,
        FOREIGN KEY (tagId) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE quarter_tones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        value TEXT NOT NULL,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE song_rhythm_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        bpm INTEGER,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE song_rhythm_item_rhythms (
        itemId INTEGER NOT NULL,
        rhythmId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (itemId, rhythmId),
        FOREIGN KEY (itemId) REFERENCES song_rhythm_items(id) ON DELETE CASCADE,
        FOREIGN KEY (rhythmId) REFERENCES rhythms(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        mediaType TEXT NOT NULL,
        localPath TEXT,
        externalUrl TEXT,
        title TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE,
        CHECK (localPath IS NOT NULL OR externalUrl IS NOT NULL)
      )
    ''');

    batch.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistName TEXT NOT NULL UNIQUE
      )
    ''');

    batch.execute('''
      CREATE TABLE playlist_songs (
        playlistId INTEGER NOT NULL,
        songId INTEGER NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlistId, songId),
        FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    _createChordTutorialsTable(batch);
    _createSongChordTutorialsTable(batch);
    _createSongNoteItemsTable(batch);
    _createSongChordItemsTables(batch);

    _createMusicalScalesTable(batch);
    _createScaleChordTutorialsTable(batch);
    _createCircleTutorialsTable(batch);
    _createGeneralNotesTables(batch);
    _createLyricsLibraryTable(batch);

    batch.execute('CREATE INDEX idx_songs_name ON songs(name)');
    batch.execute('CREATE INDEX idx_songs_favorite ON songs(favorite)');
    batch.execute('CREATE INDEX idx_songs_completed ON songs(completed)');
    batch.execute('CREATE INDEX idx_song_tags_song ON song_tags(songId)');
    batch.execute('CREATE INDEX idx_song_tags_tag ON song_tags(tagId)');
    batch.execute(
      'CREATE INDEX idx_quarter_tones_song ON quarter_tones(songId)',
    );
    batch.execute('CREATE INDEX idx_rhythms_name ON rhythms(rhythmName)');
    batch.execute(
      'CREATE INDEX idx_song_rhythm_items_song ON song_rhythm_items(songId)',
    );
    batch.execute(
      'CREATE INDEX idx_song_rhythm_item_rhythms_item ON song_rhythm_item_rhythms(itemId)',
    );
    batch.execute(
      'CREATE INDEX idx_song_rhythm_item_rhythms_rhythm ON song_rhythm_item_rhythms(rhythmId)',
    );
    batch.execute(
      'CREATE INDEX idx_media_song_type ON media(songId, mediaType)',
    );
    batch.execute(
      'CREATE INDEX idx_playlist_songs_playlist ON playlist_songs(playlistId)',
    );

    await batch.commit(noResult: true);
  }

  static void _createMusicalScalesTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS musical_scales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        keys TEXT NOT NULL,
        formula TEXT NOT NULL DEFAULT '',
        imagePath TEXT,
        videoPath TEXT,
        notes TEXT NOT NULL DEFAULT '[]',
        links TEXT NOT NULL DEFAULT '[]',
        customFields TEXT NOT NULL DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        UNIQUE(name, type)
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_musical_scales_name ON musical_scales(name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_musical_scales_type ON musical_scales(type)',
    );
  }

  static void _createChordTutorialsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS chord_tutorials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        keys TEXT NOT NULL,
        imagePath TEXT,
        videoPath TEXT,
        relativeChordId INTEGER,
        inversions TEXT NOT NULL DEFAULT '[]',
        notes TEXT NOT NULL DEFAULT '[]',
        links TEXT NOT NULL DEFAULT '[]',
        customFields TEXT NOT NULL DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (relativeChordId) REFERENCES chord_tutorials(id) ON DELETE SET NULL,
        UNIQUE(name, type)
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_chord_tutorials_name ON chord_tutorials(name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_chord_tutorials_type ON chord_tutorials(type)',
    );
  }

  static void _createSongChordTutorialsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS song_chord_tutorials (
        songId INTEGER NOT NULL,
        chordTutorialId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (songId, chordTutorialId),
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE,
        FOREIGN KEY (chordTutorialId) REFERENCES chord_tutorials(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_tutorials_song ON song_chord_tutorials(songId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_tutorials_chord ON song_chord_tutorials(chordTutorialId)',
    );
  }

  static void _createSongNoteItemsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS song_note_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_note_items_song ON song_note_items(songId)',
    );
  }

  static void _createSongChordItemsTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS song_chord_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_items_song ON song_chord_items(songId)',
    );

    batch.execute('''
      CREATE TABLE IF NOT EXISTS song_chord_item_chords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER NOT NULL,
        chordTutorialId INTEGER NOT NULL,
        inversionIndex INTEGER,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (itemId) REFERENCES song_chord_items(id) ON DELETE CASCADE,
        FOREIGN KEY (chordTutorialId) REFERENCES chord_tutorials(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_item_chords_item ON song_chord_item_chords(itemId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_item_chords_chord ON song_chord_item_chords(chordTutorialId)',
    );

    batch.execute('''
      CREATE TABLE IF NOT EXISTS song_chord_item_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER NOT NULL,
        localPath TEXT,
        externalUrl TEXT,
        title TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (itemId) REFERENCES song_chord_items(id) ON DELETE CASCADE,
        CHECK (localPath IS NOT NULL OR externalUrl IS NOT NULL)
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_chord_item_images_item ON song_chord_item_images(itemId)',
    );
  }

  static void _createScaleChordTutorialsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS scale_chord_tutorials (
        scaleId INTEGER NOT NULL,
        chordTutorialId INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (scaleId, chordTutorialId),
        FOREIGN KEY (scaleId) REFERENCES musical_scales(id) ON DELETE CASCADE,
        FOREIGN KEY (chordTutorialId) REFERENCES chord_tutorials(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_scale_chord_tutorials_scale ON scale_chord_tutorials(scaleId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_scale_chord_tutorials_chord ON scale_chord_tutorials(chordTutorialId)',
    );
  }

  static void _createCircleTutorialsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS circle_tutorials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        summary TEXT,
        imagePath TEXT,
        videoPath TEXT,
        notes TEXT NOT NULL DEFAULT '[]',
        links TEXT NOT NULL DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_circle_tutorials_title ON circle_tutorials(title)',
    );
  }

  static void _createGeneralNotesTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS general_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS note_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER NOT NULL,
        localPath TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (noteId) REFERENCES general_notes(id) ON DELETE CASCADE
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_general_notes_updated ON general_notes(updatedAt)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_general_notes_pinned ON general_notes(pinned)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_images_note ON note_images(noteId)',
    );
  }

  static void _createLyricsLibraryTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS lyrics_library_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        payload TEXT NOT NULL,
        searchText TEXT NOT NULL DEFAULT '',
        chorusFirst INTEGER NOT NULL DEFAULT 0,
        slideCount INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'custom',
        sourceId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_title ON lyrics_library_entries(title)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_search ON lyrics_library_entries(searchText)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_slide_count ON lyrics_library_entries(slideCount)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_source ON lyrics_library_entries(source, sourceId)',
    );
    batch.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_lyrics_library_source_unique ON lyrics_library_entries(source, sourceId) WHERE sourceId IS NOT NULL',
    );
  }

  static Future<void> seed(Database db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM songs'),
    );
    if ((existing ?? 0) > 0) {
      return;
    }

    await db.transaction((txn) async {
      await _seedDefaultScales(txn);
      await _seedDefaultChords(txn);
      await _seedDefaultRelativeChords(txn);
      await _seedDefaultScaleChords(txn);
      await _seedDefaultCircleTutorials(txn);

      final worshipTag = await txn.insert('tags', {
        'name': 'Worship',
        'color': 0xFF2F6F6D,
      });
      final rehearsalTag = await txn.insert('tags', {
        'name': 'Rehearsal',
        'color': 0xFF795548,
      });
      final hymnRhythm = await txn.insert('rhythms', {
        'rhythmName': '3/4 Hymn',
        'section': 'Annual',
      });
      final balladRhythm = await txn.insert('rhythms', {
        'rhythmName': '4/4 Ballad',
        'section': 'Annual',
      });

      final now = DateTime.now().toIso8601String();
      final amazingGrace = await txn.insert('songs', {
        'name': 'Amazing Grace',
        'myStartingKey': 'G',
        'transposeValue': 0,
        'originalScale': 'G Major',
        'myScale': 'G Major',
        'originalStartingKey': 'G',
        'bpm': 82,
        'lyrics': 'Amazing grace, how sweet the sound.',
        'notes': 'Keep the intro simple and leave room before verse 2.',
        'primaryRhythm': '3/4 Hymn',
        'position': 0,
        'completed': 1,
        'favorite': 1,
        'createdAt': now,
        'updatedAt': now,
      });

      final holyHoly = await txn.insert('songs', {
        'name': 'Holy, Holy, Holy',
        'myStartingKey': 'D',
        'transposeValue': -2,
        'originalScale': 'E Major',
        'myScale': 'D Major',
        'originalStartingKey': 'E',
        'bpm': 72,
        'lyrics': 'Holy, holy, holy, Lord God Almighty.',
        'notes': 'Use softer vocal line for the first verse.',
        'primaryRhythm': '4/4 Ballad',
        'position': 1,
        'completed': 0,
        'favorite': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      await _insertQuarterTone(txn, holyHoly, 'B');

      await _insertSongTag(txn, amazingGrace, worshipTag);
      await _insertSongTag(txn, holyHoly, rehearsalTag);

      await _insertRhythmItem(txn, amazingGrace, [hymnRhythm], 0, bpm: 82);
      await _insertRhythmItem(txn, holyHoly, [balladRhythm], 0, bpm: 72);

      final playlistId = await txn.insert('playlists', {
        'playlistName': 'Sunday Set',
      });
      await txn.insert('playlist_songs', {
        'playlistId': playlistId,
        'songId': amazingGrace,
        'position': 0,
      });
      await txn.insert('playlist_songs', {
        'playlistId': playlistId,
        'songId': holyHoly,
        'position': 1,
      });
    });
  }

  static Future<void> _migrateSongNotesToItems(DatabaseExecutor db) async {
    final songs = await db.query(
      'songs',
      columns: ['id', 'notes'],
      where: "notes IS NOT NULL AND TRIM(notes) <> ''",
    );
    for (final song in songs) {
      final songId = song['id'] as int?;
      final notes = song['notes'] as String?;
      if (songId == null || notes == null || notes.trim().isEmpty) {
        continue;
      }
      final existing = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM song_note_items WHERE songId = ?',
              [songId],
            ),
          ) ??
          0;
      if (existing > 0) {
        continue;
      }
      await db.insert('song_note_items', {
        'songId': songId,
        'title': '',
        'body': notes.trim(),
        'position': 0,
      });
    }
  }

  static Future<void> _migrateSongChordsToItems(DatabaseExecutor db) async {
    final songs = await db.query('songs', columns: ['id']);
    for (final song in songs) {
      final songId = song['id'] as int?;
      if (songId == null) {
        continue;
      }
      final existing = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM song_chord_items WHERE songId = ?',
              [songId],
            ),
          ) ??
          0;
      if (existing > 0) {
        continue;
      }

      final chordRows = await db.query(
        'song_chord_tutorials',
        where: 'songId = ?',
        whereArgs: [songId],
        orderBy: 'position ASC',
      );
      final imageRows = await db.query(
        'media',
        where: 'songId = ? AND mediaType = ?',
        whereArgs: [songId, 'chord_image'],
        orderBy: 'sortOrder ASC, id ASC',
      );
      if (chordRows.isEmpty && imageRows.isEmpty) {
        continue;
      }

      final itemId = await db.insert('song_chord_items', {
        'songId': songId,
        'position': 0,
      });
      for (var index = 0; index < chordRows.length; index++) {
        final chordId = chordRows[index]['chordTutorialId'] as int?;
        if (chordId == null) {
          continue;
        }
        await db.insert('song_chord_item_chords', {
          'itemId': itemId,
          'chordTutorialId': chordId,
          'inversionIndex': null,
          'position': index,
        });
      }
      for (var index = 0; index < imageRows.length; index++) {
        final image = imageRows[index];
        await db.insert('song_chord_item_images', {
          'itemId': itemId,
          'localPath': image['localPath'] as String?,
          'externalUrl': image['externalUrl'] as String?,
          'title': image['title'] as String? ?? 'Chord image',
          'sortOrder': index,
        });
      }
    }
  }

  static Future<void> _ensureSongPositionColumn(DatabaseExecutor db) async {
    if (!await _tableHasColumn(db, 'songs', 'position')) {
      await db.execute(
        'ALTER TABLE songs ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
      );
    }
    final rows = await db.query(
      'songs',
      columns: ['id'],
      orderBy: 'name COLLATE NOCASE, id ASC',
    );
    for (var index = 0; index < rows.length; index++) {
      final id = rows[index]['id'] as int?;
      if (id == null) {
        continue;
      }
      await db.update(
        'songs',
        {'position': index},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _ensureSongCompletedColumn(DatabaseExecutor db) async {
    if (!await _tableHasColumn(db, 'songs', 'completed')) {
      await db.execute(
        'ALTER TABLE songs ADD COLUMN completed INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<void> _ensureLyricsLibrarySourceColumns(
    DatabaseExecutor db,
  ) async {
    if (!await _tableHasColumn(db, 'lyrics_library_entries', 'source')) {
      await db.execute(
        "ALTER TABLE lyrics_library_entries ADD COLUMN source TEXT NOT NULL DEFAULT 'custom'",
      );
    }
    if (!await _tableHasColumn(db, 'lyrics_library_entries', 'sourceId')) {
      await db.execute(
        'ALTER TABLE lyrics_library_entries ADD COLUMN sourceId TEXT',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_source ON lyrics_library_entries(source, sourceId)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_lyrics_library_source_unique ON lyrics_library_entries(source, sourceId) WHERE sourceId IS NOT NULL',
    );
  }

  static Future<void> _ensureLyricsLibrarySlideCountColumn(
    DatabaseExecutor db,
  ) async {
    if (!await _tableHasColumn(db, 'lyrics_library_entries', 'slideCount')) {
      await db.execute(
        'ALTER TABLE lyrics_library_entries ADD COLUMN slideCount INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lyrics_library_slide_count ON lyrics_library_entries(slideCount)',
    );

    final rows = await db.query(
      'lyrics_library_entries',
      columns: ['id', 'payload'],
      where: 'slideCount = 0',
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) {
        continue;
      }
      await db.update(
        'lyrics_library_entries',
        {'slideCount': _lyricsSlideCountFromPayload(row['payload'])},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _ensureRhythmItemBpmColumn(DatabaseExecutor db) async {
    if (!await _tableHasColumn(db, 'song_rhythm_items', 'bpm')) {
      await db.execute('ALTER TABLE song_rhythm_items ADD COLUMN bpm INTEGER');
    }
  }

  static Future<void> _migrateSongBpmToRhythmItems(DatabaseExecutor db) async {
    final rows = await db.query(
      'songs',
      columns: ['id', 'bpm', 'primaryRhythm'],
      where: 'bpm IS NOT NULL',
    );
    for (final row in rows) {
      final songId = row['id'] as int?;
      final bpm = row['bpm'] as int?;
      if (songId == null || bpm == null) {
        continue;
      }
      final itemRows = await db.query(
        'song_rhythm_items',
        columns: ['id', 'bpm'],
        where: 'songId = ?',
        whereArgs: [songId],
        orderBy: 'position ASC, id ASC',
        limit: 1,
      );
      if (itemRows.isNotEmpty) {
        final itemId = itemRows.first['id'] as int?;
        if (itemId != null && itemRows.first['bpm'] == null) {
          await db.update(
            'song_rhythm_items',
            {'bpm': bpm},
            where: 'id = ?',
            whereArgs: [itemId],
          );
        }
        continue;
      }

      final rhythmName = (row['primaryRhythm'] as String?)?.trim();
      if (rhythmName == null || rhythmName.isEmpty) {
        continue;
      }
      final rhythmId = await _ensureRhythmByName(db, rhythmName);
      final itemId = await db.insert('song_rhythm_items', {
        'songId': songId,
        'position': 0,
        'bpm': bpm,
      });
      await db.insert(
        'song_rhythm_item_rhythms',
        {
          'itemId': itemId,
          'rhythmId': rhythmId,
          'position': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<int> _ensureRhythmByName(
    DatabaseExecutor db,
    String rhythmName,
  ) async {
    final name = rhythmName.trim();
    await db.insert(
      'rhythms',
      {'rhythmName': name, 'section': null},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final rows = await db.query(
      'rhythms',
      columns: ['id'],
      where: 'rhythmName = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.single['id'] as int;
  }

  static int _lyricsSlideCountFromPayload(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return 0;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return 0;
      }
      final chorusCount = _lyricsStringListCount(decoded['chorus']);
      final verseCount = _lyricsVerseSlideCount(decoded['verses']);
      if (chorusCount == 0) {
        return verseCount;
      }
      final chorusFirst = decoded['chorusFirst'] == true;
      var count = chorusFirst ? chorusCount : 0;
      if (verseCount > 0) {
        count += verseCount * (chorusCount + 1);
      } else if (!chorusFirst) {
        count += chorusCount;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static int _lyricsStringListCount(Object? value) {
    if (value is String) {
      return value.trim().isEmpty ? 0 : 1;
    }
    if (value is! List) {
      return 0;
    }
    return value.where((item) {
      return item != null && item.toString().trim().isNotEmpty;
    }).length;
  }

  static int _lyricsVerseSlideCount(Object? value) {
    if (value is! List) {
      return 0;
    }
    var count = 0;
    for (final item in value) {
      if (item is String) {
        if (item.trim().isNotEmpty) {
          count++;
        }
        continue;
      }
      if (item is List &&
          item.any(
              (line) => line != null && line.toString().trim().isNotEmpty)) {
        count++;
      }
    }
    return count;
  }

  static Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tables.isEmpty) {
      return false;
    }
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((item) => item['name'] == column);
  }

  static Future<void> _seedDefaultScales(
    DatabaseExecutor db, {
    bool replaceDetails = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    for (final scale in DefaultScaleCatalog.definitions) {
      await db.rawInsert(
        '''
        INSERT OR IGNORE INTO musical_scales
        (name, type, keys, formula, imagePath, videoPath, notes, links, customFields, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?)
        ''',
        [
          scale.name,
          scale.type,
          scale.keys,
          scale.formula,
          scale.imagePath,
          _defaultScaleNotes(scale),
          _emptyLinks,
          _emptyCustomFields,
          now,
          now,
        ],
      );
      if (replaceDetails) {
        await db.update(
          'musical_scales',
          {
            'keys': scale.keys,
            'formula': scale.formula,
            'notes': _defaultScaleNotes(scale),
            'updatedAt': now,
          },
          where: 'name = ? AND type = ?',
          whereArgs: [scale.name, scale.type],
        );
        await db.update(
          'musical_scales',
          {
            'imagePath': scale.imagePath,
            'updatedAt': now,
          },
          where:
              'name = ? AND type = ? AND (imagePath IS NULL OR imagePath = ?)',
          whereArgs: [scale.name, scale.type, ''],
        );
      }
    }
  }

  static Future<void> _seedDefaultChords(
    DatabaseExecutor db, {
    bool replaceDetails = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    for (final chord in DefaultChordCatalog.definitions) {
      await db.rawInsert(
        '''
        INSERT OR IGNORE INTO chord_tutorials
        (name, type, keys, imagePath, videoPath, relativeChordId, inversions, notes, links, customFields, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?, ?, ?)
        ''',
        [
          chord.name,
          chord.type,
          chord.keys,
          chord.imagePath,
          _defaultChordInversions(chord),
          _defaultChordNotes(chord),
          _emptyLinks,
          _emptyCustomFields,
          now,
          now,
        ],
      );
      if (replaceDetails) {
        await db.update(
          'chord_tutorials',
          {
            'keys': chord.keys,
            'inversions': _defaultChordInversions(chord),
            'notes': _defaultChordNotes(chord),
            'updatedAt': now,
          },
          where: 'name = ? AND type = ?',
          whereArgs: [chord.name, chord.type],
        );
        await db.update(
          'chord_tutorials',
          {
            'imagePath': chord.imagePath,
            'updatedAt': now,
          },
          where:
              'name = ? AND type = ? AND (imagePath IS NULL OR imagePath = ?)',
          whereArgs: [chord.name, chord.type, ''],
        );
      }
    }
  }

  static Future<void> _seedDefaultChordInversions(DatabaseExecutor db) async {
    await _seedDefaultChords(db);
    final now = DateTime.now().toIso8601String();
    for (final chord in DefaultChordCatalog.definitions) {
      await db.update(
        'chord_tutorials',
        {
          'inversions': _defaultChordInversions(chord),
          'updatedAt': now,
        },
        where:
            "name = ? AND type = ? AND (inversions IS NULL OR TRIM(inversions) = '' OR inversions = ?)",
        whereArgs: [chord.name, chord.type, _emptyInversions],
      );
    }
  }

  static Future<void> _seedDefaultRelativeChords(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    for (final source in DefaultChordCatalog.definitions) {
      final targetType = RelativeChords.targetTypeFor(source.type);
      if (targetType == null) {
        continue;
      }
      final sourceId = await _chordTutorialId(db, source.name, source.type);
      if (sourceId == null) {
        continue;
      }
      final targetId = await _relativeChordTutorialId(
        db,
        source.name,
        source.type,
        targetType,
      );
      if (targetId == null) {
        continue;
      }
      await db.update(
        'chord_tutorials',
        {
          'relativeChordId': targetId,
          'updatedAt': now,
        },
        where: 'id = ? AND relativeChordId IS NULL',
        whereArgs: [sourceId],
      );
    }
  }

  static Future<int?> _relativeChordTutorialId(
    DatabaseExecutor db,
    String sourceName,
    String sourceType,
    String targetType,
  ) async {
    for (final targetName
        in RelativeChords.targetRootNamesFor(sourceName, sourceType)) {
      final id = await _chordTutorialId(db, targetName, targetType);
      if (id != null) {
        return id;
      }
    }
    return null;
  }

  static Future<int?> _chordTutorialId(
    DatabaseExecutor db,
    String name,
    String type,
  ) async {
    final rows = await db.query(
      'chord_tutorials',
      columns: ['id'],
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int?;
  }

  static Future<void> _seedDefaultScaleChords(DatabaseExecutor db) async {
    for (final scale in DefaultScaleCatalog.definitions) {
      final scaleId = await _scaleId(db, scale.name, scale.type);
      if (scaleId == null) {
        continue;
      }
      final existing = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM scale_chord_tutorials WHERE scaleId = ?',
              [scaleId],
            ),
          ) ??
          0;
      if (existing > 0) {
        continue;
      }
      final chords = _defaultScaleChordDefinitions(scale);
      for (var index = 0; index < chords.length; index++) {
        final chord = chords[index];
        final chordId = await _chordTutorialId(db, chord.name, chord.type);
        if (chordId == null) {
          continue;
        }
        await db.insert(
          'scale_chord_tutorials',
          {
            'scaleId': scaleId,
            'chordTutorialId': chordId,
            'position': index,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  static Future<void> _reorderDefaultScaleChords(DatabaseExecutor db) async {
    for (final scale in DefaultScaleCatalog.definitions) {
      final scaleId = await _scaleId(db, scale.name, scale.type);
      if (scaleId == null) {
        continue;
      }
      final desiredIds = <int>[];
      for (final chord in _defaultScaleChordDefinitions(scale)) {
        final chordId = await _chordTutorialId(db, chord.name, chord.type);
        if (chordId != null) {
          desiredIds.add(chordId);
        }
      }
      if (desiredIds.isEmpty) {
        continue;
      }
      final existingRows = await db.query(
        'scale_chord_tutorials',
        columns: ['chordTutorialId'],
        where: 'scaleId = ?',
        whereArgs: [scaleId],
        orderBy: 'position ASC',
      );
      final existingIds = [
        for (final row in existingRows)
          if (row['chordTutorialId'] != null) row['chordTutorialId'] as int,
      ];
      if (existingIds.length != desiredIds.length) {
        continue;
      }
      final existingSet = existingIds.toSet();
      if (!desiredIds.every(existingSet.contains)) {
        continue;
      }
      for (var index = 0; index < desiredIds.length; index++) {
        await db.update(
          'scale_chord_tutorials',
          {'position': index},
          where: 'scaleId = ? AND chordTutorialId = ?',
          whereArgs: [scaleId, desiredIds[index]],
        );
      }
    }
  }

  static List<({String name, String type})> _defaultScaleChordDefinitions(
    DefaultScaleDefinition scale,
  ) {
    final intervals = scale.type == 'Minor'
        ? const [0, 2, 3, 5, 7, 8, 10]
        : const [0, 2, 4, 5, 7, 9, 11];
    final chordTypes = scale.type == 'Minor'
        ? const [
            'Minor',
            'Diminished',
            'Major',
            'Minor',
            'Minor',
            'Major',
            'Major',
          ]
        : const [
            'Major',
            'Minor',
            'Minor',
            'Major',
            'Major',
            'Minor',
            'Diminished',
          ];
    final chromatic = _preferFlatScaleNames(scale.name, scale.type)
        ? _flatChromatic
        : _sharpChromatic;
    final rootIndex = chromatic.indexOf(scale.name);
    final effectiveRootIndex =
        rootIndex >= 0 ? rootIndex : _sharpChromatic.indexOf(scale.name);
    final definitions = [
      for (var i = 0; i < intervals.length; i++)
        (
          name:
              chromatic[(effectiveRootIndex + intervals[i]) % chromatic.length],
          type: chordTypes[i],
          index: i,
        ),
    ];
    definitions.sort((a, b) {
      final typeComparison =
          _scaleChordTypeOrder(a.type).compareTo(_scaleChordTypeOrder(b.type));
      if (typeComparison != 0) {
        return typeComparison;
      }
      return a.index.compareTo(b.index);
    });
    return [
      for (final definition in definitions)
        (name: definition.name, type: definition.type),
    ];
  }

  static int _scaleChordTypeOrder(String type) {
    return switch (type) {
      'Major' => 0,
      'Minor' => 1,
      'Diminished' => 2,
      _ => 3,
    };
  }

  static bool _preferFlatScaleNames(String root, String type) {
    if (root.contains('b')) {
      return true;
    }
    if (root.contains('#')) {
      return false;
    }
    return switch (type) {
      'Minor' => const ['D', 'G', 'C', 'F'].contains(root),
      _ => root == 'F',
    };
  }

  static Future<int?> _scaleId(
    DatabaseExecutor db,
    String name,
    String type,
  ) async {
    final rows = await db.query(
      'musical_scales',
      columns: ['id'],
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int?;
  }

  static Future<void> _refreshDefaultDiminishedChordInversions(
    DatabaseExecutor db,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final chord in DefaultChordCatalog.definitions) {
      if (!_isDiminishedChordType(chord.type)) {
        continue;
      }
      final rows = await db.query(
        'chord_tutorials',
        columns: ['id', 'inversions'],
        where: 'name = ? AND type = ?',
        whereArgs: [chord.name, chord.type],
        limit: 1,
      );
      if (rows.isEmpty) {
        continue;
      }
      final id = rows.first['id'] as int?;
      if (id == null) {
        continue;
      }

      final defaultInversions = {
        for (final inversion in chord.inversions) inversion.name: inversion,
      };
      final currentInversions = TutorialFieldCodec.decodeInversions(
        rows.first['inversions'],
      );
      if (currentInversions.isEmpty) {
        await db.update(
          'chord_tutorials',
          {
            'inversions': _defaultChordInversions(chord),
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        continue;
      }

      var changed = false;
      final merged = <ChordInversion>[];
      final seen = <String>{};
      for (final inversion in currentInversions) {
        seen.add(inversion.name);
        final defaultInversion = defaultInversions[inversion.name];
        final defaultImagePath = defaultInversion?.imagePath;
        if ((inversion.imagePath == null ||
                inversion.imagePath!.trim().isEmpty) &&
            defaultImagePath != null &&
            defaultImagePath.trim().isNotEmpty) {
          merged.add(inversion.copyWith(imagePath: defaultImagePath));
          changed = true;
        } else {
          merged.add(inversion);
        }
      }

      for (final defaultInversion in chord.inversions) {
        if (seen.contains(defaultInversion.name)) {
          continue;
        }
        merged.add(_defaultChordInversion(defaultInversion));
        changed = true;
      }

      if (!changed) {
        continue;
      }
      await db.update(
        'chord_tutorials',
        {
          'inversions': TutorialFieldCodec.encodeInversions(merged),
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static bool _isDiminishedChordType(String type) {
    return type.toLowerCase().contains('diminished');
  }

  static Future<void> _seedDefaultCircleTutorials(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO circle_tutorials
      (title, summary, imagePath, videoPath, notes, links, createdAt, updatedAt)
      VALUES (?, ?, ?, NULL, ?, ?, ?, ?)
      ''',
      [
        'Circle of Fifths',
        'A map for key signatures, closely related keys, and common progressions.',
        'asset://piano_scale_images_pianoscales_org/circle_of_fifths_article_image_2023.png',
        TutorialFieldCodec.encodeNotes(const [
          TutorialNote(
            title: 'What it shows',
            body:
                'The circle arranges keys by perfect fifths. Moving clockwise adds one sharp; moving counter-clockwise adds one flat.',
          ),
          TutorialNote(
            title: 'How to read it',
            body:
                'Start at C. One step clockwise is G with one sharp. Another step is D with two sharps. One step counter-clockwise is F with one flat.',
          ),
          TutorialNote(
            title: 'Example: C to G',
            body:
                'C major has no sharps or flats. G major is one fifth above C, so it adds F#. The G major scale is G, A, B, C, D, E, F#, G.',
          ),
          TutorialNote(
            title: 'Practice step',
            body:
                'Pick any key, move one position clockwise, then play both scales and listen for how closely related they sound.',
          ),
        ]),
        _emptyLinks,
        now,
        now,
      ],
    );
  }

  static String get _emptyNotes {
    return TutorialFieldCodec.encodeNotes(const []);
  }

  static String get _emptyLinks {
    return TutorialFieldCodec.encodeLinks(const []);
  }

  static String get _emptyCustomFields {
    return TutorialFieldCodec.encodeCustomFields(const []);
  }

  static String get _emptyInversions {
    return TutorialFieldCodec.encodeInversions(const []);
  }

  static String _defaultScaleNotes(DefaultScaleDefinition scale) {
    return TutorialFieldCodec.encodeNotes([
      TutorialNote(
        title: 'Formula',
        body: '${scale.displayName}: ${scale.formula}',
      ),
      TutorialNote(
        title: 'Practice tip',
        body:
            'Play ${scale.displayName} slowly ascending and descending. Keep the fingering even and listen for the ${scale.type.toLowerCase()} sound.',
      ),
    ]);
  }

  static String _defaultChordNotes(DefaultChordDefinition chord) {
    return TutorialFieldCodec.encodeNotes([
      TutorialNote(
        title: 'Chord structure',
        body: chord.notes,
      ),
      TutorialNote(
        title: 'Practice tip',
        body:
            'Play ${chord.displayName} blocked, then broken from low to high. Say the note names while you play: ${chord.keys}.',
      ),
    ]);
  }

  static String _defaultChordInversions(DefaultChordDefinition chord) {
    return TutorialFieldCodec.encodeInversions([
      for (final inversion in chord.inversions)
        _defaultChordInversion(inversion),
    ]);
  }

  static ChordInversion _defaultChordInversion(
    DefaultChordInversionDefinition inversion,
  ) {
    return ChordInversion(
      name: inversion.name,
      keys: inversion.keys,
      imagePath: inversion.imagePath,
      notes: [
        TutorialNote(title: 'How to use it', body: inversion.notes),
      ],
    );
  }

  static Future<void> _ensureScaleFormulaColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(musical_scales)');
    final hasFormula = columns.any((column) => column['name'] == 'formula');
    if (!hasFormula) {
      await db.execute(
        "ALTER TABLE musical_scales ADD COLUMN formula TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  static Future<void> _ensureScaleTutorialColumns(Database db) async {
    if (!await _tableExists(db, 'musical_scales')) {
      final batch = db.batch();
      _createMusicalScalesTable(batch);
      await batch.commit(noResult: true);
      return;
    }
    final columns = await db.rawQuery('PRAGMA table_info(musical_scales)');
    await _ensureColumn(
      db,
      columns,
      table: 'musical_scales',
      column: 'videoPath',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      columns,
      table: 'musical_scales',
      column: 'links',
      definition: "TEXT NOT NULL DEFAULT '[]'",
    );
    await _ensureColumn(
      db,
      columns,
      table: 'musical_scales',
      column: 'customFields',
      definition: "TEXT NOT NULL DEFAULT '[]'",
    );
  }

  static Future<void> _ensureChordTutorialColumns(Database db) async {
    if (!await _tableExists(db, 'chord_tutorials')) {
      final batch = db.batch();
      _createChordTutorialsTable(batch);
      await batch.commit(noResult: true);
      return;
    }
    final columns = await db.rawQuery('PRAGMA table_info(chord_tutorials)');
    await _ensureColumn(
      db,
      columns,
      table: 'chord_tutorials',
      column: 'videoPath',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      columns,
      table: 'chord_tutorials',
      column: 'links',
      definition: "TEXT NOT NULL DEFAULT '[]'",
    );
    await _ensureColumn(
      db,
      columns,
      table: 'chord_tutorials',
      column: 'inversions',
      definition: "TEXT NOT NULL DEFAULT '[]'",
    );
    await _ensureColumn(
      db,
      columns,
      table: 'chord_tutorials',
      column: 'relativeChordId',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      columns,
      table: 'chord_tutorials',
      column: 'customFields',
      definition: "TEXT NOT NULL DEFAULT '[]'",
    );
  }

  static Future<void> _ensureColumn(
    Database db,
    List<Map<String, Object?>> columns, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final exists = columns.any((item) => item['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _rebuildMusicalScalesTableForTypes(Database db) async {
    final rows = await db.query('musical_scales');
    await db.transaction((txn) async {
      await txn
          .execute('ALTER TABLE musical_scales RENAME TO musical_scales_old');
      await txn.execute('DROP INDEX IF EXISTS idx_musical_scales_name');
      await txn.execute('DROP INDEX IF EXISTS idx_musical_scales_type');
      final batch = txn.batch();
      _createMusicalScalesTable(batch);
      await batch.commit(noResult: true);

      for (final row in rows) {
        final rawName = (row['name'] as String?)?.trim() ?? '';
        if (rawName.isEmpty || rawName == 'Major' || rawName == 'Minor') {
          continue;
        }
        final parsed = _parseScaleName(rawName);
        await txn.insert(
          'musical_scales',
          {
            'name': parsed.name,
            'type': parsed.type,
            'keys': row['keys'] as String? ?? '',
            'formula': row['formula'] as String? ?? '',
            'imagePath': row['imagePath'] as String?,
            'videoPath': row['videoPath'] as String?,
            'notes': row['notes'] as String?,
            'links': row['links'] as String? ?? _emptyLinks,
            'customFields':
                row['customFields'] as String? ?? _emptyCustomFields,
            'createdAt':
                row['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            'updatedAt':
                row['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.execute('DROP TABLE musical_scales_old');
    });
  }

  static Future<void> _rebuildChordTutorialsTable(Database db) async {
    final exists = await _tableExists(db, 'chord_tutorials');
    if (!exists) {
      final batch = db.batch();
      _createChordTutorialsTable(batch);
      await batch.commit(noResult: true);
      return;
    }

    final rows = await db.query('chord_tutorials');
    await db.transaction((txn) async {
      await txn
          .execute('ALTER TABLE chord_tutorials RENAME TO chord_tutorials_old');
      await txn.execute('DROP INDEX IF EXISTS idx_chord_tutorials_name');
      await txn.execute('DROP INDEX IF EXISTS idx_chord_tutorials_type');
      final batch = txn.batch();
      _createChordTutorialsTable(batch);
      await batch.commit(noResult: true);

      for (final row in rows) {
        final parsed = _chordIdentityFor(row);
        if (parsed.name.isEmpty) {
          continue;
        }
        final defaultChord = _defaultChord(parsed.name, parsed.type);
        final keys = (row['keys'] as String?)?.trim();
        final notes = (row['notes'] as String?)?.trim();
        final now = DateTime.now().toIso8601String();
        await txn.insert(
          'chord_tutorials',
          {
            'name': parsed.name,
            'type': parsed.type,
            'keys':
                keys == null || keys.isEmpty ? defaultChord?.keys ?? '' : keys,
            'imagePath': row['imagePath'] as String? ?? defaultChord?.imagePath,
            'videoPath': row['videoPath'] as String?,
            'relativeChordId': row['relativeChordId'] as int?,
            'inversions': row['inversions'] as String? ??
                (defaultChord == null
                    ? _emptyInversions
                    : _defaultChordInversions(defaultChord)),
            'notes': notes == null || notes.isEmpty
                ? defaultChord == null
                    ? _emptyNotes
                    : _defaultChordNotes(defaultChord)
                : notes,
            'links': row['links'] as String? ?? _emptyLinks,
            'customFields':
                row['customFields'] as String? ?? _emptyCustomFields,
            'createdAt': row['createdAt'] as String? ?? now,
            'updatedAt': row['updatedAt'] as String? ?? now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.execute('DROP TABLE chord_tutorials_old');
    });
  }

  static Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  static ({String name, String type}) _chordIdentityFor(
    Map<String, Object?> row,
  ) {
    final name = (row['name'] as String?)?.trim();
    final type = (row['type'] as String?)?.trim();
    if (name != null && name.isNotEmpty && type != null && type.isNotEmpty) {
      return (name: name, type: type);
    }
    return _parseChordName(row['chordName'] as String? ?? '');
  }

  static DefaultChordDefinition? _defaultChord(String name, String type) {
    for (final chord in DefaultChordCatalog.definitions) {
      if (chord.name.toLowerCase() == name.toLowerCase() &&
          chord.type.toLowerCase() == type.toLowerCase()) {
        return chord;
      }
    }
    return null;
  }

  static ({String name, String type}) _parseScaleName(String value) {
    for (final type in DefaultScaleCatalog.types) {
      if (value.toLowerCase().endsWith(' ${type.toLowerCase()}')) {
        return (
          name: value.substring(0, value.length - type.length).trim(),
          type: type,
        );
      }
    }
    return (name: value, type: 'Custom');
  }

  static ({String name, String type}) _parseChordName(String value) {
    final trimmed = value.trim();
    for (final type in DefaultChordCatalog.types) {
      if (trimmed.toLowerCase().endsWith(' ${type.toLowerCase()}')) {
        return (
          name: trimmed.substring(0, trimmed.length - type.length).trim(),
          type: type,
        );
      }
    }
    return (name: trimmed, type: 'Custom');
  }

  static Future<void> _insertQuarterTone(
    Transaction txn,
    int songId,
    String value,
  ) async {
    await txn.insert('quarter_tones', {'songId': songId, 'value': value});
  }

  static Future<void> _insertSongTag(
    Transaction txn,
    int songId,
    int tagId,
  ) async {
    await txn.insert('song_tags', {'songId': songId, 'tagId': tagId});
  }

  static Future<void> _insertRhythmItem(
    Transaction txn,
    int songId,
    List<int> rhythmIds,
    int position, {
    int? bpm,
  }) async {
    final itemId = await txn.insert('song_rhythm_items', {
      'songId': songId,
      'position': position,
      'bpm': bpm,
    });
    for (var index = 0; index < rhythmIds.length; index++) {
      await txn.insert('song_rhythm_item_rhythms', {
        'itemId': itemId,
        'rhythmId': rhythmIds[index],
        'position': index,
      });
    }
  }

  static const _sharpChromatic = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const _flatChromatic = <String>[
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];
}
