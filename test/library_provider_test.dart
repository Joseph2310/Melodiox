import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/core/constants/media_types.dart';
import 'package:personal_hymns_library/domain/entities/chord_tutorial.dart';
import 'package:personal_hymns_library/domain/entities/circle_tutorial.dart';
import 'package:personal_hymns_library/domain/entities/general_note.dart';
import 'package:personal_hymns_library/domain/entities/media_item.dart';
import 'package:personal_hymns_library/domain/entities/musical_scale.dart';
import 'package:personal_hymns_library/domain/entities/playlist.dart';
import 'package:personal_hymns_library/domain/entities/rhythm.dart';
import 'package:personal_hymns_library/domain/entities/rhythm_item.dart';
import 'package:personal_hymns_library/domain/entities/song.dart';
import 'package:personal_hymns_library/domain/entities/song_filter.dart';
import 'package:personal_hymns_library/domain/entities/song_sort.dart';
import 'package:personal_hymns_library/domain/entities/tag.dart';
import 'package:personal_hymns_library/domain/repositories/chord_tutorial_repository.dart';
import 'package:personal_hymns_library/domain/repositories/circle_tutorial_repository.dart';
import 'package:personal_hymns_library/domain/repositories/general_note_repository.dart';
import 'package:personal_hymns_library/domain/repositories/musical_scale_repository.dart';
import 'package:personal_hymns_library/domain/repositories/playlist_repository.dart';
import 'package:personal_hymns_library/domain/repositories/rhythm_repository.dart';
import 'package:personal_hymns_library/domain/repositories/song_repository.dart';
import 'package:personal_hymns_library/domain/repositories/tag_repository.dart';
import 'package:personal_hymns_library/presentation/providers/library_provider.dart';

void main() {
  test('search matches partial tokens across song fields', () async {
    final provider = _buildProvider();

    await provider.load();
    provider.setSearchQuery('ama gr');

    expect(provider.visibleSongs.map((song) => song.name), ['Amazing Grace']);
  });

  test('search matches linked chord tutorials', () async {
    final provider = _buildProvider();

    await provider.load();
    provider.setSearchQuery('c maj');

    expect(provider.visibleSongs.map((song) => song.name), ['Amazing Grace']);
  });

  test('main search keeps filters and pauses active sorting', () async {
    final provider = _buildProvider();

    await provider.load();
    provider.setSort(
      const SongSort(direction: SortDirection.descending),
    );
    expect(provider.visibleSongs.map((song) => song.name), [
      'Holy, Holy, Holy',
      'Amazing Grace',
    ]);
    provider.setSearchQuery('h');
    expect(provider.visibleSongs.map((song) => song.name), [
      'Amazing Grace',
      'Holy, Holy, Holy',
    ]);

    provider.setFilter(const SongFilter(completed: true));

    expect(provider.visibleSongs.map((song) => song.name), [
      'Amazing Grace',
    ]);
  });

  test('filters favorites and toggles favorite state', () async {
    final songRepository = _FakeSongRepository();
    final provider = _buildProvider(songRepository: songRepository);

    await provider.load();
    provider.setFilter(const SongFilter(favoriteOnly: true));

    expect(provider.visibleSongs.map((song) => song.name), ['Amazing Grace']);

    await provider.toggleFavorite(provider.songs.last);

    expect(
      provider.visibleSongs.map((song) => song.name).toSet(),
      {'Amazing Grace', 'Holy, Holy, Holy'},
    );
  });

  test('filters ready and not ready songs', () async {
    final provider = _buildProvider();

    await provider.load();
    provider.setFilter(const SongFilter(completed: true));

    expect(provider.visibleSongs.map((song) => song.name), ['Amazing Grace']);

    provider.setFilter(const SongFilter(completed: false));

    expect(
        provider.visibleSongs.map((song) => song.name), ['Holy, Holy, Holy']);
  });

  test('filters bpm from rhythm items', () async {
    final provider = _buildProvider();

    await provider.load();
    provider.setFilter(const SongFilter(minBpm: 80, maxBpm: 90));

    expect(provider.visibleSongs.map((song) => song.name), ['Amazing Grace']);
  });
}

LibraryProvider _buildProvider({_FakeSongRepository? songRepository}) {
  return LibraryProvider(
    songRepository: songRepository ?? _FakeSongRepository(),
    tagRepository: _FakeTagRepository(),
    playlistRepository: _FakePlaylistRepository(),
    rhythmRepository: _FakeRhythmRepository(),
    chordTutorialRepository: _FakeChordTutorialRepository(),
    circleTutorialRepository: _FakeCircleTutorialRepository(),
    generalNoteRepository: _FakeGeneralNoteRepository(),
    musicalScaleRepository: _FakeMusicalScaleRepository(),
  );
}

