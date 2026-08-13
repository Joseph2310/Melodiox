import '../entities/lyrics_library_entry.dart';

enum LyricsLibrarySort {
  titleAsc,
  titleDesc,
  newest,
  oldest,
  mostSlides,
  source,
}

abstract class LyricsLibraryRepository {
  Future<List<LyricsLibraryEntry>> getEntries({
    String query = '',
    int? limit,
    int offset = 0,
    LyricsLibrarySort sort = LyricsLibrarySort.titleAsc,
  });
  Future<int> countEntries({String query = ''});
  Future<LyricsLibraryEntry?> getEntry(int id);
  Future<int> saveEntry(LyricsLibraryEntry entry);
  Future<void> deleteEntry(int id);
  Future<int> importFromJson(String source);
  Future<String> exportJson();
  Future<int> replaceAllFromJson(String source);
  Future<void> ensureSeeded();
}
