import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum AppLanguage {
  english,
  arabic;

  String get storageValue {
    return switch (this) {
      AppLanguage.english => 'en',
      AppLanguage.arabic => 'ar',
    };
  }

  Locale get locale {
    return Locale(storageValue);
  }
}

enum SongCardField {
  myKey,
  transpose,
  rhythm,
  bpm,
  quarterTone,
  chords,
  tags,
  originalScale,
  myScale,
  originalKey,
  notes;

  String get storageValue {
    return switch (this) {
      SongCardField.myKey => 'myKey',
      SongCardField.transpose => 'transpose',
      SongCardField.rhythm => 'rhythm',
      SongCardField.bpm => 'bpm',
      SongCardField.quarterTone => 'quarterTone',
      SongCardField.chords => 'chords',
      SongCardField.tags => 'tags',
      SongCardField.originalScale => 'originalScale',
      SongCardField.myScale => 'myScale',
      SongCardField.originalKey => 'originalKey',
      SongCardField.notes => 'notes',
    };
  }

  String get label {
    return switch (this) {
      SongCardField.myKey => 'My Key',
      SongCardField.transpose => 'Transpose',
      SongCardField.rhythm => 'Rhythm',
      SongCardField.bpm => 'BPM',
      SongCardField.quarterTone => 'Quarter Tone',
      SongCardField.chords => 'Chords',
      SongCardField.tags => 'Tags',
      SongCardField.originalScale => 'Original Scale',
      SongCardField.myScale => 'My Scale',
      SongCardField.originalKey => 'Original Key',
      SongCardField.notes => 'Notes',
    };
  }
}

enum PlaylistItemField {
  myKey,
  transpose,
  rhythm,
  bpm,
  quarterTone,
  chords,
  tags,
  originalScale,
  myScale,
  originalKey,
  notes;

  String get storageValue {
    return switch (this) {
      PlaylistItemField.myKey => 'myKey',
      PlaylistItemField.transpose => 'transpose',
      PlaylistItemField.rhythm => 'rhythm',
      PlaylistItemField.bpm => 'bpm',
      PlaylistItemField.quarterTone => 'quarterTone',
      PlaylistItemField.chords => 'chords',
      PlaylistItemField.tags => 'tags',
      PlaylistItemField.originalScale => 'originalScale',
      PlaylistItemField.myScale => 'myScale',
      PlaylistItemField.originalKey => 'originalKey',
      PlaylistItemField.notes => 'notes',
    };
  }

  String get label {
    return switch (this) {
      PlaylistItemField.myKey => 'My Key',
      PlaylistItemField.transpose => 'Transpose',
      PlaylistItemField.rhythm => 'Rhythm',
      PlaylistItemField.bpm => 'BPM',
      PlaylistItemField.quarterTone => 'Quarter Tone',
      PlaylistItemField.chords => 'Chords',
      PlaylistItemField.tags => 'Tags',
      PlaylistItemField.originalScale => 'Original Scale',
      PlaylistItemField.myScale => 'My Scale',
      PlaylistItemField.originalKey => 'Original Key',
      PlaylistItemField.notes => 'Notes',
    };
  }
}

enum IncompleteSongCardStyle {
  none,
  soft,
  strong;

  String get storageValue {
    return switch (this) {
      IncompleteSongCardStyle.none => 'none',
      IncompleteSongCardStyle.soft => 'soft',
      IncompleteSongCardStyle.strong => 'strong',
    };
  }

  String get label {
    return switch (this) {
      IncompleteSongCardStyle.none => 'No color',
      IncompleteSongCardStyle.soft => 'Soft color',
      IncompleteSongCardStyle.strong => 'Strong color',
    };
  }
}

enum IncompleteSongCardColor {
  amber,
  red,
  blue,
  green,
  purple;

  String get storageValue {
    return switch (this) {
      IncompleteSongCardColor.amber => 'amber',
      IncompleteSongCardColor.red => 'red',
      IncompleteSongCardColor.blue => 'blue',
      IncompleteSongCardColor.green => 'green',
      IncompleteSongCardColor.purple => 'purple',
    };
  }

  String get label {
    return switch (this) {
      IncompleteSongCardColor.amber => 'Amber',
      IncompleteSongCardColor.red => 'Red',
      IncompleteSongCardColor.blue => 'Blue',
      IncompleteSongCardColor.green => 'Green',
      IncompleteSongCardColor.purple => 'Purple',
    };
  }

  Color get color {
    return switch (this) {
      IncompleteSongCardColor.amber => Colors.amber,
      IncompleteSongCardColor.red => Colors.red,
      IncompleteSongCardColor.blue => Colors.blue,
      IncompleteSongCardColor.green => Colors.green,
      IncompleteSongCardColor.purple => Colors.purple,
    };
  }
}

class SettingsProvider extends ChangeNotifier {
  static const _themeModeKey = 'themeMode';
  static const _keepScreenAwakeKey = 'keepScreenAwake';
  static const _languageKey = 'language';
  static const _songCardFieldsKey = 'songCardFields';
  static const _playlistItemFieldsKey = 'playlistItemFields';
  static const _incompleteSongCardStyleKey = 'incompleteSongCardStyle';
  static const _incompleteSongCardColorKey = 'incompleteSongCardColor';
  static const _lyricsFontSizeKey = 'lyricsFontSize';
  static const _defaultSongCardFields = [
    SongCardField.myKey,
    SongCardField.transpose,
    SongCardField.rhythm,
    SongCardField.bpm,
    SongCardField.quarterTone,
    SongCardField.chords,
    SongCardField.tags,
  ];
  static const _defaultPlaylistItemFields = [
    PlaylistItemField.myKey,
  ];

