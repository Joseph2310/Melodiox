import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/lyrics_library_entry.dart';
import '../../domain/repositories/lyrics_library_repository.dart';
import '../database/database_provider.dart';
import '../models/lyrics_library_entry_model.dart';

class SqliteLyricsLibraryRepository implements LyricsLibraryRepository {
  SqliteLyricsLibraryRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  static const _tasbe7naImportFormatVersion = 3;

  @override
  Future<List<LyricsLibraryEntry>> getEntries({
    String query = '',
    int? limit,
    int offset = 0,
    LyricsLibrarySort sort = LyricsLibrarySort.titleAsc,
  }) async {
    final db = await _databaseProvider.database;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      final rows = await db.query(
        'lyrics_library_entries',
        orderBy: _orderBy(sort),
        limit: limit,
        offset: limit == null ? null : offset,
      );
      return rows.map(LyricsLibraryEntryModel.fromMap).toList();
    }

    final scored = await _scoredTitleMatches(db, normalized);
    final selected =
        (limit == null ? scored.skip(offset) : scored.skip(offset).take(limit))
            .toList();
    if (selected.isEmpty) {
      return const [];
    }
    final entries = await _entriesByIds(db, selected.map((item) => item.id));
    return [
      for (final item in selected)
        if (entries[item.id] != null) entries[item.id]!,
    ];
  }

  @override
  Future<int> countEntries({String query = ''}) async {
    final db = await _databaseProvider.database;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM lyrics_library_entries'),
          ) ??
          0;
    }
    return (await _scoredTitleMatches(db, normalized)).length;
  }

  @override
  Future<LyricsLibraryEntry?> getEntry(int id) async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'lyrics_library_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return LyricsLibraryEntryModel.fromMap(rows.first);
  }

  @override
  Future<int> saveEntry(LyricsLibraryEntry entry) async {
    final db = await _databaseProvider.database;
    final now = DateTime.now();
    final effective = entry.copyWith(
      createdAt: entry.id == null ? now : entry.createdAt,
      updatedAt: now,
    );
    final row = LyricsLibraryEntryModel.toMap(effective)..remove('id');
    if (entry.id == null) {
      return db.insert('lyrics_library_entries', row);
    }
    await db.update(
      'lyrics_library_entries',
      row,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return entry.id!;
  }

  @override
  Future<void> deleteEntry(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('lyrics_library_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> importFromJson(String source) async {
    final entries = LyricsLibraryEntry.parseJsonList(source);
    if (entries.isEmpty) {
      throw const FormatException('No lyrics entries were found.');
    }
    final db = await _databaseProvider.database;
    return db.transaction<int>(
      (txn) => _mergeEntries(
        txn,
        entries,
        replaceSource: false,
      ),
    );
  }

  @override
  Future<String> exportJson() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'lyrics_library_entries',
      orderBy: 'source COLLATE NOCASE ASC, title COLLATE NOCASE ASC, id ASC',
    );
    final entries = rows.map(LyricsLibraryEntryModel.fromMap);
    final payloads = [
      for (final entry in entries)
        {
          ...entry.payload,
          'title': entry.title,
          'source': entry.source,
          if (entry.sourceId != null) 'sourceId': entry.sourceId,
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(payloads);
  }

  @override
  Future<int> replaceAllFromJson(String source) {
    return importFromJson(source);
  }

  @override
  Future<void> ensureSeeded() async {
    final db = await _databaseProvider.database;
    await _removeBundledLegacySeedIfNeeded(db);
    if (await _hasCurrentTasbe7naImport(db)) {
      return;
    }
    try {
      final source = await rootBundle.loadString('tasbe7naDB.json');
      final entries = LyricsLibraryEntry.parseJsonList(source);
      if (entries.isEmpty) {
        return;
      }
      await db.transaction<int>(
        (txn) => _mergeEntries(
          txn,
          entries,
          replaceSource: true,
        ),
      );
    } catch (_) {
      // The bundled library is optional at runtime; manual import remains usable.
    }
  }

  Future<int> _mergeEntries(
    DatabaseExecutor db,
    List<LyricsLibraryEntry> entries, {
    required bool replaceSource,
  }) async {
    final importedSourceIds = <String, Set<String>>{};
    final existingBySourceId = <String, Map<String, Object?>>{};
    final sources = entries
        .map((entry) => entry.source.trim().isEmpty
            ? LyricsLibraryEntry.customSource
            : entry.source.trim())
        .toSet();
    for (final source in sources) {
      final rows = await db.query(
        'lyrics_library_entries',
        columns: ['id', 'createdAt', 'source', 'sourceId'],
        where: 'source = ? AND sourceId IS NOT NULL',
        whereArgs: [source],
      );
      for (final row in rows) {
        final sourceId = row['sourceId'] as String?;
        if (sourceId != null && sourceId.isNotEmpty) {
          existingBySourceId[_sourceKey(source, sourceId)] = row;
        }
      }
    }

    var changed = 0;
    for (final incoming in entries) {
      final source = incoming.source.trim().isEmpty
          ? LyricsLibraryEntry.customSource
          : incoming.source.trim();
      final sourceId = incoming.sourceId?.trim();
      final entry = incoming.copyWith(
        source: source,
        sourceId: sourceId,
        clearSourceId: sourceId == null || sourceId.isEmpty,
      );
      if (sourceId != null && sourceId.isNotEmpty) {
        importedSourceIds.putIfAbsent(source, () => <String>{}).add(sourceId);
      }

      final row = LyricsLibraryEntryModel.toMap(entry)..remove('id');
      final existing = sourceId == null || sourceId.isEmpty
          ? null
          : existingBySourceId[_sourceKey(source, sourceId)];
      final existingId = existing?['id'] as int?;
      if (existingId != null) {
        row['createdAt'] = existing?['createdAt'];
        await db.update(
          'lyrics_library_entries',
          row,
          where: 'id = ?',
          whereArgs: [existingId],
        );
      } else {
        await db.insert(
          'lyrics_library_entries',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      changed++;
    }

    if (replaceSource) {
      for (final sourceEntry in importedSourceIds.entries) {
        final rows = await db.query(
          'lyrics_library_entries',
          columns: ['id', 'sourceId'],
          where: 'source = ? AND sourceId IS NOT NULL',
          whereArgs: [sourceEntry.key],
        );
        for (final row in rows) {
          final id = row['id'] as int?;
          final sourceId = row['sourceId'] as String?;
          if (id != null &&
              sourceId != null &&
              !sourceEntry.value.contains(sourceId)) {
            await db.delete(
              'lyrics_library_entries',
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    }

    return changed;
  }

  String _sourceKey(String source, String sourceId) => '$source\x00$sourceId';

  String _orderBy(LyricsLibrarySort sort) {
    return switch (sort) {
      LyricsLibrarySort.titleAsc => 'title COLLATE NOCASE ASC, id ASC',
      LyricsLibrarySort.titleDesc => 'title COLLATE NOCASE DESC, id DESC',
      LyricsLibrarySort.newest => 'updatedAt DESC, id DESC',
      LyricsLibrarySort.oldest => 'updatedAt ASC, id ASC',
      LyricsLibrarySort.mostSlides =>
        'slideCount DESC, title COLLATE NOCASE ASC',
      LyricsLibrarySort.source =>
        'source COLLATE NOCASE ASC, title COLLATE NOCASE ASC, id ASC',
    };
  }

  Future<List<_ScoredLyricsTitle>> _scoredTitleMatches(
    DatabaseExecutor db,
    String normalized,
  ) async {
    final titleRows = await db.query(
      'lyrics_library_entries',
      columns: ['id', 'title'],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
    final scored = [
      for (final row in titleRows)
        _ScoredLyricsTitle(
          row['id'] as int,
          row['title'] as String? ?? '',
          _scoreTitle(row['title'] as String? ?? '', normalized),
        ),
    ]..removeWhere((item) => item.score <= 0.18);

    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return scored;
  }

  Future<bool> _hasCurrentTasbe7naImport(DatabaseExecutor db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM lyrics_library_entries
            WHERE source = ?
              AND payload LIKE ?
            ''',
            [
              LyricsLibraryEntry.tasbe7naSource,
              '%"importFormatVersion":$_tasbe7naImportFormatVersion%',
            ],
          ),
        ) ??
        0;
    return count > 0;
  }

  Future<void> _removeBundledLegacySeedIfNeeded(DatabaseExecutor db) async {
    final tasbe7naCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM lyrics_library_entries WHERE source = ?',
            [LyricsLibraryEntry.tasbe7naSource],
          ),
        ) ??
        0;
    if (tasbe7naCount > 0) {
      return;
    }

    final candidateRows = await db.rawQuery(
      '''
      SELECT createdAt, updatedAt, COUNT(*) AS count
      FROM lyrics_library_entries
      WHERE source = ? AND sourceId IS NULL
      GROUP BY createdAt, updatedAt
      ORDER BY count DESC
      LIMIT 1
      ''',
      [LyricsLibraryEntry.customSource],
    );
    if (candidateRows.isEmpty) {
      return;
    }
    final candidate = candidateRows.first;
    final count = candidate['count'] as int? ?? 0;
    final createdAt = candidate['createdAt'] as String?;
    final updatedAt = candidate['updatedAt'] as String?;
    if (count < 1000 ||
        createdAt == null ||
        updatedAt == null ||
        createdAt != updatedAt) {
      return;
    }

    await db.delete(
      'lyrics_library_entries',
      where:
          'source = ? AND sourceId IS NULL AND createdAt = ? AND updatedAt = ?',
      whereArgs: [LyricsLibraryEntry.customSource, createdAt, updatedAt],
    );
  }

  Future<Map<int, LyricsLibraryEntry>> _entriesByIds(
    DatabaseExecutor db,
    Iterable<int> ids,
  ) async {
    final result = <int, LyricsLibraryEntry>{};
    final values = ids.toList(growable: false);
    for (var start = 0; start < values.length; start += 800) {
      final end = start + 800 > values.length ? values.length : start + 800;
      final chunk = values.sublist(start, end);
      final rows = await db.query(
        'lyrics_library_entries',
        where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final entry = LyricsLibraryEntryModel.fromMap(row);
        final id = entry.id;
        if (id != null) {
          result[id] = entry;
        }
      }
    }
    return result;
  }
}

class _ScoredLyricsTitle {
  const _ScoredLyricsTitle(this.id, this.title, this.score);

  final int id;
  final String title;
  final double score;
}

double _scoreTitle(String titleValue, String query) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) {
    return 1;
  }
  final queryTokens = normalizedQuery.split(' ');
  final title = _normalizeSearchText(titleValue);

  final titleAverage = _averageScore(queryTokens, title);
  final phraseTitleScore = _scoreText(title, normalizedQuery);

  final titleWeighted = (titleAverage * 1.25).clamp(0.0, 1.0);
  final phraseWeighted = (phraseTitleScore * 1.2).clamp(0.0, 1.0);

  return [
    titleWeighted,
    phraseWeighted,
  ].reduce((best, value) => value > best ? value : best);
}

double _averageScore(List<String> queryTokens, String text) {
  if (queryTokens.isEmpty || text.isEmpty) {
    return 0;
  }
  final scores = [
    for (final token in queryTokens)
      if (token.isNotEmpty) _scoreText(text, token),
  ];
  if (scores.isEmpty) {
    return 0;
  }
  return scores.reduce((sum, value) => sum + value) / scores.length;
}

double _scoreText(String text, String query) {
  if (text.isEmpty || query.isEmpty) {
    return 0;
  }
  if (text == query) {
    return 1;
  }
  if (text.contains(query)) {
    return query.contains(' ') ? 0.98 : 0.92;
  }

  var best = 0.0;
  for (final word in text.split(' ')) {
    if (word.isEmpty) {
      continue;
    }
    if (word == query) {
      return 1;
    }
    if (word.startsWith(query)) {
      best = _max(best, 0.9);
    } else if (query.startsWith(word) && word.length >= 3) {
      best = _max(best, 0.72);
    }

    final similarity = _levenshteinSimilarity(word, query);
    if (similarity >= 0.68) {
      best = _max(best, 0.42 + similarity * 0.48);
    }

    final subsequence = _subsequenceScore(word, query);
    if (subsequence >= 0.55) {
      best = _max(best, subsequence * 0.78);
    }
  }
  return best;
}

double _levenshteinSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  if (a == b) {
    return 1;
  }
  final aRunes = a.runes.toList();
  final bRunes = b.runes.toList();
  if (aRunes.length < 3 || bRunes.length < 3) {
    return 0;
  }
  final previous = List<int>.generate(bRunes.length + 1, (index) => index);
  final current = List<int>.filled(bRunes.length + 1, 0);
  for (var i = 0; i < aRunes.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < bRunes.length; j++) {
      final cost = aRunes[i] == bRunes[j] ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((best, value) => value < best ? value : best);
    }
    for (var j = 0; j < previous.length; j++) {
      previous[j] = current[j];
    }
  }
  final distance = previous.last;
  final longest = aRunes.length > bRunes.length ? aRunes.length : bRunes.length;
  return 1 - (distance / longest);
}

double _subsequenceScore(String word, String query) {
  if (word.isEmpty || query.isEmpty || query.length > word.length) {
    return 0;
  }
  var queryIndex = 0;
  var firstMatch = -1;
  var lastMatch = -1;
  final wordRunes = word.runes.toList();
  final queryRunes = query.runes.toList();
  for (var i = 0; i < wordRunes.length && queryIndex < queryRunes.length; i++) {
    if (wordRunes[i] == queryRunes[queryIndex]) {
      firstMatch = firstMatch == -1 ? i : firstMatch;
      lastMatch = i;
      queryIndex++;
    }
  }
  if (queryIndex != queryRunes.length || firstMatch == -1) {
    return 0;
  }
  final span = lastMatch - firstMatch + 1;
  final compactness = queryRunes.length / span;
  final coverage = queryRunes.length / wordRunes.length;
  return (compactness * 0.7) + (coverage * 0.3);
}

String _normalizeSearchText(String value) {
  var text = value.toLowerCase();
  const replacements = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ئ': 'ي',
    'ؤ': 'و',
    'ة': 'ه',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  final buffer = StringBuffer();
  var lastWasSpace = true;
  for (final rune in text.runes) {
    if (_isArabicMark(rune)) {
      continue;
    }
    if (_isSearchLetterOrDigit(rune)) {
      buffer.writeCharCode(rune);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

bool _isArabicMark(int rune) {
  return rune == 0x0640 ||
      rune == 0x0670 ||
      (rune >= 0x064B && rune <= 0x065F) ||
      (rune >= 0x06D6 && rune <= 0x06ED);
}

bool _isSearchLetterOrDigit(int rune) {
  return (rune >= 0x0030 && rune <= 0x0039) ||
      (rune >= 0x0061 && rune <= 0x007A) ||
      (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF);
}

double _max(double a, double b) => a > b ? a : b;
