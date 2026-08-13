enum MediaType {
  chordImage,
  melodyImage,
  songAudio,
  vocalAudio,
  performanceVideo,
}

extension MediaTypeX on MediaType {
  String get storageValue {
    switch (this) {
      case MediaType.chordImage:
        return 'chord_image';
      case MediaType.melodyImage:
        return 'melody_image';
      case MediaType.songAudio:
        return 'song_audio';
      case MediaType.vocalAudio:
        return 'vocal_audio';
      case MediaType.performanceVideo:
        return 'performance_video';
    }
  }

  String get label {
    switch (this) {
      case MediaType.chordImage:
        return 'Chord image';
      case MediaType.melodyImage:
        return 'Melody image';
      case MediaType.songAudio:
        return 'Song audio';
      case MediaType.vocalAudio:
        return 'Vocal audio';
      case MediaType.performanceVideo:
        return 'Performance video';
    }
  }

  static MediaType fromStorageValue(String value) {
    return MediaType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MediaType.chordImage,
    );
  }
}
