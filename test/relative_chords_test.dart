import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/core/utils/relative_chords.dart';
import 'package:personal_hymns_library/domain/entities/chord_tutorial.dart';

void main() {
  test('finds relative minor from major chords', () {
    final cMajor = _chord(
      1,
      'C',
      'Major',
      'C, E, G',
      relativeChordId: 2,
    );
    final aMinor = _chord(2, 'A', 'Minor', 'A, C, E');
    final dSharpMajor = _chord(
      3,
      'D#',
      'Major',
      'D#, G, A#',
      relativeChordId: 4,
    );
    final cMinor = _chord(4, 'C', 'Minor', 'C, Eb, G');

    expect(
      RelativeChords.findFor(cMajor, [cMajor, aMinor])?.chord.displayName,
      'A Minor',
    );
    expect(
      RelativeChords.findFor(
        dSharpMajor,
        [dSharpMajor, cMinor],
      )?.chord.displayName,
      'C Minor',
    );
  });

  test('finds relative major from minor chords', () {
    final aMinor = _chord(
      1,
      'A',
      'Minor',
      'A, C, E',
      relativeChordId: 2,
    );
    final cMajor = _chord(2, 'C', 'Major', 'C, E, G');
    final cMinor = _chord(
      3,
      'C',
      'Minor',
      'C, Eb, G',
      relativeChordId: 4,
    );
    final eFlatMajor = _chord(4, 'Eb', 'Major', 'Eb, G, Bb');

    expect(
      RelativeChords.findFor(aMinor, [aMinor, cMajor])?.chord.displayName,
      'C Major',
    );
    expect(
      RelativeChords.findFor(
        cMinor,
        [cMinor, eFlatMajor],
      )?.chord.displayName,
      'Eb Major',
    );
  });

  test('does not assign relative chords to diminished types', () {
    final diminished = _chord(1, 'C', 'Diminished', 'C, Eb, Gb');
    final aMinor = _chord(2, 'A', 'Minor', 'A, C, E');

    expect(RelativeChords.findFor(diminished, [diminished, aMinor]), isNull);
  });

  test('provides default relative target names for seeding', () {
    expect(RelativeChords.targetTypeFor('Major'), 'Minor');
    expect(RelativeChords.targetRootNamesFor('C', 'Major'), ['A']);
    expect(RelativeChords.targetRootNamesFor('D#', 'Major'), ['C']);
    expect(RelativeChords.targetTypeFor('Minor'), 'Major');
    expect(RelativeChords.targetRootNamesFor('C', 'Minor'), ['Eb', 'D#']);
  });

  test('uses saved relative chord override before automatic mapping', () {
    final cMajor = _chord(
      1,
      'C',
      'Major',
      'C, E, G',
      relativeChordId: 3,
    );
    final aMinor = _chord(2, 'A', 'Minor', 'A, C, E');
    final gMajor = _chord(3, 'G', 'Major', 'G, B, D');

    expect(
      RelativeChords.findFor(cMajor, [cMajor, aMinor, gMajor])
          ?.chord
          .displayName,
      'G Major',
    );
  });
}

ChordTutorial _chord(
  int id,
  String name,
  String type,
  String keys, {
  int? relativeChordId,
}) {
  return ChordTutorial(
    id: id,
    name: name,
    type: type,
    keys: keys,
    relativeChordId: relativeChordId,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}
