import '../../core/constants/media_types.dart';
import 'chord_tutorial.dart';
import 'media_item.dart';
import 'rhythm_item.dart';
import 'song_chord_item.dart';
import 'tag.dart';
import 'tutorial_detail.dart';

class Song {
  const Song({
    this.id,
    required this.name,
    required this.myStartingKey,
    required this.transposeValue,
    this.originalScale,
    this.myScale,
    this.originalStartingKey,
    this.bpm,
    this.lyrics,
    this.notes,
    this.primaryRhythm,
    this.position = 0,
    this.completed = false,
    this.tags = const [],
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.quarterTones = const [],
    this.rhythmItems = const [],
    this.chordTutorials = const [],
    this.chordItems = const [],
    this.noteItems = const [],
    this.media = const [],
  });

  final int? id;
  final String name;
  final String myStartingKey;
  final int transposeValue;
  final String? originalScale;
  final String? myScale;
  final String? originalStartingKey;
  final int? bpm;
  final String? lyrics;
  final String? notes;
  final String? primaryRhythm;
  final int position;
  final bool completed;
  final List<Tag> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> quarterTones;
  final List<RhythmItem> rhythmItems;
  final List<ChordTutorial> chordTutorials;
  final List<SongChordItem> chordItems;
  final List<TutorialNote> noteItems;
  final List<MediaItem> media;

  List<String> get activeQuarterTones => quarterTones.where((value) {
        final normalized = value.trim().toLowerCase();
        return normalized.isNotEmpty && normalized != 'none';
      }).toList();

  bool get hasQuarterTones => activeQuarterTones.isNotEmpty;

  String get quarterToneSummary =>
      hasQuarterTones ? activeQuarterTones.join(', ') : 'None';

  String get rhythmSummary {
    if (rhythmItems.isNotEmpty && rhythmItems.first.summary.isNotEmpty) {
      return rhythmItems.first.summary;
    }
    return primaryRhythm?.trim() ?? '';
  }

  String get allRhythmsSummary {
    final summary = rhythmItems
        .map((item) => item.summary)
        .where((value) => value.isNotEmpty)
        .join(', ');
    return summary.isNotEmpty ? summary : primaryRhythm?.trim() ?? '';
  }

  String get linkedChordSummary {
    final selections = chordItems.expand((item) => item.chords);
    if (selections.isNotEmpty) {
      return selections
          .map((selection) => selection.displayName)
          .where((value) => value.trim().isNotEmpty)
          .join(', ');
    }
    return chordTutorials
        .map((chord) => chord.displayName)
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
  }

  String get compactChordSummary {
    final names = chordItems
        .expand((item) => item.chords)
        .map((selection) => selection.displayName)
        .toList();
    if (names.isEmpty) {
      names.addAll(chordTutorials.map((chord) => chord.displayName));
    }
    if (names.isEmpty) {
      return '';
    }
    if (names.length <= 2) {
      return names.join(', ');
    }
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String get notesSummary {
    if (noteItems.isNotEmpty) {
      return noteItems
          .map((note) => [
                if (note.title.trim().isNotEmpty) note.title.trim(),
                note.body.trim(),
              ].where((value) => value.isNotEmpty).join(': '))
          .where((value) => value.trim().isNotEmpty)
          .join('\n');
    }
    return notes?.trim() ?? '';
  }

  List<MediaItem> get chordImages {
    final itemImages = chordItems.expand((item) => item.images).toList();
    if (itemImages.isNotEmpty) {
      return itemImages;
    }
    return media
        .where((item) => item.mediaType == MediaType.chordImage)
        .toList();
  }

  bool get hasLyrics => lyrics != null && lyrics!.trim().isNotEmpty;
  bool get hasNotes => notesSummary.trim().isNotEmpty;

  Song copyWith({
    int? id,
    String? name,
    String? myStartingKey,
    int? transposeValue,
    String? originalScale,
    String? myScale,
    String? originalStartingKey,
    int? bpm,
    String? lyrics,
    String? notes,
    String? primaryRhythm,
    int? position,
    bool? completed,
    List<Tag>? tags,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? quarterTones,
    List<RhythmItem>? rhythmItems,
    List<ChordTutorial>? chordTutorials,
    List<SongChordItem>? chordItems,
    List<TutorialNote>? noteItems,
    List<MediaItem>? media,
    bool clearOriginalScale = false,
    bool clearMyScale = false,
    bool clearOriginalStartingKey = false,
    bool clearBpm = false,
    bool clearLyrics = false,
    bool clearNotes = false,
    bool clearPrimaryRhythm = false,
  }) {
    return Song(
      id: id ?? this.id,
      name: name ?? this.name,
      myStartingKey: myStartingKey ?? this.myStartingKey,
      transposeValue: transposeValue ?? this.transposeValue,
      originalScale:
          clearOriginalScale ? null : originalScale ?? this.originalScale,
      myScale: clearMyScale ? null : myScale ?? this.myScale,
      originalStartingKey: clearOriginalStartingKey
          ? null
          : originalStartingKey ?? this.originalStartingKey,
      bpm: clearBpm ? null : bpm ?? this.bpm,
      lyrics: clearLyrics ? null : lyrics ?? this.lyrics,
      notes: clearNotes ? null : notes ?? this.notes,
      primaryRhythm:
          clearPrimaryRhythm ? null : primaryRhythm ?? this.primaryRhythm,
      position: position ?? this.position,
      completed: completed ?? this.completed,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quarterTones: quarterTones ?? this.quarterTones,
      rhythmItems: rhythmItems ?? this.rhythmItems,
      chordTutorials: chordTutorials ?? this.chordTutorials,
      chordItems: chordItems ?? this.chordItems,
      noteItems: noteItems ?? this.noteItems,
      media: media ?? this.media,
    );
  }
}
