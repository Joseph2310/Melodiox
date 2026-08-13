import 'music_keys.dart';

class DefaultChordCatalog {
  const DefaultChordCatalog._();

  static const types = <String>[
    'Major',
    'Minor',
    'Diminished',
    'Major 7',
    'Minor 7',
    'Diminished 7',
    'Half-diminished 7',
  ];

  static List<DefaultChordDefinition> get definitions {
    return [
      for (final name in MusicKeys.values)
        for (final type in types)
          DefaultChordDefinition(
            name: name,
            type: type,
            keys: _chordNotes(name, type).join(', '),
            imagePath: _imagePath(name, type),
            inversions: _inversions(name, type),
            notes: _chordDescription(type),
          ),
    ];
  }

  static List<String> _chordNotes(String root, String type) {
    final intervals = switch (type) {
      'Half-diminished 7' => const [0, 3, 6, 10],
      'Diminished 7' => const [0, 3, 6, 9],
      'Minor 7' => const [0, 3, 7, 10],
      'Major 7' => const [0, 4, 7, 11],
      'Diminished' => const [0, 3, 6],
      'Minor' => const [0, 3, 7],
      _ => const [0, 4, 7],
    };
    final chromatic =
        _preferFlats(root, type) ? _flatChromatic : _sharpChromatic;
    final rootIndex = chromatic.indexOf(root);
    final effectiveRootIndex =
        rootIndex >= 0 ? rootIndex : _sharpChromatic.indexOf(root);
    return [
      for (final interval in intervals)
        chromatic[(effectiveRootIndex + interval) % chromatic.length],
    ];
  }

  static String _chordDescription(String type) {
    return switch (type) {
      'Half-diminished 7' =>
        'Half-diminished seventh chord: root, minor third, diminished fifth, minor seventh.',
      'Diminished 7' =>
        'Diminished seventh chord: root, minor third, diminished fifth, diminished seventh.',
      'Minor 7' =>
        'Minor seventh chord: root, minor third, perfect fifth, minor seventh.',
      'Major 7' =>
        'Major seventh chord: root, major third, perfect fifth, major seventh.',
      'Diminished' => 'Diminished triad: root, minor third, diminished fifth.',
      'Minor' => 'Minor triad.',
      _ => 'Major triad.',
    };
  }

  static String _imagePath(String root, String type) {
    final key = _assetKey(root);
    final path = switch (type) {
      'Half-diminished 7' =>
        'diminished_chords/half_diminished_7/${key}m7b5.png',
      'Diminished 7' => 'diminished_chords/diminished_7/${key}dim7.png',
      'Minor 7' => 'seventh_chords/minor_7/${key}m7.png',
      'Major 7' => 'seventh_chords/major_7/${key}maj7.png',
      'Diminished' => 'diminished_chords/diminished_triad/${key}dim.png',
      'Minor' => 'basic_chords/minor/${key}m.png',
      _ => 'basic_chords/major/$key.png',
    };
    return 'asset://piano_scale_images_pianoscales_org/$path';
  }

  static List<DefaultChordInversionDefinition> _inversions(
    String root,
    String type,
  ) {
    final notes = _chordNotes(root, type);
    final names = notes.length == 4
        ? const [
            'Root position',
            'First inversion',
            'Second inversion',
            'Third inversion',
          ]
        : const [
            'Root position',
            'First inversion',
            'Second inversion',
          ];
    return [
      for (var index = 0; index < names.length; index++)
        DefaultChordInversionDefinition(
          name: names[index],
          keys: _rotate(notes, index).join(', '),
          imagePath: index == 0
              ? _imagePath(root, type)
              : _hasInversionImages(type)
                  ? _inversionImagePath(root, type, index)
                  : null,
          notes:
              _inversionDescription(type, names[index], _rotate(notes, index)),
        ),
    ];
  }

  static List<String> _rotate(List<String> values, int count) {
    if (values.isEmpty) {
      return values;
    }
    final offset = count % values.length;
    return [...values.skip(offset), ...values.take(offset)];
  }

  static String _inversionImagePath(String root, String type, int index) {
    final key = _assetKey(root);
    final position = switch (index) {
      1 => 'first',
      2 => 'second',
      _ => 'third',
    };
    final path = switch (type) {
      'Half-diminished 7' =>
        'diminished_chords/inversions/half_diminished_7/$position/${key}m7b5_$position.png',
      'Diminished 7' =>
        'diminished_chords/inversions/diminished_7/$position/${key}dim7_$position.png',
      'Diminished' =>
        'diminished_chords/inversions/diminished_triad/$position/${key}dim_$position.png',
      'Minor 7' =>
        'seventh_chords/inversions/minor_7/$position/${key}m7_$position.png',
      'Major 7' =>
        'seventh_chords/inversions/major_7/$position/${key}maj7_$position.png',
      'Minor' =>
        'basic_chords/inversions/minor/$position/${key}m_$position.png',
      _ => 'basic_chords/inversions/major/$position/${key}_$position.png',
    };
    return 'asset://piano_scale_images_pianoscales_org/$path';
  }

  static bool _hasInversionImages(String type) {
    return switch (type) {
      'Major' ||
      'Minor' ||
      'Diminished' ||
      'Major 7' ||
      'Minor 7' ||
      'Diminished 7' ||
      'Half-diminished 7' =>
        true,
      _ => false,
    };
  }

  static String _inversionDescription(
    String type,
    String name,
    List<String> keys,
  ) {
    final bass = keys.isEmpty ? '' : keys.first;
    final chordKind = type.contains('7') ? 'seventh chord' : 'triad';
    return switch (name) {
      'Root position' =>
        'The root is in the bass. This is the home shape of the $chordKind.',
      'First inversion' =>
        'The third is in the bass. The notes stay the same, but $bass becomes the lowest note.',
      'Second inversion' =>
        'The fifth is in the bass. The notes stay the same, but $bass becomes the lowest note.',
      _ =>
        'The seventh is in the bass. The notes stay the same, but $bass becomes the lowest note.',
    };
  }

  static String _assetKey(String root) {
    return switch (root) {
      'C#' => 'db',
      'D#' => 'eb',
      'F#' => 'gb',
      'G#' => 'ab',
      'A#' => 'bb',
      _ => root.toLowerCase(),
    };
  }

  static bool _preferFlats(String root, String type) {
    if (root.contains('b')) {
      return true;
    }
    if (root.contains('#')) {
      return false;
    }
    if (type.contains('Diminished') || type.contains('diminished')) {
      return true;
    }
    if (type.startsWith('Minor')) {
      return const ['C', 'F', 'G'].contains(root);
    }
    return root == 'F';
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

class DefaultChordDefinition {
  const DefaultChordDefinition({
    required this.name,
    required this.type,
    required this.keys,
    required this.imagePath,
    required this.inversions,
    required this.notes,
  });

  final String name;
  final String type;
  final String keys;
  final String imagePath;
  final List<DefaultChordInversionDefinition> inversions;
  final String notes;

  String get displayName => '$name $type';
}

class DefaultChordInversionDefinition {
  const DefaultChordInversionDefinition({
    required this.name,
    required this.keys,
    this.imagePath,
    required this.notes,
  });

  final String name;
  final String keys;
  final String? imagePath;
  final String notes;
}