class _FakeSongRepository implements SongRepository {
  final _songs = <Song>[
    Song(
      id: 1,
      name: 'Amazing Grace',
      myStartingKey: 'G',
      transposeValue: 0,
      lyrics: 'Amazing grace, how sweet the sound.',
      notes: 'Slow intro',
      primaryRhythm: '3/4 Hymn',
      tags: const [Tag(id: 1, name: 'Worship')],
      favorite: true,
      completed: true,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      quarterTones: const ['None'],
      rhythmItems: const [
        RhythmItem(
          bpm: 82,
          rhythms: [Rhythm(id: 1, rhythmName: '3/4 Hymn', isPrimary: true)],
        ),
      ],
      chordTutorials: [_cMajorChord],
      media: const [
        MediaItem(
          mediaType: MediaType.songAudio,
          title: 'Guide',
          localPath: '/tmp/guide.mp3',
        ),
      ],
    ),
    Song(
      id: 2,
      name: 'Holy, Holy, Holy',
      myStartingKey: 'D',
      transposeValue: -2,
      notes: 'Use soft dynamics',
      primaryRhythm: '4/4 Ballad',
      tags: const [Tag(id: 2, name: 'Rehearsal')],
      createdAt: DateTime(2024, 2),
      updatedAt: DateTime(2024, 2),
      quarterTones: const [],
      rhythmItems: const [
        RhythmItem(
          bpm: 72,
          rhythms: [Rhythm(id: 2, rhythmName: '4/4 Ballad', isPrimary: true)],
        ),
      ],
    ),
  ];

  @override
  Future<void> deleteSong(int id) async {
    _songs.removeWhere((song) => song.id == id);
  }

  @override
  Future<Song?> getSong(int id) async {
    for (final song in _songs) {
      if (song.id == id) {
        return song;
      }
    }
    return null;
  }

  @override
  Future<List<Song>> getSongs() async {
    return [..._songs];
  }

  @override
  Future<int> saveSong(Song song) async {
    final id = song.id ?? (_songs.length + 1);
    _songs.removeWhere((existing) => existing.id == id);
    _songs.add(song.copyWith(id: id));
    return id;
  }

  @override
  Future<void> reorderSongs(List<int> songIds) async {
    final byId = {for (final song in _songs) song.id: song};
    _songs
      ..clear()
      ..addAll([
        for (var index = 0; index < songIds.length; index++)
          if (byId[songIds[index]] != null)
            byId[songIds[index]]!.copyWith(position: index),
      ]);
  }

  @override
  Future<void> toggleFavorite(int id, bool favorite) async {
    final index = _songs.indexWhere((song) => song.id == id);
    _songs[index] = _songs[index].copyWith(favorite: favorite);
  }

  @override
  Future<void> setCompleted(int id, bool completed) async {
    final index = _songs.indexWhere((song) => song.id == id);
    _songs[index] = _songs[index].copyWith(completed: completed);
  }
}

class _FakeTagRepository implements TagRepository {
  final _tags = const [
    Tag(id: 1, name: 'Worship'),
    Tag(id: 2, name: 'Rehearsal'),
  ];

  @override
  Future<void> deleteTag(int id) async {}

  @override
  Future<List<Tag>> getTags() async => [..._tags];

  @override
  Future<int> saveTag(Tag tag) async => tag.id ?? 1;
}

class _FakePlaylistRepository implements PlaylistRepository {
  @override
  Future<void> addSong(int playlistId, int songId) async {}

  @override
  Future<void> deletePlaylist(int id) async {}

  @override
  Future<List<Playlist>> getPlaylists() async => const [];

  @override
  Future<void> removeSong(int playlistId, int songId) async {}

  @override
  Future<void> reorderSongs(int playlistId, List<int> orderedSongIds) async {}

  @override
  Future<int> savePlaylist(Playlist playlist) async => playlist.id ?? 1;
}

class _FakeRhythmRepository implements RhythmRepository {
  final _rhythms = const [
    Rhythm(id: 1, rhythmName: '3/4 Hymn', section: 'Annual'),
    Rhythm(id: 2, rhythmName: '4/4 Ballad', section: 'Annual'),
  ];

  @override
  Future<void> deleteRhythm(int id) async {}

  @override
  Future<List<Rhythm>> getRhythms() async => [..._rhythms];

  @override
  Future<int> saveRhythm(Rhythm rhythm) async => rhythm.id ?? 1;
}

class _FakeChordTutorialRepository implements ChordTutorialRepository {
  @override
  Future<void> deleteChordTutorial(int id) async {}

  @override
  Future<List<ChordTutorial>> getChordTutorials() async => [_cMajorChord];

  @override
  Future<int> saveChordTutorial(ChordTutorial tutorial) async =>
      tutorial.id ?? 1;
}

final _cMajorChord = ChordTutorial(
  id: 1,
  name: 'C',
  type: 'Major',
  keys: 'C, E, G',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

class _FakeCircleTutorialRepository implements CircleTutorialRepository {
  @override
  Future<void> deleteCircleTutorial(int id) async {}

  @override
  Future<List<CircleTutorial>> getCircleTutorials() async => const [];

  @override
  Future<int> saveCircleTutorial(CircleTutorial tutorial) async =>
      tutorial.id ?? 1;
}

class _FakeGeneralNoteRepository implements GeneralNoteRepository {
  @override
  Future<void> deleteNote(int id) async {}

  @override
  Future<List<GeneralNote>> getNotes() async => const [];

  @override
  Future<int> saveNote(GeneralNote note) async => note.id ?? 1;
}

class _FakeMusicalScaleRepository implements MusicalScaleRepository {
  @override
  Future<void> deleteScale(int id) async {}

  @override
  Future<List<MusicalScale>> getScales() async => [
        MusicalScale(
          id: 1,
          name: 'C',
          type: 'Major',
          keys: 'C, D, E, F, G, A, B, C',
          formula: '1, 1, 1/2, 1, 1, 1, 1/2',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        MusicalScale(
          id: 2,
          name: 'C',
          type: 'Minor',
          keys: 'C, D, Eb, F, G, Ab, Bb, C',
          formula: '1, 1/2, 1, 1, 1/2, 1, 1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

  @override
  Future<int> saveScale(MusicalScale scale) async => scale.id ?? 1;
}
