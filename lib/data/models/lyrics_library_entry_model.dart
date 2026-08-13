import 'dart:convert';

import '../../domain/entities/lyrics_library_entry.dart';

class LyricsLibraryEntryModel {
  const LyricsLibraryEntryModel._();

  static LyricsLibraryEntry fromMap(Map<String, Object?> map) {
    return LyricsLibraryEntry(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      payload: _decodePayload(map['payload']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      source: map['source'] as String? ?? LyricsLibraryEntry.customSource,
      sourceId: map['sourceId'] as String?,
    );
  }

  static Map<String, Object?> toMap(LyricsLibraryEntry entry) {
    final payload = Map<String, Object?>.from(entry.payload);
    payload['title'] = entry.title.trim();
    payload['source'] = entry.source;
    if (entry.sourceId == null || entry.sourceId!.trim().isEmpty) {
      payload.remove('sourceId');
    } else {
      payload['sourceId'] = entry.sourceId!.trim();
    }
    return {
      'id': entry.id,
      'title': entry.title.trim(),
      'payload': jsonEncode(payload),
      'searchText': entry.searchText,
      'chorusFirst': entry.chorusFirst ? 1 : 0,
      'slideCount': entry.slideCount,
      'source': entry.source,
      'sourceId': entry.sourceId,
      'createdAt': entry.createdAt.toIso8601String(),
      'updatedAt': entry.updatedAt.toIso8601String(),
    };
  }

  static Map<String, Object?> _decodePayload(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return const {};
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
