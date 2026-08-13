import '../../domain/entities/song.dart';

class SongValidation {
  const SongValidation._();

  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? requiredInt(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    if (int.tryParse(value.trim()) == null) {
      return '$label must be a valid number';
    }
    return null;
  }

  static String? optionalInt(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (int.tryParse(value.trim()) == null) {
      return '$label must be a valid number';
    }
    return null;
  }

  static String? validateSong(Song song) {
    if (song.name.trim().isEmpty) {
      return 'Song name is required';
    }
    if (song.myStartingKey.trim().isEmpty) {
      return 'My starting key is required';
    }
    return null;
  }
}
