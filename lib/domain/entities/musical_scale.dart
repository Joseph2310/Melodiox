import 'chord_tutorial.dart';
import 'tutorial_detail.dart';

class MusicalScale {
  const MusicalScale({
    this.id,
    required this.name,
    required this.type,
    required this.keys,
    required this.formula,
    this.imagePath,
    this.videoPath,
    this.chordTutorials = const [],
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
  final String formula;
  final String? imagePath;
  final String? videoPath;
  final List<ChordTutorial> chordTutorials;
  final List<TutorialNote> notes;
  final List<TutorialLink> links;
  final List<TutorialCustomField> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => '${name.trim()} ${type.trim()}'.trim();

  MusicalScale copyWith({
    int? id,
    String? name,
    String? type,
    String? keys,
    String? formula,
    String? imagePath,
    String? videoPath,
    List<ChordTutorial>? chordTutorials,
    List<TutorialNote>? notes,
    List<TutorialLink>? links,
    List<TutorialCustomField>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearImagePath = false,
    bool clearVideoPath = false,
    bool clearNotes = false,
  }) {
    return MusicalScale(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      keys: keys ?? this.keys,
      formula: formula ?? this.formula,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      videoPath: clearVideoPath ? null : videoPath ?? this.videoPath,
      chordTutorials: chordTutorials ?? this.chordTutorials,
      notes: clearNotes ? const [] : notes ?? this.notes,
      links: links ?? this.links,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
