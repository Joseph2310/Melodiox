import '../../domain/entities/rhythm.dart';

class RhythmModel {
  const RhythmModel._();

  static Rhythm fromMap(Map<String, Object?> map) {
    return Rhythm(
      id: map['id'] as int?,
      songId: map['songId'] as int?,
      rhythmName: map['rhythmName'] as String,
      section: map['section'] as String?,
      isPrimary: (map['isPrimary'] as int? ?? 0) == 1,
    );
  }

  static Map<String, Object?> toMap(Rhythm rhythm) {
    return {
      'id': rhythm.id,
      'rhythmName': rhythm.rhythmName.trim(),
      'section': _blankToNull(rhythm.section),
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