  ThemeMode _themeMode = ThemeMode.system;
  bool _keepScreenAwake = false;
  AppLanguage _language = AppLanguage.english;
  List<SongCardField> _songCardFields = _defaultSongCardFields;
  List<PlaylistItemField> _playlistItemFields = _defaultPlaylistItemFields;
  IncompleteSongCardStyle _incompleteSongCardStyle =
      IncompleteSongCardStyle.soft;
  IncompleteSongCardColor _incompleteSongCardColor =
      IncompleteSongCardColor.amber;
  double _lyricsFontSize = 28;

  ThemeMode get themeMode => _themeMode;
  bool get keepScreenAwake => _keepScreenAwake;
  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  List<SongCardField> get songCardFields => List.unmodifiable(_songCardFields);
  List<PlaylistItemField> get playlistItemFields =>
      List.unmodifiable(_playlistItemFields);
  IncompleteSongCardStyle get incompleteSongCardStyle =>
      _incompleteSongCardStyle;
  IncompleteSongCardColor get incompleteSongCardColor =>
      _incompleteSongCardColor;
  double get lyricsFontSize => _lyricsFontSize;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_themeModeKey);
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _keepScreenAwake = preferences.getBool(_keepScreenAwakeKey) ?? false;
    _language = _languageFromStorage(preferences.getString(_languageKey));
    _songCardFields = _songCardFieldsFromStorage(
      preferences.getStringList(_songCardFieldsKey),
    );
    _playlistItemFields = _playlistItemFieldsFromStorage(
      preferences.getStringList(_playlistItemFieldsKey),
    );
    _incompleteSongCardStyle = _incompleteStyleFromStorage(
      preferences.getString(_incompleteSongCardStyleKey),
    );
    _incompleteSongCardColor = _incompleteColorFromStorage(
      preferences.getString(_incompleteSongCardColorKey),
    );
    _lyricsFontSize = _lyricsFontSizeFromStorage(
      preferences.getDouble(_lyricsFontSizeKey),
    );
    unawaited(_applyKeepScreenAwake());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, _storageValue(value));
  }

  Future<void> setKeepScreenAwake(bool value) async {
    _keepScreenAwake = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keepScreenAwakeKey, value);
    await _applyKeepScreenAwake();
  }

  Future<void> setLanguage(AppLanguage value) async {
    _language = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageKey, value.storageValue);
  }

  Future<void> setSongCardFields(List<SongCardField> values) async {
    _songCardFields = [...values];
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _songCardFieldsKey,
      values.map((field) => field.storageValue).toList(),
    );
  }

  Future<void> setPlaylistItemFields(List<PlaylistItemField> values) async {
    _playlistItemFields = [...values];
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _playlistItemFieldsKey,
      values.map((field) => field.storageValue).toList(),
    );
  }

  Future<void> setIncompleteSongCardStyle(
    IncompleteSongCardStyle value,
  ) async {
    _incompleteSongCardStyle = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _incompleteSongCardStyleKey, value.storageValue);
  }

  Future<void> setIncompleteSongCardColor(
    IncompleteSongCardColor value,
  ) async {
    _incompleteSongCardColor = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _incompleteSongCardColorKey,
      value.storageValue,
    );
  }

  Future<void> setLyricsFontSize(double value) async {
    _lyricsFontSize = value.clamp(20, 44).toDouble();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_lyricsFontSizeKey, _lyricsFontSize);
  }

  String _storageValue(ThemeMode value) {
    return switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  AppLanguage _languageFromStorage(String? value) {
    return switch (value) {
      'ar' => AppLanguage.arabic,
      _ => AppLanguage.english,
    };
  }

  List<SongCardField> _songCardFieldsFromStorage(List<String>? values) {
    if (values == null) {
      return _defaultSongCardFields;
    }
    final fields = <SongCardField>[];
    for (final value in values) {
      for (final field in SongCardField.values) {
        if (field.storageValue == value && !fields.contains(field)) {
          fields.add(field);
        }
      }
    }
    return fields;
  }

  List<PlaylistItemField> _playlistItemFieldsFromStorage(
    List<String>? values,
  ) {
    if (values == null) {
      return _defaultPlaylistItemFields;
    }
    final fields = <PlaylistItemField>[];
    for (final value in values) {
      for (final field in PlaylistItemField.values) {
        if (field.storageValue == value && !fields.contains(field)) {
          fields.add(field);
        }
      }
    }
    return fields;
  }

  IncompleteSongCardStyle _incompleteStyleFromStorage(String? value) {
    for (final style in IncompleteSongCardStyle.values) {
      if (style.storageValue == value) {
        return style;
      }
    }
    return IncompleteSongCardStyle.soft;
  }

  IncompleteSongCardColor _incompleteColorFromStorage(String? value) {
    for (final color in IncompleteSongCardColor.values) {
      if (color.storageValue == value) {
        return color;
      }
    }
    return IncompleteSongCardColor.amber;
  }

  double _lyricsFontSizeFromStorage(double? value) {
    return (value ?? 28).clamp(20, 44).toDouble();
  }

  Future<void> _applyKeepScreenAwake() async {
    try {
      if (_keepScreenAwake) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
