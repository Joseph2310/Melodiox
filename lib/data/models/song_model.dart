import '../../domain/entities/media_item.dart';
import '../../domain/entities/rhythm_item.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/tag.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/song_chord_item.dart';
import '../../domain/entities/tutorial_detail.dart';

class SongModel {
  const SongModel._();

  static Song fromMap(
    Map<String, Object?> map, {
    List<String> quarterTones = const [],
    List<RhythmItem> rhythmItems = const [],
    List<ChordTutorial> chordTutorials = const [],
    List<MediaItem> media = const [],
    List<Tag> tags = const [],
    List<SongChordItem> chordItems = const [],
    List<TutorialNote> noteItems = const [],
  }) {
    return Song(
      id: map['id'] as int?,
      name: map['name'] as String,
      myStartingKey: map['myStartingKey'] as String,
      transposeValue: map['transposeValue'] as int? ?? 0,
      originalScale: map['originalScale'] as String?,
      myScale: map['myScale'] as String?,
      originalStartingKey: map['originalStartingKey'] as String?,
      bpm: map['bpm'] as int?,
      lyrics: map['lyrics'] as String?,
      notes: map['notes'] as String?,
      primaryRhythm: map['primaryRhythm'] as String?,
      position: map['position'] as int? ?? 0,
      completed: (map['completed'] as int? ?? 0) == 1,
      tags: tags,
      favorite: (map['favorite'] as int? ?? 0) == 1,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      quarterTones: quarterTones,
      rhythmItems: rhythmItems,
      chordTutorials: chordTutorials,
      chordItems: chordItems,
      noteItems: noteItems,
      media: media,
    );
  }

  static Map<String, Object?> toMap(Song song) {
    return {
      'id': song.id,
      'name': song.name.trim(),
      'myStartingKey': song.myStartingKey.trim(),
      'transposeValue': song.transposeValue,
      'originalScale': _blankToNull(song.originalScale),
      'myScale': _blankToNull(song.myScale),
      'originalStartingKey': _blankToNull(song.originalStartingKey),
      'bpm': song.primaryBpm,
      'lyrics': _blankToNull(song.lyrics),
      'notes': _blankToNull(song.notes),
      'primaryRhythm': _blankToNull(song.primaryRhythm),
      'position': song.position,
      'completed': song.completed ? 1 : 0,
      'favorite': song.favorite ? 1 : 0,
      'createdAt': song.createdAt.toIso8601String(),
      'updatedAt': song.updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
