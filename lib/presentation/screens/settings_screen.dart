import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../domain/entities/song.dart';
import '../../services/backup_service.dart';
import '../../services/link_service.dart';
import '../../services/song_export_service.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/shell_navigation_scope.dart';

const _appName = 'Melodiox';
const _appVersion = '1';
const _developerName = 'Joseph Ashraf';
const _developerEmail = 'joseph.ashraf2310@gmail.com';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: ShellBackButton.leading(context),
        title: Text(context.t('Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.t('Theme'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto),
                label: Text(context.t('System')),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode),
                label: Text(context.t('Light')),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.nightlight_round),
                label: Text(context.t('Night')),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) {
              settings.setThemeMode(value.first);
            },
          ),
          const SizedBox(height: 24),
          Text(context.t('Language'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AppLanguage>(
            segments: [
              ButtonSegment(
                value: AppLanguage.english,
                icon: const Icon(Icons.language),
                label: Text(context.t('English')),
              ),
              ButtonSegment(
                value: AppLanguage.arabic,
                icon: const Icon(Icons.translate),
                label: Text(context.t('Arabic')),
              ),
            ],
            selected: {settings.language},
            onSelectionChanged: (value) {
              settings.setLanguage(value.first);
            },
          ),
          const SizedBox(height: 24),
          Text(context.t('Display'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.screen_lock_portrait_outlined),
                  title: Text(context.t('Keep screen awake')),
                  value: settings.keepScreenAwake,
                  onChanged: settings.setKeepScreenAwake,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(context.t('Display configuration')),
                  subtitle: Text(
                    context.t('Song cards and playlist items'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDisplaySettings(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(context.t('Data'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(context.t('Backup & export')),
                  subtitle: Text(context.t('Backups, restore, and PDF export')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openBackupSettings(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.t('About'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(_appName),
                  subtitle: Text(
                    context.t('Personal song and piano tutorial library.'),
                  ),
                  onTap: () => _showAppAbout(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(context.t('Version')),
                  subtitle: const Text(_appVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(context.t('Developer')),
                  subtitle: const Text(_developerName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(context.t('Email')),
                  subtitle: const Text(_developerEmail),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openDeveloperEmail(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDisplaySettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _DisplaySettingsScreen()),
    );
  }

  Future<void> _openBackupSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BackupSettingsScreen(
          onExportDatabase: _exportDatabase,
          onExportFullBackup: _exportFullBackup,
          onRestoreDatabase: _restoreDatabase,
          onRestoreFullBackup: _restoreFullBackup,
          onExportSongs: _exportSongs,
        ),
      ),
    );
  }

  void _showAppAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: _appName,
      applicationVersion: _appVersion,
      children: [
        Text(context.t('Personal song and piano tutorial library.')),
        const SizedBox(height: 12),
        Text('${context.t('Developed by')}: $_developerName'),
        Text('${context.t('Email')}: $_developerEmail'),
      ],
    );
  }

  Future<void> _openDeveloperEmail(BuildContext context) async {
    final opened = await LinkService.openExternal('mailto:$_developerEmail');
    if (!opened && context.mounted) {
      _showSnack(context, context.t('Unable to open email'));
    }
  }

  Future<void> _exportDatabase(BuildContext context) async {
    final target = await _chooseBackupTarget(context);
    if (target == null || !context.mounted) {
      return;
    }
    try {
      final service = context.read<BackupService>();
      final path = await service.exportDatabase(target: target);
      if (!context.mounted) {
        return;
      }
      _showSnack(
        context,
        path == null
            ? context.t('Backup cancelled')
            : context.t('Database exported'),
      );
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, '${context.t('Backup failed')}: $error');
      }
    }
  }

  Future<void> _exportFullBackup(BuildContext context) async {
    final target = await _chooseBackupTarget(context);
    if (target == null || !context.mounted) {
      return;
    }
    try {
      final service = context.read<BackupService>();
      final path = await service.exportFullBackup(target: target);
      if (!context.mounted) {
        return;
      }
      _showSnack(
        context,
        path == null
            ? context.t('Backup cancelled')
            : context.t('Full backup exported'),
      );
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, '${context.t('Backup failed')}: $error');
      }
    }
  }

  Future<void> _restoreDatabase(BuildContext context) async {
    final source = await _chooseRestoreSource(context);
    if (source == null || !context.mounted) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Restore database'),
      message: context.t('Restore will replace the current local library.'),
      confirmLabel: context.t('Restore'),
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      final service = context.read<BackupService>();
      final path = await service.restoreDatabase(source: source);
      if (!context.mounted) {
        return;
      }
      if (path == null) {
        _showSnack(context, context.t('Restore cancelled'));
        return;
      }
      await context.read<LibraryProvider>().load();
      if (context.mounted) {
        _showSnack(context, context.t('Database restored'));
      }
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, '${context.t('Restore failed')}: $error');
      }
    }
  }

  Future<void> _restoreFullBackup(BuildContext context) async {
    final source = await _chooseRestoreSource(context);
    if (source == null || !context.mounted) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Full restore'),
      message: context.t(
        'Full restore will replace the current database and copied media files.',
      ),
      confirmLabel: context.t('Restore'),
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      final service = context.read<BackupService>();
      final path = await service.restoreFullBackup(source: source);
      if (!context.mounted) {
        return;
      }
      if (path == null) {
        _showSnack(context, context.t('Restore cancelled'));
        return;
      }
      await context.read<LibraryProvider>().load();
      if (context.mounted) {
        _showSnack(context, context.t('Full backup restored'));
      }
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, '${context.t('Restore failed')}: $error');
      }
    }
  }

  Future<void> _exportSongs(BuildContext context) async {
    final library = context.read<LibraryProvider>();
    if (library.songs.isEmpty) {
      _showSnack(context, context.t('No songs to export'));
      return;
    }
    final request = await showDialog<_SongExportRequest>(
      context: context,
      builder: (context) => _SongExportDialog(songs: library.songs),
    );
    if (request == null || request.songIds.isEmpty || !context.mounted) {
      return;
    }
    final selectedSongs = library.songs
        .where((song) => song.id != null && request.songIds.contains(song.id))
        .toList();
    final path = await SongExportService().exportPdf(
      songs: selectedSongs,
      options: request.options,
    );
    if (context.mounted) {
      _showSnack(
        context,
        path == null
            ? context.t('Export cancelled')
            : context.t('Songs exported'),
      );
    }
  }

  Future<BackupStorageTarget?> _chooseBackupTarget(BuildContext context) {
    return showModalBottomSheet<BackupStorageTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(context.t('Save locally')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(context.t('Save to Google Drive')),
              subtitle: Text(context.t('Choose Drive in the save picker')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.drive),
            ),
          ],
        ),
      ),
    );
  }

  Future<BackupStorageTarget?> _chooseRestoreSource(BuildContext context) {
    return showModalBottomSheet<BackupStorageTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(context.t('From local file')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(context.t('From Google Drive')),
              subtitle: Text(context.t('Choose Drive in the file picker')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.drive),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplaySettingsScreen extends StatelessWidget {
  const _DisplaySettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Display configuration'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SongCardFieldsSection(),
          SizedBox(height: 12),
          _PlaylistItemFieldsSection(),
          SizedBox(height: 12),
          _IncompleteSongStyleSection(),
          SizedBox(height: 12),
          _LyricsDisplaySection(),
        ],
      ),
    );
  }
}

