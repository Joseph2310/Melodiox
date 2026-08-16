import 'package:flutter/foundation.dart';

import '../../core/constants/media_types.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/circle_tutorial.dart';
import '../../domain/entities/general_note.dart';
import '../../domain/entities/musical_scale.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/rhythm.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_filter.dart';
import '../../domain/entities/song_sort.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/chord_tutorial_repository.dart';
import '../../domain/repositories/circle_tutorial_repository.dart';
import '../../domain/repositories/general_note_repository.dart';
import '../../domain/repositories/musical_scale_repository.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/repositories/rhythm_repository.dart';
import '../../domain/repositories/song_repository.dart';
import '../../domain/repositories/tag_repository.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider({
    required SongRepository songRepository,
    required TagRepository tagRepository,
    required PlaylistRepository playlistRepository,
    required RhythmRepository rhythmRepository,
    required ChordTutorialRepository chordTutorialRepository,
    required CircleTutorialRepository circleTutorialRepository,
    required GeneralNoteRepository generalNoteRepository,
    required MusicalScaleRepository musicalScaleRepository,
  })  : _songRepository = songRepository,
        _tagRepository = tagRepository,
        _playlistRepository = playlistRepository,
        _rhythmRepository = rhythmRepository,
        _chordTutorialRepository = chordTutorialRepository,
        _circleTutorialRepository = circleTutorialRepository,
        _generalNoteRepository = generalNoteRepository,
        _musicalScaleRepository = musicalScaleRepository;

  final SongRepository _songRepository;
  final TagRepository _tagRepository;
  final PlaylistRepository _playlistRepository;
  final RhythmRepository _rhythmRepository;
  final ChordTutorialRepository _chordTutorialRepository;
  final CircleTutorialRepository _circleTutorialRepository;
  final GeneralNoteRepository _generalNoteRepository;
  final MusicalScaleRepository _musicalScaleRepository;

  List<Song> _songs = [];
  List<Tag> _tags = [];
  List<Playlist> _playlists = [];
  List<Rhythm> _rhythms = [];
  List<ChordTutorial> _chordTutorials = [];
  List<CircleTutorial> _circleTutorials = [];
  List<GeneralNote> _notes = [];
  List<MusicalScale> _scales = [];
  String _searchQuery = '';
  SongFilter _filter = const SongFilter();
  SongSort _sort = const SongSort();
  bool _isLoading = false;
  String? _errorMessage;

  List<Song> get songs => List.unmodifiable(_songs);
  List<Tag> get tags => List.unmodifiable(_tags);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Rhythm> get rhythms => List.unmodifiable(_rhythms);
  List<ChordTutorial> get chordTutorials => List.unmodifiable(_chordTutorials);
  List<CircleTutorial> get circleTutorials =>
      List.unmodifiable(_circleTutorials);
  List<GeneralNote> get notes => List.unmodifiable(_notes);
  List<MusicalScale> get scales => List.unmodifiable(_scales);
  String get searchQuery => _searchQuery;
  SongFilter get filter => _filter;
  SongSort get sort => _sort;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Song> get visibleSongs => _deriveSongs();
  List<Song> get favoriteSongs => _deriveSongs(forceFavorites: true);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _refreshData();
    } catch (error) {
      _errorMessage = 'Unable to load library: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Song? songById(int id) {
    for (final song in _songs) {
      if (song.id == id) {
        return song;
      }
    }
    return null;
  }

  List<Song> songsForPlaylist(Playlist playlist) {
    final byId = {for (final song in _songs) song.id: song};
    return playlist.songIds
        .map((songId) => byId[songId])
        .whereType<Song>()
        .toList();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilter(SongFilter value) {
    _filter = value;
    notifyListeners();
  }

  void clearFilters({bool keepFavoritesOnly = false}) {
    _filter = SongFilter(favoriteOnly: keepFavoritesOnly);
    notifyListeners();
  }

  void setSort(SongSort value) {
    _sort = value;
    notifyListeners();
  }

  Future<bool> saveSong(Song song) {
    return _mutate(() => _songRepository.saveSong(song));
  }

  Future<bool> deleteSong(int id) {
    return _mutate(() => _songRepository.deleteSong(id));
  }

  Future<bool> toggleFavorite(Song song) async {
    final id = song.id;
    if (id == null) {
      return false;
    }
    return _mutate(() => _songRepository.toggleFavorite(id, !song.favorite));
  }

  Future<bool> setSongCompleted(Song song, bool completed) async {
    final id = song.id;
    if (id == null) {
      return false;
    }
    return _mutate(() => _songRepository.setCompleted(id, completed));
  }

  Future<bool> saveTag(Tag tag) {
    return _mutate(() => _tagRepository.saveTag(tag));
  }

  Future<bool> deleteTag(int id) {
    return _mutate(() => _tagRepository.deleteTag(id));
  }

  Future<bool> saveRhythm(Rhythm rhythm) {
    return _mutate(() => _rhythmRepository.saveRhythm(rhythm));
  }

  Future<bool> deleteRhythm(int id) {
    return _mutate(() => _rhythmRepository.deleteRhythm(id));
  }

  Future<bool> saveChordTutorial(ChordTutorial tutorial) {
    return _mutate(
      () => _chordTutorialRepository.saveChordTutorial(tutorial),
    );
  }

  Future<bool> deleteChordTutorial(int id) {
    return _mutate(() => _chordTutorialRepository.deleteChordTutorial(id));
  }

  Future<bool> saveCircleTutorial(CircleTutorial tutorial) {
    return _mutate(
      () => _circleTutorialRepository.saveCircleTutorial(tutorial),
    );
  }

  Future<bool> deleteCircleTutorial(int id) {
    return _mutate(() => _circleTutorialRepository.deleteCircleTutorial(id));
  }

  Future<bool> saveNote(GeneralNote note) {
    return _mutate(() => _generalNoteRepository.saveNote(note));
  }

  Future<bool> deleteNote(int id) {
    return _mutate(() => _generalNoteRepository.deleteNote(id));
  }

  Future<bool> saveScale(MusicalScale scale) {
    return _mutate(() => _musicalScaleRepository.saveScale(scale));
  }

  Future<bool> deleteScale(int id) {
    return _mutate(() => _musicalScaleRepository.deleteScale(id));
  }

  Future<bool> savePlaylist(Playlist playlist) {
    return _mutate(() => _playlistRepository.savePlaylist(playlist));
  }

  Future<bool> deletePlaylist(int id) {
    return _mutate(() => _playlistRepository.deletePlaylist(id));
  }

  Future<bool> addSongToPlaylist(int playlistId, int songId) {
    return _mutate(() => _playlistRepository.addSong(playlistId, songId));
  }

  Future<bool> removeSongFromPlaylist(int playlistId, int songId) {
    return _mutate(() => _playlistRepository.removeSong(playlistId, songId));
  }

  Future<bool> reorderSongs(List<Song> songs, int oldIndex, int newIndex) {
    final reordered = [...songs];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    final ids = reordered.map((song) => song.id).whereType<int>().toList();
    return _mutate(() => _songRepository.reorderSongs(ids));
  }

  Future<bool> reorderPlaylist(Playlist playlist, int oldIndex, int newIndex) {
    final ids = [...playlist.songIds];
    final moved = ids.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, ids.length).toInt();
    ids.insert(targetIndex, moved);
    return _mutate(() => _playlistRepository.reorderSongs(playlist.id!, ids));
  }

  Future<void> _refreshData() async {
    final results = await Future.wait([
      _songRepository.getSongs(),
      _tagRepository.getTags(),
      _playlistRepository.getPlaylists(),
      _rhythmRepository.getRhythms(),
      _chordTutorialRepository.getChordTutorials(),
      _circleTutorialRepository.getCircleTutorials(),
      _generalNoteRepository.getNotes(),
      _musicalScaleRepository.getScales(),
    ]);
    _songs = results[0] as List<Song>;
    _tags = results[1] as List<Tag>;
    _playlists = results[2] as List<Playlist>;
    _rhythms = results[3] as List<Rhythm>;
    _chordTutorials = results[4] as List<ChordTutorial>;
    _circleTutorials = results[5] as List<CircleTutorial>;
    _notes = results[6] as List<GeneralNote>;
    _scales = results[7] as List<MusicalScale>;
  }

  Future<bool> _mutate(Future<Object?> Function() action) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      await _refreshData();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  List<Song> _deriveSongs({bool forceFavorites = false}) {
    final searching = _searchQuery.trim().isNotEmpty;
    final filter =
        forceFavorites ? _filter.copyWith(favoriteOnly: true) : _filter;
    final searched = _songs.where((song) => _matchesSearch(song, _searchQuery));
    final filtered =
        searched.where((song) => _matchesFilter(song, filter)).toList();
    if (!searching) {
      filtered.sort(_compareSongs);
    }
    return filtered;
  }

  bool _matchesSearch(Song song, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final haystack = _normalize(
      [
        song.name,
        song.myStartingKey,
        song.originalStartingKey ?? '',
        song.originalScale ?? '',
        song.myScale ?? '',
        song.lyrics ?? '',
        song.notesSummary,
        song.rhythmSummary,
        song.linkedChordSummary,
        ...song.bpmValues.map((value) => '$value BPM'),
        ...song.tags.map((tag) => tag.name),
        song.quarterToneSummary,
        for (final item in song.rhythmItems)
          ...item.rhythms.map((rhythm) => rhythm.rhythmName),
        ...song.chordTutorials.map((chord) => chord.keys),
        for (final item in song.chordItems)
          ...item.chords.map((selection) => selection.keys),
      ].join(' '),
    );
    final words = haystack
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return tokens.every((token) {
      if (haystack.contains(token)) {
        return true;
      }
      return words.any(
        (word) => word.startsWith(token) || _isSubsequence(token, word),
      );
    });
  }

  bool _matchesFilter(Song song, SongFilter filter) {
    if (filter.favoriteOnly && !song.favorite) {
      return false;
    }
    if (filter.tagIds.isNotEmpty &&
        !song.tags
            .any((tag) => tag.id != null && filter.tagIds.contains(tag.id))) {
      return false;
    }
    if (filter.myKey != null && song.myStartingKey != filter.myKey) {
      return false;
    }
    if (filter.originalKey != null &&
        song.originalStartingKey != filter.originalKey) {
      return false;
    }
    if (filter.scale != null &&
        song.originalScale != filter.scale &&
        song.myScale != filter.scale) {
      return false;
    }
    if (filter.scaleType != null &&
        !_songUsesScaleType(song, filter.scaleType!)) {
      return false;
    }
    if (filter.rhythm != null &&
        !song.rhythmItems.any(
          (item) => item.rhythms.any(
            (rhythm) => rhythm.rhythmName == filter.rhythm,
          ),
        ) &&
        song.primaryRhythm != filter.rhythm) {
      return false;
    }
    if ((filter.minBpm != null || filter.maxBpm != null) &&
        !song.bpmValues.any((value) {
          return (filter.minBpm == null || value >= filter.minBpm!) &&
              (filter.maxBpm == null || value <= filter.maxBpm!);
        })) {
      return false;
    }
    if (filter.transposeValue != null &&
        song.transposeValue != filter.transposeValue) {
      return false;
    }
    if (filter.quarterTone != null &&
        !song.quarterTones.contains(filter.quarterTone)) {
      return false;
    }
    if (filter.completed != null && song.completed != filter.completed) {
      return false;
    }
    if (!_matchesPresence(filter.hasLyrics, song.hasLyrics)) {
      return false;
    }
    if (!_matchesPresence(filter.hasNotes, song.hasNotes)) {
      return false;
    }
    if (!_matchesPresence(
      filter.hasChordImages,
      song.linkedChordSummary.isNotEmpty ||
          song.chordImages.any((media) => media.hasSource),
    )) {
      return false;
    }
    if (!_matchesPresence(
      filter.hasVideo,
      _hasMedia(song, MediaType.performanceVideo),
    )) {
      return false;
    }
    if (!_matchesPresence(
      filter.hasAudio,
      _hasMedia(song, MediaType.songAudio) ||
          _hasMedia(song, MediaType.vocalAudio),
    )) {
      return false;
    }
    return true;
  }

  bool _songUsesScaleType(Song song, String scaleType) {
    return _scaleValueHasType(song.originalScale, scaleType) ||
        _scaleValueHasType(song.myScale, scaleType);
  }

  bool _scaleValueHasType(String? value, String scaleType) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }
    final normalizedValue = value.trim().toLowerCase();
    final normalizedType = scaleType.trim().toLowerCase();
    for (final scale in _scales) {
      if (scale.displayName.toLowerCase() == normalizedValue) {
        return scale.type.trim().toLowerCase() == normalizedType;
      }
    }
    return normalizedValue.endsWith(' $normalizedType');
  }

  bool _matchesPresence(bool? expected, bool actual) {
    return expected == null || expected == actual;
  }

  bool _hasMedia(Song song, MediaType type) {
    return song.media.any(
      (media) => media.mediaType == type && media.hasSource,
    );
  }

  int _compareSongs(Song a, Song b) {
    final direction = _sort.direction == SortDirection.ascending ? 1 : -1;
    final comparison = switch (_sort.field) {
      SongSortField.manual => a.position.compareTo(b.position),
      SongSortField.alphabetical => _compareText(a.name, b.name),
      SongSortField.newest => b.createdAt.compareTo(a.createdAt),
      SongSortField.oldest => a.createdAt.compareTo(b.createdAt),
      SongSortField.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
      SongSortField.favoriteFirst => _compareFavorite(a, b),
      SongSortField.rhythm => _compareText(a.rhythmSummary, b.rhythmSummary),
      SongSortField.key => _compareText(a.myStartingKey, b.myStartingKey),
      SongSortField.bpm => (a.primaryBpm ?? 0).compareTo(b.primaryBpm ?? 0),
      SongSortField.tag => _compareText(
          a.tags.map((tag) => tag.name).join(', '),
          b.tags.map((tag) => tag.name).join(', '),
        ),
    };
    if (_sort.field == SongSortField.manual) {
      return comparison == 0 ? _compareText(a.name, b.name) : comparison;
    }
    final resolved =
        comparison == 0 ? _compareText(a.name, b.name) : comparison;
    return resolved * direction;
  }

  int _compareFavorite(Song a, Song b) {
    if (a.favorite == b.favorite) {
      return _compareText(a.name, b.name);
    }
    return a.favorite ? -1 : 1;
  }

  int _compareText(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  bool _isSubsequence(String token, String word) {
    if (token.length < 3 || word.length < 3) {
      return false;
    }
    var tokenIndex = 0;
    for (final codeUnit in word.codeUnits) {
      if (token.codeUnitAt(tokenIndex) == codeUnit) {
        tokenIndex++;
        if (tokenIndex == token.length) {
          return true;
        }
      }
    }
    return false;
  }
}
