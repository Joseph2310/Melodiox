import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/database/database_provider.dart';
import 'data/repositories/sqlite_chord_tutorial_repository.dart';
import 'data/repositories/sqlite_circle_tutorial_repository.dart';
import 'data/repositories/sqlite_general_note_repository.dart';
import 'data/repositories/sqlite_lyrics_library_repository.dart';
import 'data/repositories/sqlite_musical_scale_repository.dart';
import 'data/repositories/sqlite_playlist_repository.dart';
import 'data/repositories/sqlite_rhythm_repository.dart';
import 'data/repositories/sqlite_song_repository.dart';
import 'data/repositories/sqlite_tag_repository.dart';
import 'domain/repositories/lyrics_library_repository.dart';
import 'presentation/providers/library_provider.dart';
import 'presentation/providers/audio_player_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseProvider = DatabaseProvider();
  final songRepository = SqliteSongRepository(databaseProvider);
  final tagRepository = SqliteTagRepository(databaseProvider);
  final playlistRepository = SqlitePlaylistRepository(databaseProvider);
  final rhythmRepository = SqliteRhythmRepository(databaseProvider);
  final chordTutorialRepository = SqliteChordTutorialRepository(
    databaseProvider,
  );
  final circleTutorialRepository = SqliteCircleTutorialRepository(
    databaseProvider,
  );
  final generalNoteRepository = SqliteGeneralNoteRepository(databaseProvider);
  final musicalScaleRepository = SqliteMusicalScaleRepository(databaseProvider);
  final lyricsLibraryRepository = SqliteLyricsLibraryRepository(
    databaseProvider,
  );
  await lyricsLibraryRepository.ensureSeeded();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseProvider>.value(value: databaseProvider),
        Provider<LyricsLibraryRepository>.value(
          value: lyricsLibraryRepository,
        ),
        Provider<BackupService>(create: (_) => BackupService(databaseProvider)),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(
            songRepository: songRepository,
            tagRepository: tagRepository,
            playlistRepository: playlistRepository,
            rhythmRepository: rhythmRepository,
            chordTutorialRepository: chordTutorialRepository,
            circleTutorialRepository: circleTutorialRepository,
            generalNoteRepository: generalNoteRepository,
            musicalScaleRepository: musicalScaleRepository,
          )..load(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ],
      child: const PersonalHymnsApp(),
    ),
  );
}