class _IncompleteSongStyleSection extends StatelessWidget {
  const _IncompleteSongStyleSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.task_alt_outlined),
        title: Text(context.t('Non-ready songs')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.t('Incomplete song color')),
          ),
          const SizedBox(height: 8),
          SegmentedButton<IncompleteSongCardStyle>(
            segments: [
              for (final style in IncompleteSongCardStyle.values)
                ButtonSegment(
                  value: style,
                  label: Text(context.t(style.label)),
                ),
            ],
            selected: {settings.incompleteSongCardStyle},
            onSelectionChanged: (value) {
              settings.setIncompleteSongCardStyle(value.first);
            },
          ),
          if (settings.incompleteSongCardStyle !=
              IncompleteSongCardStyle.none) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(context.t('Color')),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in IncompleteSongCardColor.values)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: color.color),
                    label: Text(context.t(color.label)),
                    selected: settings.incompleteSongCardColor == color,
                    onSelected: (_) {
                      settings.setIncompleteSongCardColor(color);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LyricsDisplaySection extends StatelessWidget {
  const _LyricsDisplaySection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.article_outlined),
        title: Text(context.t('Lyrics display')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t('Lyrics font size'))),
              Text(settings.lyricsFontSize.round().toString()),
            ],
          ),
          Slider(
            value: settings.lyricsFontSize,
            min: 20,
            max: 44,
            divisions: 12,
            label: settings.lyricsFontSize.round().toString(),
            onChanged: settings.setLyricsFontSize,
          ),
        ],
      ),
    );
  }
}

