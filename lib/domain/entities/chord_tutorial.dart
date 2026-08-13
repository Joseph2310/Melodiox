import 'tutorial_detail.dart';

class ChordTutorial {
  const ChordTutorial({
    this.id,
    required this.name,
    required this.type,
    required this.keys,
    this.imagePath,
    this.videoPath,
    this.relativeChordId,
    this.inversions = const [],
    this.notes = const [],
    this.links = const [],
    this.customFields = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String type;
  final String keys;
  final String? imagePath;
  final String? videoPath;
  final int? relativeChordId;
  final List<ChordInversion> inversions;
  final List<TutorialNote> notes;
  final List<TutorialLink> links;
  final List<TutorialCustomField> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final value = '$name $type'.trim();
    return value.isEmpty ? name : value;
  }

  String get chordName => displayName;

  ChordTutorial copyWith({
    int? id,
    String? name,
    String? type,
    String? keys,
    String? imagePath,
    String? videoPath,
    int? relativeChordId,
    List<ChordInversion>? inversions,
    List<TutorialNote>? notes,
    List<TutorialLink>? links,
    List<TutorialCustomField>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearImagePath = false,
    bool clearVideoPath = false,
    bool clearRelativeChordId = false,
    bool clearNotes = false,
  }) {
    return ChordTutorial(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      keys: keys ?? this.keys,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      videoPath: clearVideoPath ? null : videoPath ?? this.videoPath,
      relativeChordId:
          clearRelativeChordId ? null : relativeChordId ?? this.relativeChordId,
      inversions: inversions ?? this.inversions,
      notes: clearNotes ? const [] : notes ?? this.notes,
      links: links ?? this.links,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChordTutorial &&
        (id != null && other.id != null
            ? id == other.id
            : displayName.toLowerCase() == other.displayName.toLowerCase());
  }

  @override
  int get hashCode => id ?? displayName.toLowerCase().hashCode;
}

class ChordInversion {
  const ChordInversion({
    required this.name,
    required this.keys,
    this.imagePath,
    this.videoPath,
    this.notes = const [],
    this.links = const [],
  });

  final String name;
  final String keys;
  final String? imagePath;
  final String? videoPath;
  final List<TutorialNote> notes;
  final List<TutorialLink> links;

  bool get isEmpty {
    return name.trim().isEmpty &&
        keys.trim().isEmpty &&
        (imagePath == null || imagePath!.trim().isEmpty) &&
        (videoPath == null || videoPath!.trim().isEmpty) &&
        notes.isEmpty &&
        links.isEmpty;
  }

  ChordInversion copyWith({
    String? name,
    String? keys,
    String? imagePath,
    String? videoPath,
    List<TutorialNote>? notes,
    List<TutorialLink>? links,
    bool clearImagePath = false,
    bool clearVideoPath = false,
  }) {
    return ChordInversion(
      name: name ?? this.name,
      keys: keys ?? this.keys,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      videoPath: clearVideoPath ? null : videoPath ?? this.videoPath,
      notes: notes ?? this.notes,
      links: links ?? this.links,
    );
  }
}
