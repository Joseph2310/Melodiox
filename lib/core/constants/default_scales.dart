import 'music_keys.dart';

class DefaultScaleCatalog {
  const DefaultScaleCatalog._();

  static const types = <String>['Major', 'Minor'];

  static List<DefaultScaleDefinition> get definitions {
    return [
      for (final name in MusicKeys.values)
        for (final type in types)
          DefaultScaleDefinition(
            name: name,
            type: type,
            keys: _scaleNotes(name, type).join(', '),
            formula: _formula(type),
            imagePath: _imagePath(name, type),
            notes: _scaleNotesDescription(type),
          ),
    ];
  }

  static List<String> _scaleNotes(String root, String type) {
    return switch (type) {
      'Minor' => _minorScaleNotes[root] ?? _minorScaleNotes['C']!,
      _ => _majorScaleNotes[root] ?? _majorScaleNotes['C']!,
    };
  }

  static String _formula(String type) {
    return switch (type) {
      'Minor' => '1, 1/2, 1, 1, 1/2, 1, 1',
      _ => '1, 1, 1/2, 1, 1, 1, 1/2',
    };
  }

  static String _scaleNotesDescription(String type) {
    return switch (type) {
      'Minor' => 'Natural minor scale.',
      _ => 'Major scale.',
    };
  }

  static String _imagePath(String root, String type) {
    final directory = type == 'Minor' ? 'minor_natural' : 'major';
    final suffix = type == 'Minor' ? 'minor' : 'major';
    final key = _assetKey(root);
    return 'asset://piano_scale_images_pianoscales_org/scales/$directory/${key}_$suffix.png';
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

  static const _majorScaleNotes = <String, List<String>>{
    'C': ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'],
    'C#': ['C#', 'D#', 'E#', 'F#', 'G#', 'A#', 'B#', 'C#'],
    'Db': ['Db', 'Eb', 'F', 'Gb', 'Ab', 'Bb', 'C', 'Db'],
    'D': ['D', 'E', 'F#', 'G', 'A', 'B', 'C#', 'D'],
    'D#': ['D#', 'E#', 'F##', 'G#', 'A#', 'B#', 'C##', 'D#'],
    'Eb': ['Eb', 'F', 'G', 'Ab', 'Bb', 'C', 'D', 'Eb'],
    'E': ['E', 'F#', 'G#', 'A', 'B', 'C#', 'D#', 'E'],
    'F': ['F', 'G', 'A', 'Bb', 'C', 'D', 'E', 'F'],
    'F#': ['F#', 'G#', 'A#', 'B', 'C#', 'D#', 'E#', 'F#'],
    'Gb': ['Gb', 'Ab', 'Bb', 'Cb', 'Db', 'Eb', 'F', 'Gb'],
    'G': ['G', 'A', 'B', 'C', 'D', 'E', 'F#', 'G'],
    'G#': ['G#', 'A#', 'B#', 'C#', 'D#', 'E#', 'F##', 'G#'],
    'Ab': ['Ab', 'Bb', 'C', 'Db', 'Eb', 'F', 'G', 'Ab'],
    'A': ['A', 'B', 'C#', 'D', 'E', 'F#', 'G#', 'A'],
    'A#': ['A#', 'B#', 'C##', 'D#', 'E#', 'F##', 'G##', 'A#'],
    'Bb': ['Bb', 'C', 'D', 'Eb', 'F', 'G', 'A', 'Bb'],
    'B': ['B', 'C#', 'D#', 'E', 'F#', 'G#', 'A#', 'B'],
  };

  static const _minorScaleNotes = <String, List<String>>{
    'C': ['C', 'D', 'Eb', 'F', 'G', 'Ab', 'Bb', 'C'],
    'C#': ['C#', 'D#', 'E', 'F#', 'G#', 'A', 'B', 'C#'],
    'Db': ['Db', 'Eb', 'Fb', 'Gb', 'Ab', 'Bbb', 'Cb', 'Db'],
    'D': ['D', 'E', 'F', 'G', 'A', 'Bb', 'C', 'D'],
    'D#': ['D#', 'E#', 'F#', 'G#', 'A#', 'B', 'C#', 'D#'],
    'Eb': ['Eb', 'F', 'Gb', 'Ab', 'Bb', 'Cb', 'Db', 'Eb'],
    'E': ['E', 'F#', 'G', 'A', 'B', 'C', 'D', 'E'],
    'F': ['F', 'G', 'Ab', 'Bb', 'C', 'Db', 'Eb', 'F'],
    'F#': ['F#', 'G#', 'A', 'B', 'C#', 'D', 'E', 'F#'],
    'Gb': ['Gb', 'Ab', 'Bbb', 'Cb', 'Db', 'Ebb', 'Fb', 'Gb'],
    'G': ['G', 'A', 'Bb', 'C', 'D', 'Eb', 'F', 'G'],
    'G#': ['G#', 'A#', 'B', 'C#', 'D#', 'E', 'F#', 'G#'],
    'Ab': ['Ab', 'Bb', 'Cb', 'Db', 'Eb', 'Fb', 'Gb', 'Ab'],
    'A': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'A'],
    'A#': ['A#', 'B#', 'C#', 'D#', 'E#', 'F#', 'G#', 'A#'],
    'Bb': ['Bb', 'C', 'Db', 'Eb', 'F', 'Gb', 'Ab', 'Bb'],
    'B': ['B', 'C#', 'D', 'E', 'F#', 'G', 'A', 'B'],
  };
}

class DefaultScaleDefinition {
  const DefaultScaleDefinition({
    required this.name,
    required this.type,
    required this.keys,
    required this.formula,
    required this.imagePath,
    required this.notes,
  });

  final String name;
  final String type;
  final String keys;
  final String formula;
  final String imagePath;
  final String notes;

  String get displayName => '$name $type';
}
