import 'rhythm.dart';

class RhythmItem {
  const RhythmItem({
    this.id,
    this.songId,
    this.position = 0,
    this.bpm,
    this.rhythms = const [],
  });

  final int? id;
  final int? songId;
  final int position;
  final int? bpm;
  final List<Rhythm> rhythms;

  String get summary =>
      rhythms.map((rhythm) => rhythm.rhythmName).where((name) {
        return name.trim().isNotEmpty;
      }).join(' / ');

  RhythmItem copyWith({
    int? id,
    int? songId,
    int? position,
    int? bpm,
    List<Rhythm>? rhythms,
    bool clearBpm = false,
  }) {
    return RhythmItem(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      bpm: clearBpm ? null : bpm ?? this.bpm,
      rhythms: rhythms ?? this.rhythms,
    );
  }
}
