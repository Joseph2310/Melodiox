import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hymns_library/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads saved night mode preference', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final provider = SettingsProvider();

    await provider.load();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('saves night mode preference', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    await provider.setThemeMode(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('themeMode'), 'dark');
  });

  test('saves and loads language preference', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    await provider.setLanguage(AppLanguage.arabic);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('language'), 'ar');

    final reloadedProvider = SettingsProvider();
    await reloadedProvider.load();

    expect(reloadedProvider.language, AppLanguage.arabic);
    expect(reloadedProvider.locale.languageCode, 'ar');
  });

  test('saves and loads incomplete song card style', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    await provider.setIncompleteSongCardStyle(IncompleteSongCardStyle.strong);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('incompleteSongCardStyle'), 'strong');

    final reloadedProvider = SettingsProvider();
    await reloadedProvider.load();

    expect(
      reloadedProvider.incompleteSongCardStyle,
      IncompleteSongCardStyle.strong,
    );
  });

  test('saves and loads incomplete song card color', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    await provider.setIncompleteSongCardColor(IncompleteSongCardColor.blue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('incompleteSongCardColor'), 'blue');

    final reloadedProvider = SettingsProvider();
    await reloadedProvider.load();

    expect(
      reloadedProvider.incompleteSongCardColor,
      IncompleteSongCardColor.blue,
    );
  });

  test('saves and loads lyrics font size', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    await provider.setLyricsFontSize(34);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('lyricsFontSize'), 34);

    final reloadedProvider = SettingsProvider();
    await reloadedProvider.load();

    expect(reloadedProvider.lyricsFontSize, 34);
  });
}
