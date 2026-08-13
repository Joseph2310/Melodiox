import '../../domain/entities/chord_tutorial.dart';
import 'tutorial_field_codec.dart';

class ChordTutorialModel {
  const ChordTutorialModel._();

  static ChordTutorial fromMap(Map<String, Object?> map) {
    final parsed = _parseChordName(map['chordName'] as String? ?? '');
    final now = DateTime.now();
    return ChordTutorial(
      id: map['id'] as int?,
      name: map['name'] as String? ?? parsed.name,
      type: map['type'] as String? ?? parsed.type,
      keys: map['keys'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      videoPath: map['videoPath'] as String?,
      relativeChordId: map['relativeChordId'] as int?,
      inversions: TutorialFieldCodec.decodeInversions(map['inversions']),
      notes: TutorialFieldCodec.decodeNotes(map['notes']),
      links: TutorialFieldCodec.decodeLinks(map['links']),
      customFields: TutorialFieldCodec.decodeCustomFields(map['customFields']),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? now,
    );
  }

  static Map<String, Object?> toMap(ChordTutorial tutorial) {
    return {
      'id': tutorial.id,
      'name': tutorial.name.trim(),
      'type': tutorial.type.trim(),
      'keys': tutorial.keys.trim(),
      'imagePath': _blankToNull(tutorial.imagePath),
      'videoPath': _blankToNull(tutorial.videoPath),
      'relativeChordId': tutorial.relativeChordId,
      'inversions': TutorialFieldCodec.encodeInversions(tutorial.inversions),
      'notes': TutorialFieldCodec.encodeNotes(tutorial.notes),
      'links': TutorialFieldCodec.encodeLinks(tutorial.links),
      'customFields': TutorialFieldCodec.encodeCustomFields(
        tutorial.customFields,
      ),
      'createdAt': tutorial.createdAt.toIso8601String(),
      'updatedAt': tutorial.updatedAt.toIso8601String(),
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static ({String name, String type}) _parseChordName(String value) {
    final trimmed = value.trim();
    for (final type in const [
      'Half-diminished 7',
      'Diminished 7',
      'Major 7',
      'Minor 7',
      'Diminished',
      'Major',
      'Minor',
    ]) {
      if (trimmed.toLowerCase().endsWith(' ${type.toLowerCase()}')) {
        return (
          name: trimmed.substring(0, trimmed.length - type.length).trim(),
          type: type,
        );
      }
    }
    return (name: trimmed, type: 'Custom');
  }
}
