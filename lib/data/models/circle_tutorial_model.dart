import '../../domain/entities/circle_tutorial.dart';
import 'tutorial_field_codec.dart';

class CircleTutorialModel {
  const CircleTutorialModel._();

  static CircleTutorial fromMap(Map<String, Object?> map) {
    final now = DateTime.now();
    return CircleTutorial(
      id: map['id'] as int?,
      title: map['title'] as String,
      summary: map['summary'] as String?,
      imagePath: map['imagePath'] as String?,
      videoPath: map['videoPath'] as String?,
      notes: TutorialFieldCodec.decodeNotes(map['notes']),
      links: TutorialFieldCodec.decodeLinks(map['links']),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? now,
    );
  }

  static Map<String, Object?> toMap(CircleTutorial tutorial) {
    return {
      'id': tutorial.id,
      'title': tutorial.title.trim(),
      'summary': _blankToNull(tutorial.summary),
      'imagePath': _blankToNull(tutorial.imagePath),
      'videoPath': _blankToNull(tutorial.videoPath),
      'notes': TutorialFieldCodec.encodeNotes(tutorial.notes),
      'links': TutorialFieldCodec.encodeLinks(tutorial.links),
      'createdAt': tutorial.createdAt.toIso8601String(),
      'updatedAt': tutorial.updatedAt.toIso8601String(),
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