class _BackupSettingsScreen extends StatelessWidget {
  const _BackupSettingsScreen({
    required this.onExportDatabase,
    required this.onExportFullBackup,
    required this.onRestoreDatabase,
    required this.onRestoreFullBackup,
    required this.onExportSongs,
  });

  final Future<void> Function(BuildContext context) onExportDatabase;
  final Future<void> Function(BuildContext context) onExportFullBackup;
  final Future<void> Function(BuildContext context) onRestoreDatabase;
  final Future<void> Function(BuildContext context) onRestoreFullBackup;
  final Future<void> Function(BuildContext context) onExportSongs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Backup & export'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(context.t('Database backup')),
                  subtitle:
                      Text(context.t('Songs, playlists, tags, and settings')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onExportDatabase(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(context.t('Full backup')),
                  subtitle: Text(context.t('Database and copied media files')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onExportFullBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: Text(context.t('Restore database')),
                  subtitle: Text(context.t('Restores database only')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onRestoreDatabase(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(context.t('Full restore')),
                  subtitle:
                      Text(context.t('Restores database and media files')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onRestoreFullBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.t('Export songs PDF')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onExportSongs(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCardFieldsSection extends StatelessWidget {
  const _SongCardFieldsSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final selected = settings.songCardFields;
    final hidden = SongCardField.values
        .where((field) => !selected.contains(field))
        .toList(growable: false);

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.view_agenda_outlined),
        title: Text(context.t('Song main card')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t('No fields selected')),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selected.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...selected];
                final item = next.removeAt(oldIndex);
                next.insert(newIndex, item);
                settings.setSongCardFields(next);
              },
              itemBuilder: (context, index) {
                final field = selected[index];
                return SwitchListTile(
                  key: ValueKey('song-card-field-${field.storageValue}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_iconForSongCardField(field)),
                  title: Text(context.t(field.label)),
                  value: true,
                  onChanged: (_) {
                    final next = [...selected]..remove(field);
                    settings.setSongCardFields(next);
                  },
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          if (hidden.isNotEmpty) ...[
            const Divider(),
            for (final field in hidden)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconForSongCardField(field)),
                title: Text(context.t(field.label)),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  settings.setSongCardFields([...selected, field]);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistItemFieldsSection extends StatelessWidget {
  const _PlaylistItemFieldsSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final selected = settings.playlistItemFields;
    final hidden = PlaylistItemField.values
        .where((field) => !selected.contains(field))
        .toList(growable: false);

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.queue_music_outlined),
        title: Text(context.t('Playlist items')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t('No fields selected')),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selected.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...selected];
                final item = next.removeAt(oldIndex);
                next.insert(newIndex, item);
                settings.setPlaylistItemFields(next);
              },
              itemBuilder: (context, index) {
                final field = selected[index];
                return SwitchListTile(
                  key: ValueKey('playlist-item-field-${field.storageValue}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_iconForPlaylistItemField(field)),
                  title: Text(context.t(field.label)),
                  value: true,
                  onChanged: (_) {
                    final next = [...selected]..remove(field);
                    settings.setPlaylistItemFields(next);
                  },
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          if (hidden.isNotEmpty) ...[
            const Divider(),
            for (final field in hidden)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconForPlaylistItemField(field)),
                title: Text(context.t(field.label)),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  settings.setPlaylistItemFields([...selected, field]);
                },
              ),
          ],
        ],
      ),
    );
  }
}

IconData _iconForSongCardField(SongCardField field) {
  return switch (field) {
    SongCardField.myKey => Icons.music_note,
    SongCardField.transpose => Icons.swap_vert,
    SongCardField.rhythm => Icons.timer_outlined,
    SongCardField.bpm => Icons.speed,
    SongCardField.quarterTone => Icons.tune,
    SongCardField.chords => Icons.piano_outlined,
    SongCardField.tags => Icons.sell_outlined,
    SongCardField.originalScale => Icons.stacked_line_chart_outlined,
    SongCardField.myScale => Icons.auto_graph_outlined,
    SongCardField.originalKey => Icons.key_outlined,
    SongCardField.notes => Icons.notes_outlined,
  };
}

IconData _iconForPlaylistItemField(PlaylistItemField field) {
  return switch (field) {
    PlaylistItemField.myKey => Icons.music_note,
    PlaylistItemField.transpose => Icons.swap_vert,
    PlaylistItemField.rhythm => Icons.timer_outlined,
    PlaylistItemField.bpm => Icons.speed,
    PlaylistItemField.quarterTone => Icons.tune,
    PlaylistItemField.chords => Icons.piano_outlined,
    PlaylistItemField.tags => Icons.sell_outlined,
    PlaylistItemField.originalScale => Icons.stacked_line_chart_outlined,
    PlaylistItemField.myScale => Icons.auto_graph_outlined,
    PlaylistItemField.originalKey => Icons.key_outlined,
    PlaylistItemField.notes => Icons.notes_outlined,
  };
}

class _SongExportDialog extends StatefulWidget {
  const _SongExportDialog({required this.songs});

  final List<Song> songs;

  @override
  State<_SongExportDialog> createState() => _SongExportDialogState();
}

class _SongExportDialogState extends State<_SongExportDialog> {
  final _selectedSongIds = <int>{};
  var _options = const SongExportOptions();

  @override
  void initState() {
    super.initState();
    _selectedSongIds.addAll(
      widget.songs.map((song) => song.id).whereType<int>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('Export songs')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t('Songs'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              for (final song in widget.songs) _songTile(song),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t('Include'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _optionTile('Title', _options.title, (value) {
                _options = _options.copyWith(title: value);
              }),
              _optionTile('Lyrics', _options.lyrics, (value) {
                _options = _options.copyWith(lyrics: value);
              }),
              _optionTile('Musical notes', _options.musicalNotes, (value) {
                _options = _options.copyWith(musicalNotes: value);
              }),
              _optionTile('Rhythm', _options.rhythm, (value) {
                _options = _options.copyWith(rhythm: value);
              }),
              _optionTile('Scale', _options.scale, (value) {
                _options = _options.copyWith(scale: value);
              }),
              _optionTile('Tempo', _options.tempo, (value) {
                _options = _options.copyWith(tempo: value);
              }),
              _optionTile('Chords', _options.chords, (value) {
                _options = _options.copyWith(chords: value);
              }),
              _optionTile('Notes', _options.notes, (value) {
                _options = _options.copyWith(notes: value);
              }),
              _optionTile('Quarter-toned keys', _options.quarterTones, (value) {
                _options = _options.copyWith(quarterTones: value);
              }),
              _optionTile('Tags', _options.tag, (value) {
                _options = _options.copyWith(tag: value);
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('Cancel')),
        ),
        FilledButton(
          onPressed: _selectedSongIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _SongExportRequest(
                      songIds: _selectedSongIds,
                      options: _options,
                    ),
                  ),
          child: Text(context.t('Export')),
        ),
      ],
    );
  }

  Widget _optionTile(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      value: value,
      title: Text(context.t(label)),
      onChanged: (checked) {
        setState(() => onChanged(checked ?? false));
      },
    );
  }

  Widget _songTile(Song song) {
    final songId = song.id;
    return CheckboxListTile(
      value: songId != null && _selectedSongIds.contains(songId),
      title: Text(song.name),
      onChanged: songId == null
          ? null
          : (checked) {
              setState(() {
                if (checked ?? false) {
                  _selectedSongIds.add(songId);
                } else {
                  _selectedSongIds.remove(songId);
                }
              });
            },
    );
  }
}

class _SongExportRequest {
  const _SongExportRequest({required this.songIds, required this.options});

  final Set<int> songIds;
  final SongExportOptions options;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
