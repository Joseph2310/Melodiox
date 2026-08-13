class MusicKeys {
  const MusicKeys._();

  static const values = <String>[
    'C',
    'C#',
    'Db',
    'D',
    'D#',
    'Eb',
    'E',
    'F',
    'F#',
    'Gb',
    'G',
    'G#',
    'Ab',
    'A',
    'A#',
    'Bb',
    'B',
  ];

  static const quarterToneValues = values;

  static const scaleTypes = <String>[
    'Major',
    'Minor',
  ];

  static final scales = <String>[
    for (final key in values)
      for (final scale in scaleTypes) '$key $scale',
  ];

  static List<String> scalesForTypes(Iterable<String> types) {
    final normalizedTypes = types
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final effectiveTypes =
        normalizedTypes.isEmpty ? scaleTypes : normalizedTypes;
    return [
      for (final key in values)
        for (final scale in effectiveTypes) '$key $scale',
    ];
  }
}
