import '../../domain/entities/general_note.dart';

class GeneralNoteModel {
  const GeneralNoteModel._();

  static GeneralNote fromMap(
    Map<String, Object?> map, {
    List<NoteImage> images = const [],
  }) {
    return GeneralNote(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      pinned: (map['pinned'] as int? ?? 0) == 1,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      images: images,
    );
  }

  static Map<String, Object?> toMap(GeneralNote note) {
    return {
      'id': note.id,
      'title': note.title.trim(),
      'body': note.body.trim(),
      'pinned': note.pinned ? 1 : 0,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  static NoteImage imageFromMap(Map<String, Object?> map) {
    return NoteImage(
      id: map['id'] as int?,
      noteId: map['noteId'] as int?,
      localPath: map['localPath'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  static Map<String, Object?> imageToMap(NoteImage image, int noteId) {
    return {
      'id': image.id,
      'noteId': noteId,
      'localPath': image.localPath.trim(),
      'sortOrder': image.sortOrder,
    };
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
