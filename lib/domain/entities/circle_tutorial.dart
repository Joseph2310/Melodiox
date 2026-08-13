import 'tutorial_detail.dart';

class CircleTutorial {
  const CircleTutorial({
    this.id,
    required this.title,
    this.summary,
    this.imagePath,
    this.videoPath,
    this.notes = const [],
    this.links = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String? summary;
  final String? imagePath;
  final String? videoPath;
  final List<TutorialNote> notes;
  final List<TutorialLink> links;
  final DateTime createdAt;
  final DateTime updatedAt;

  CircleTutorial copyWith({
    int? id,
    String? title,
    String? summary,
    String? imagePath,
    String? videoPath,
    List<TutorialNote>? notes,
    List<TutorialLink>? links,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSummary = false,
    bool clearImagePath = false,
    bool clearVideoPath = false,
  }) {
    return CircleTutorial(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: clearSummary ? null : summary ?? this.summary,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      videoPath: clearVideoPath ? null : videoPath ?? this.videoPath,
      notes: notes ?? this.notes,
      links: links ?? this.links,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
