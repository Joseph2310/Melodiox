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
    final intervals = switch (type) {
      'Minor' => const [0, 2, 3, 5, 7, 8, 10],
      _ => const [0, 2, 4, 5, 7, 9, 11],
    };
    final chromatic =
        _preferFlats(root, type) ? _flatChromatic : _sharpChromatic;
    final rootIndex = chromatic.indexOf(root);
    final effectiveRootIndex =
        rootIndex >= 0 ? rootIndex : _sharpChromatic.indexOf(root);
    return [
      for (final interval in intervals)
        chromatic[(effectiveRootIndex + interval) % chromatic.length],
      chromatic[effectiveRootIndex % chromatic.length],
    ];
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

  static bool _preferFlats(String root, String type) {
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
