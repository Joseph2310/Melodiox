import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/core/constants/default_scales.dart';
import 'package:personal_hymns_library/core/constants/music_keys.dart';

void main() {
  test('default catalog contains major and minor entries for every key', () {
    final definitions = DefaultScaleCatalog.definitions;

    expect(definitions, hasLength(MusicKeys.values.length * 2));
    expect(
      definitions.map((scale) => scale.displayName),
      containsAll(['C Major', 'C Minor', 'D Major', 'D Minor', 'Bb Major']),
    );
  });

  test('default catalog includes scale notes and formula details', () {
    final cMajor = DefaultScaleCatalog.definitions.firstWhere(
      (scale) => scale.displayName == 'C Major',
    );
    final cMinor = DefaultScaleCatalog.definitions.firstWhere(
      (scale) => scale.displayName == 'C Minor',
    );

    expect(cMajor.keys, 'C, D, E, F, G, A, B, C');
    expect(cMajor.formula, '1, 1, 1/2, 1, 1, 1, 1/2');
    expect(cMinor.keys, 'C, D, Eb, F, G, Ab, Bb, C');
    expect(cMinor.formula, '1, 1/2, 1, 1, 1/2, 1, 1');
  });
}
