import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/core/utils/music_key_sort.dart';

void main() {
  test('sorts keys from C in music key order', () {
    final keys = ['A', 'C', 'E', 'D', 'B'];

    keys.sort(compareMusicKeys);

    expect(keys, ['C', 'D', 'E', 'A', 'B']);
  });

  test('keeps accidentals near their base key order', () {
    final keys = ['G', 'Db', 'C', 'F#', 'D'];

    keys.sort(compareMusicKeys);

    expect(keys, ['C', 'Db', 'D', 'F#', 'G']);
  });
}
