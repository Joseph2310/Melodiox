class GeneralNote {
  const GeneralNote({
    this.id,
    required this.title,
    required this.body,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  final int? id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoteImage> images;

  GeneralNote copyWith({
    int? id,
    String? title,
    String? body,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<NoteImage>? images,
  }) {
    return GeneralNote(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
    );
  }
}

class NoteImage {
  const NoteImage({
    this.id,
    this.noteId,
    required this.localPath,
    this.sortOrder = 0,
  });

  final int? id;
  final int? noteId;
  final String localPath;
  final int sortOrder;

  NoteImage copyWith({
    int? id,
    int? noteId,
    String? localPath,
    int? sortOrder,
  }) {
    return NoteImage(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      localPath: localPath ?? this.localPath,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
