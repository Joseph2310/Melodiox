import '../../domain/entities/chord_tutorial.dart';

class RelativeChords {
  const RelativeChords._();

  static RelativeChord? findFor(
    ChordTutorial source,
    List<ChordTutorial> catalog,
  ) {
    final savedRelative = _savedRelativeChord(source, catalog);
    if (savedRelative == null) {
      return null;
    }
    final relation = _relationForType(source.type);
    final label = relation != null && savedRelative.type == relation.targetType
        ? relation.label
        : 'Relative chord';
    return RelativeChord(chord: savedRelative, label: label);
  }

  static String? targetTypeFor(String sourceType) {
    return _relationForType(sourceType)?.targetType;
  }

  static List<String> targetRootNamesFor(String sourceRoot, String sourceType) {
    final rootIndex = _noteIndex(sourceRoot);
    final relation = _relationForType(sourceType);
    if (rootIndex == null || relation == null) {
      return const [];
    }
    return _relativeRootNames(
      sourceRoot,
      rootIndex,
      relation.semitoneDelta,
      relation.label,
    );
  }

  static ChordTutorial? _savedRelativeChord(
    ChordTutorial source,
    List<ChordTutorial> catalog,
  ) {
    final id = source.relativeChordId;
    if (id == null) {
      return null;
    }
    for (final chord in catalog) {
      if (chord.id == id) {
        return chord;
      }
    }
    return null;
  }

  static _RelativeRelation? _relationForType(String type) {
    return switch (type) {
      'Major' => const _RelativeRelation(
          label: 'Relative minor',
          targetType: 'Minor',
          semitoneDelta: -3,
        ),
      'Major 7' => const _RelativeRelation(
          label: 'Relative minor',
          targetType: 'Minor 7',
          semitoneDelta: -3,
        ),
      'Minor' => const _RelativeRelation(
          label: 'Relative major',
          targetType: 'Major',
          semitoneDelta: 3,
        ),
      'Minor 7' => const _RelativeRelation(
          label: 'Relative major',
          targetType: 'Major 7',
          semitoneDelta: 3,
        ),
      _ => null,
    };
  }

  static List<String> _relativeRootNames(
    String sourceRoot,
    int sourceIndex,
    int semitoneDelta,
    String relationLabel,
  ) {
    final targetIndex = (sourceIndex + semitoneDelta) % 12;
    final primaryChromatic = _chromaticFor(sourceRoot, relationLabel);
    final primary = primaryChromatic[targetIndex];
    final alternateChromatic = identical(primaryChromatic, _sharpChromatic)
        ? _flatChromatic
        : _sharpChromatic;
    final alternate = alternateChromatic[targetIndex];
    return primary == alternate ? [primary] : [primary, alternate];
  }

  static List<String> _chromaticFor(String sourceRoot, String relationLabel) {
    if (sourceRoot.contains('#')) {
      return _sharpChromatic;
    }
    if (sourceRoot.contains('b')) {
      return _flatChromatic;
    }
    return relationLabel == 'Relative major' ? _flatChromatic : _sharpChromatic;
  }

  static int? _noteIndex(String note) {
    return switch (note.trim()) {
      'C' => 0,
      'C#' || 'Db' => 1,
      'D' => 2,
      'D#' || 'Eb' => 3,
      'E' => 4,
      'F' => 5,
      'F#' || 'Gb' => 6,
      'G' => 7,
      'G#' || 'Ab' => 8,
      'A' => 9,
      'A#' || 'Bb' => 10,
      'B' => 11,
      _ => null,
    };
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

class RelativeChord {
  const RelativeChord({required this.chord, required this.label});

  final ChordTutorial chord;
  final String label;
}

class _RelativeRelation {
  const _RelativeRelation({
    required this.label,
    required this.targetType,
    required this.semitoneDelta,
  });

  final String label;
  final String targetType;
  final int semitoneDelta;
}
