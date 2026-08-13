import 'chord_tutorial.dart';
import 'media_item.dart';

class SongChordItem {
  const SongChordItem({
    this.id,
    this.songId,
    this.position = 0,
    this.chords = const [],
    this.images = const [],
  });

  final int? id;
  final int? songId;
  final int position;
  final List<SongChordSelection> chords;
  final List<MediaItem> images;

  bool get isEmpty => chords.isEmpty && images.isEmpty;

  String get summary {
    final chordSummary = chords
        .map((selection) => selection.displayName)
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final imageCount = images.where((image) => image.hasSource).length;
    if (chordSummary.isNotEmpty && imageCount > 0) {
      return '$chordSummary - $imageCount image(s)';
    }
    if (chordSummary.isNotEmpty) {
      return chordSummary;
    }
    if (imageCount > 0) {
      return '$imageCount image(s)';
    }
    return '';
  }

  SongChordItem copyWith({
    int? id,
    int? songId,
    int? position,
    List<SongChordSelection>? chords,
    List<MediaItem>? images,
  }) {
    return SongChordItem(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      chords: chords ?? this.chords,
      images: images ?? this.images,
    );
  }
}

class SongChordSelection {
  const SongChordSelection({
    required this.chord,
    this.inversionIndex,
  });

  final ChordTutorial chord;
  final int? inversionIndex;

  bool get isRoot => inversionIndex == null;

  ChordInversion? get inversion {
    final index = inversionIndex;
    if (index == null || index < 0 || index >= chord.inversions.length) {
      return null;
    }
    return chord.inversions[index];
  }

  String get displayName {
    final selectedInversion = inversion;
    if (selectedInversion == null) {
      return chord.displayName;
    }
    return '${chord.displayName} - ${selectedInversion.name}';
  }

  String get keys {
    return inversion?.keys ?? chord.keys;
  }

  String? get imagePath {
    return inversion?.imagePath ?? chord.imagePath;
  }

  SongChordSelection copyWith({
    ChordTutorial? chord,
    int? inversionIndex,
    bool clearInversion = false,
  }) {
    return SongChordSelection(
      chord: chord ?? this.chord,
      inversionIndex:
          clearInversion ? null : inversionIndex ?? this.inversionIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SongChordSelection &&
        other.chord == chord &&
        other.inversionIndex == inversionIndex;
  }

  @override
  int get hashCode => Object.hash(chord, inversionIndex);
}
