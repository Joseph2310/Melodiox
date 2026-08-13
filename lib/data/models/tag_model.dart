import '../../domain/entities/tag.dart';

class TagModel {
  const TagModel._();

  static Tag fromMap(Map<String, Object?> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int?,
    );
  }

  static Map<String, Object?> toMap(Tag tag) {
    return {'id': tag.id, 'name': tag.name.trim(), 'color': tag.color};
  }
}
