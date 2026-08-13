import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/core/constants/default_chords.dart';
import 'package:personal_hymns_library/core/constants/music_keys.dart';

void main() {
  test('default catalog contains triad and seventh entries for every key', () {
    final definitions = DefaultChordCatalog.definitions;

    expect(definitions, hasLength(MusicKeys.values.length * 7));
    expect(
      definitions.map((chord) => chord.displayName),
      containsAll([
        'C Major',
        'C Minor',
        'C Diminished',
        'C Major 7',
        'C Minor 7',
        'C Diminished 7',
        'C Half-diminished 7',
      ]),
    );
  });

  test('default seventh chords include notes and bundled images', () {
    final cMajor7 = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Major 7',
    );
    final cMinor7 = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Minor 7',
    );

    expect(cMajor7.keys, 'C, E, G, B');
    expect(cMajor7.imagePath, contains('seventh_chords/major_7/cmaj7.png'));
    expect(cMinor7.keys, 'C, Eb, G, Bb');
    expect(cMinor7.imagePath, contains('seventh_chords/minor_7/cm7.png'));
  });

  test('default chords include editable inversion tutorial entries', () {
    final cMajor = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Major',
    );
    final cMajor7 = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Major 7',
    );

    expect(
      cMajor.inversions.map((inversion) => inversion.name),
      ['Root position', 'First inversion', 'Second inversion'],
    );
    expect(cMajor.inversions[1].keys, 'E, G, C');
    expect(
      cMajor.inversions[1].imagePath,
      contains('basic_chords/inversions/major/first/c_first.png'),
    );

    expect(
      cMajor7.inversions.map((inversion) => inversion.name),
      [
        'Root position',
        'First inversion',
        'Second inversion',
        'Third inversion',
      ],
    );
    expect(cMajor7.inversions[3].keys, 'B, C, E, G');
    expect(
      cMajor7.inversions[3].imagePath,
      contains('seventh_chords/inversions/major_7/third/cmaj7_third.png'),
    );
  });

  test('default diminished chords include notes and bundled images', () {
    final cDiminished = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Diminished',
    );
    final cDiminished7 = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Diminished 7',
    );
    final cHalfDiminished7 = DefaultChordCatalog.definitions.firstWhere(
      (chord) => chord.displayName == 'C Half-diminished 7',
    );

    expect(cDiminished.keys, 'C, Eb, Gb');
    expect(
      cDiminished.imagePath,
      contains('diminished_chords/diminished_triad/cdim.png'),
    );
    expect(cDiminished.inversions[1].keys, 'Eb, Gb, C');
    expect(
      cDiminished.inversions[1].imagePath,
      contains(
          'diminished_chords/inversions/diminished_triad/first/cdim_first.png'),
    );

    expect(cDiminished7.keys, 'C, Eb, Gb, A');
    expect(
      cDiminished7.imagePath,
      contains('diminished_chords/diminished_7/cdim7.png'),
    );
    expect(
      cDiminished7.inversions[3].imagePath,
      contains(
          'diminished_chords/inversions/diminished_7/third/cdim7_third.png'),
    );
    expect(cHalfDiminished7.keys, 'C, Eb, Gb, Bb');
    expect(
      cHalfDiminished7.imagePath,
      contains('diminished_chords/half_diminished_7/cm7b5.png'),
    );
    expect(
      cHalfDiminished7.inversions[3].imagePath,
      contains(
          'diminished_chords/inversions/half_diminished_7/third/cm7b5_third.png'),
    );
  });
}
