class Rhythm {
  const Rhythm({
    this.id,
    this.songId,
    required this.rhythmName,
    this.section,
    this.isPrimary = false,
  });

  final int? id;
  final int? songId;
  final String rhythmName;
  final String? section;
  final bool isPrimary;

  Rhythm copyWith({
    int? id,
    int? songId,
    String? rhythmName,
    String? section,
    bool? isPrimary,
    bool clearSection = false,
  }) {
    return Rhythm(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      rhythmName: rhythmName ?? this.rhythmName,
      section: clearSection ? null : section ?? this.section,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Rhythm &&
        (id != null && other.id != null
            ? id == other.id
            : rhythmName.toLowerCase() == other.rhythmName.toLowerCase());
  }

  @override
  int get hashCode => id ?? rhythmName.toLowerCase().hashCode;
}
