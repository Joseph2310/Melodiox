class SongFilter {
  const SongFilter({
    this.favoriteOnly = false,
    this.tagIds = const {},
    this.myKey,
    this.originalKey,
    this.scale,
    this.scaleType,
    this.rhythm,
    this.minBpm,
    this.maxBpm,
    this.transposeValue,
    this.quarterTone,
    this.completed,
    this.hasAudio,
    this.hasVideo,
    this.hasChordImages,
    this.hasLyrics,
    this.hasNotes,
  });

  final bool favoriteOnly;
  final Set<int> tagIds;
  final String? myKey;
  final String? originalKey;
  final String? scale;
  final String? scaleType;
  final String? rhythm;
  final int? minBpm;
  final int? maxBpm;
  final int? transposeValue;
  final String? quarterTone;
  final bool? completed;
  final bool? hasAudio;
  final bool? hasVideo;
  final bool? hasChordImages;
  final bool? hasLyrics;
  final bool? hasNotes;

  bool get hasActiveFilters {
    return favoriteOnly ||
        tagIds.isNotEmpty ||
        myKey != null ||
        originalKey != null ||
        scale != null ||
        scaleType != null ||
        rhythm != null ||
        minBpm != null ||
        maxBpm != null ||
        transposeValue != null ||
        quarterTone != null ||
        completed != null ||
        hasAudio != null ||
        hasVideo != null ||
        hasChordImages != null ||
        hasLyrics != null ||
        hasNotes != null;
  }

  SongFilter copyWith({
    bool? favoriteOnly,
    Set<int>? tagIds,
    String? myKey,
    String? originalKey,
    String? scale,
    String? scaleType,
    String? rhythm,
    int? minBpm,
    int? maxBpm,
    int? transposeValue,
    String? quarterTone,
    bool? completed,
    bool? hasAudio,
    bool? hasVideo,
    bool? hasChordImages,
    bool? hasLyrics,
    bool? hasNotes,
    bool clearTag = false,
    bool clearMyKey = false,
    bool clearOriginalKey = false,
    bool clearScale = false,
    bool clearScaleType = false,
    bool clearRhythm = false,
    bool clearMinBpm = false,
    bool clearMaxBpm = false,
    bool clearTranspose = false,
    bool clearQuarterTone = false,
    bool clearCompleted = false,
    bool clearHasAudio = false,
    bool clearHasVideo = false,
    bool clearHasChordImages = false,
    bool clearHasLyrics = false,
    bool clearHasNotes = false,
  }) {
    return SongFilter(
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      tagIds: clearTag ? const {} : tagIds ?? this.tagIds,
      myKey: clearMyKey ? null : myKey ?? this.myKey,
      originalKey: clearOriginalKey ? null : originalKey ?? this.originalKey,
      scale: clearScale ? null : scale ?? this.scale,
      scaleType: clearScaleType ? null : scaleType ?? this.scaleType,
      rhythm: clearRhythm ? null : rhythm ?? this.rhythm,
      minBpm: clearMinBpm ? null : minBpm ?? this.minBpm,
      maxBpm: clearMaxBpm ? null : maxBpm ?? this.maxBpm,
      transposeValue:
          clearTranspose ? null : transposeValue ?? this.transposeValue,
      quarterTone: clearQuarterTone ? null : quarterTone ?? this.quarterTone,
      completed: clearCompleted ? null : completed ?? this.completed,
      hasAudio: clearHasAudio ? null : hasAudio ?? this.hasAudio,
      hasVideo: clearHasVideo ? null : hasVideo ?? this.hasVideo,
      hasChordImages:
          clearHasChordImages ? null : hasChordImages ?? this.hasChordImages,
      hasLyrics: clearHasLyrics ? null : hasLyrics ?? this.hasLyrics,
      hasNotes: clearHasNotes ? null : hasNotes ?? this.hasNotes,
    );
  }
}
