import 'dart:convert';

class LyricsLibraryEntry {
  const LyricsLibraryEntry({
    this.id,
    required this.title,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.source = customSource,
    this.sourceId,
  });

  static const customSource = 'custom';
  static const tasbe7naSource = 'tasbe7na';

  final int? id;
  final String title;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;
  final String? sourceId;

  bool get chorusFirst => payload['chorusFirst'] == true;

  List<String> get chorus => _stringList(payload['chorus']);

  List<String> get chorusSlides => chorus;

  List<List<String>> get verses {
    final value = payload['verses'];
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (_stringList(item).isNotEmpty) _stringList(item),
    ];
  }

  List<String> get verseSlides {
    return [
      for (final verse in verses)
        verse
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .join('\n\n'),
    ].where((slide) => slide.trim().isNotEmpty).toList();
  }

  List<String> get slides {
    final values = <String>[];
    final chorusValues = chorusSlides;
    final verseValues = verseSlides;
    if (chorusValues.isEmpty) {
      return verseValues;
    }
    if (chorusFirst) {
      values.addAll(chorusValues);
    }
    for (final verse in verseValues) {
      values
        ..add(verse)
        ..addAll(chorusValues);
    }
    if (verseValues.isEmpty && !chorusFirst) {
      values.addAll(chorusValues);
    }
    return values.where((slide) => slide.trim().isNotEmpty).toList();
  }

  String get songLyricsText => slides.join('\n\n---\n\n');

  String get bodyText => [
        ...chorusSlides,
        ...verseSlides,
      ].join(' ').trim();

  String get searchText => [
        title,
        bodyText,
      ].join(' ').trim();

  String get payloadJson => jsonEncode(payload);

  int get slideCount => slides.length;

  LyricsLibraryEntry copyWith({
    int? id,
    String? title,
    Map<String, Object?>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    String? sourceId,
    bool clearSourceId = false,
  }) {
    return LyricsLibraryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      sourceId: clearSourceId ? null : sourceId ?? this.sourceId,
    );
  }

  static LyricsLibraryEntry fromSlides({
    int? id,
    required String title,
    required List<String> slides,
    DateTime? createdAt,
    DateTime? updatedAt,
    String source = customSource,
    String? sourceId,
  }) {
    return fromParts(
      id: id,
      title: title,
      verseSlides: slides,
      createdAt: createdAt,
      updatedAt: updatedAt,
      source: source,
      sourceId: sourceId,
    );
  }

  static LyricsLibraryEntry fromParts({
    int? id,
    required String title,
    required List<String> verseSlides,
    List<String> chorusSlides = const [],
    bool chorusFirst = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String source = customSource,
    String? sourceId,
    Map<String, Object?> metadata = const {},
  }) {
    final now = DateTime.now();
    final cleanSource = source.trim().isEmpty ? customSource : source.trim();
    final cleanSourceId = sourceId?.trim();
    return LyricsLibraryEntry(
      id: id,
      title: title.trim(),
      payload: {
        'title': title.trim(),
        'formated': true,
        'source': cleanSource,
        if (cleanSourceId != null && cleanSourceId.isNotEmpty)
          'sourceId': cleanSourceId,
        ...metadata,
        'chorusFirst': chorusFirst,
        'chorus': [
          for (final slide in chorusSlides)
            if (slide.trim().isNotEmpty) slide.trim(),
        ],
        'verses': [
          for (final slide in verseSlides)
            if (slide.trim().isNotEmpty) [slide.trim()],
        ],
      },
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      source: cleanSource,
      sourceId:
          cleanSourceId == null || cleanSourceId.isEmpty ? null : cleanSourceId,
    );
  }

  static List<LyricsLibraryEntry> parseJsonList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Lyrics JSON must be a list.');
    }
    final now = DateTime.now();
    return [
      for (final item in decoded)
        if (item is Map && (item['title'] ?? '').toString().trim().isNotEmpty)
          _fromPayload(Map<String, Object?>.from(item), now: now),
    ];
  }

  static LyricsLibraryEntry _fromPayload(
    Map<String, Object?> payload, {
    required DateTime now,
  }) {
    final title = (payload['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      throw const FormatException('Lyrics entry is missing a title.');
    }
    payload['title'] = title;
    final source = (payload['source'] ?? customSource).toString().trim();
    final sourceId = (payload['sourceId'] ?? '').toString().trim();
    return LyricsLibraryEntry(
      title: title,
      payload: payload,
      createdAt: now,
      updatedAt: now,
      source: source.isEmpty ? customSource : source,
      sourceId: sourceId.isEmpty ? null : sourceId,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is String) {
      return value.trim().isEmpty ? const [] : [value.trim()];
    }
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }
}
