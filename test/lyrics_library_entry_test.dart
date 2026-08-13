import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/domain/entities/lyrics_library_entry.dart';

void main() {
  test('repeats chorus after every verse slide', () {
    final entry = LyricsLibraryEntry.fromParts(
      title: 'Sample',
      chorusSlides: const ['Chorus'],
      verseSlides: const ['Verse 1', 'Verse 2'],
    );

    expect(entry.slides, const ['Verse 1', 'Chorus', 'Verse 2', 'Chorus']);
  });

  test('can show chorus first without duplicating it in the editor body', () {
    final entry = LyricsLibraryEntry.fromParts(
      title: 'Sample',
      chorusFirst: true,
      chorusSlides: const ['Chorus'],
      verseSlides: const ['Verse 1'],
    );

    expect(entry.chorusSlides, const ['Chorus']);
    expect(entry.verseSlides, const ['Verse 1']);
    expect(entry.slides, const ['Chorus', 'Verse 1', 'Chorus']);
  });
}
