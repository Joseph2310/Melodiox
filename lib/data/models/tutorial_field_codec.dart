import 'dart:convert';

import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/tutorial_detail.dart';

class TutorialFieldCodec {
  const TutorialFieldCodec._();

  static List<TutorialNote> decodeNotes(Object? value) {
    final text = value as String?;
    if (text == null || text.trim().isEmpty) {
      return const [];
    }
    final trimmed = text.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return _notesFromList(decoded);
      }
    } catch (_) {
      // Older app versions stored one plain notes string.
    }
    return [TutorialNote(body: trimmed)];
  }

  static String encodeNotes(List<TutorialNote> notes) {
    final values = [
      for (final note in notes)
        if (!note.isEmpty)
          {
            'title': note.title.trim(),
            'body': note.body.trim(),
          },
    ];
    return jsonEncode(values);
  }

  static List<TutorialLink> decodeLinks(Object? value) {
    final text = value as String?;
    if (text == null || text.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return _linksFromList(decoded);
      }
    } catch (_) {
      // Ignore malformed link payloads and keep the app usable.
    }
    return const [];
  }

  static String encodeLinks(List<TutorialLink> links) {
    final values = [
      for (final link in links)
        if (!link.isEmpty)
          {
            'label': link.label.trim(),
            'url': link.url.trim(),
          },
    ];
    return jsonEncode(values);
  }

  static List<TutorialCustomField> decodeCustomFields(Object? value) {
    final text = value as String?;
    if (text == null || text.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => TutorialCustomField(
                name: item['name']?.toString() ?? '',
                value: item['value']?.toString() ?? '',
              ),
            )
            .where((field) => !field.isEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore malformed custom fields and keep the app usable.
    }
    return const [];
  }

  static String encodeCustomFields(List<TutorialCustomField> fields) {
    final values = [
      for (final field in fields)
        if (!field.isEmpty)
          {
            'name': field.name.trim(),
            'value': field.value.trim(),
          },
    ];
    return jsonEncode(values);
  }

  static List<ChordInversion> decodeInversions(Object? value) {
    final text = value as String?;
    if (text == null || text.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => ChordInversion(
                name: item['name']?.toString() ?? '',
                keys: item['keys']?.toString() ?? '',
                imagePath: _blankToNull(item['imagePath']?.toString()),
                videoPath: _blankToNull(item['videoPath']?.toString()),
                notes: item['notes'] is List
                    ? _notesFromList(item['notes'] as List)
                    : decodeNotes(item['notes']),
                links: item['links'] is List
                    ? _linksFromList(item['links'] as List)
                    : decodeLinks(item['links']),
              ),
            )
            .where((inversion) => !inversion.isEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore malformed inversion payloads and keep the app usable.
    }
    return const [];
  }

  static String encodeInversions(List<ChordInversion> inversions) {
    final values = [
      for (final inversion in inversions)
        if (!inversion.isEmpty)
          {
            'name': inversion.name.trim(),
            'keys': inversion.keys.trim(),
            'imagePath': _blankToNull(inversion.imagePath),
            'videoPath': _blankToNull(inversion.videoPath),
            'notes': _noteMaps(inversion.notes),
            'links': _linkMaps(inversion.links),
          },
    ];
    return jsonEncode(values);
  }

  static List<TutorialNote> _notesFromList(List<Object?> values) {
    return values
        .whereType<Map>()
        .map(
          (item) => TutorialNote(
            title: item['title']?.toString() ?? '',
            body: item['body']?.toString() ?? '',
          ),
        )
        .where((note) => !note.isEmpty)
        .toList(growable: false);
  }

  static List<TutorialLink> _linksFromList(List<Object?> values) {
    return values
        .whereType<Map>()
        .map(
          (item) => TutorialLink(
            label: item['label']?.toString() ?? '',
            url: item['url']?.toString() ?? '',
          ),
        )
        .where((link) => !link.isEmpty)
        .toList(growable: false);
  }

  static List<Map<String, String>> _noteMaps(List<TutorialNote> notes) {
    return [
      for (final note in notes)
        if (!note.isEmpty)
          {
            'title': note.title.trim(),
            'body': note.body.trim(),
          },
    ];
  }

  static List<Map<String, String>> _linkMaps(List<TutorialLink> links) {
    return [
      for (final link in links)
        if (!link.isEmpty)
          {
            'label': link.label.trim(),
            'url': link.url.trim(),
          },
    ];
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
