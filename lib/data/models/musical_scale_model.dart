import '../../domain/entities/musical_scale.dart';
import '../../domain/entities/chord_tutorial.dart';
import 'tutorial_field_codec.dart';

class MusicalScaleModel {
  const MusicalScaleModel._();

  static MusicalScale fromMap(
    Map<String, Object?> map, {
    List<ChordTutorial> chordTutorials = const [],
  }) {
    return MusicalScale(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      keys: map['keys'] as String,
      formula: map['formula'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      videoPath: map['videoPath'] as String?,
      chordTutorials: chordTutorials,
      notes: TutorialFieldCodec.decodeNotes(map['notes']),
      links: TutorialFieldCodec.decodeLinks(map['links']),
      customFields: TutorialFieldCodec.decodeCustomFields(map['customFields']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static Map<String, Object?> toMap(MusicalScale scale) {
    return {
      'id': scale.id,
      'name': scale.name.trim(),
      'type': scale.type.trim(),
      'keys': scale.keys.trim(),
      'formula': scale.formula.trim(),
      'imagePath': _blankToNull(scale.imagePath),
      'videoPath': _blankToNull(scale.videoPath),
      'notes': TutorialFieldCodec.encodeNotes(scale.notes),
      'links': TutorialFieldCodec.encodeLinks(scale.links),
      'customFields': TutorialFieldCodec.encodeCustomFields(
        scale.customFields,
      ),
      'createdAt': scale.createdAt.toIso8601String(),
      'updatedAt': scale.updatedAt.toIso8601String(),
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
