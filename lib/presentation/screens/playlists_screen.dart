import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/shell_navigation_scope.dart';
import 'song_details_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return Scaffold(
          appBar: AppBar(
            leading: ShellBackButton.leading(context),
            title: Text(context.t('Playlists')),
            actions: [
              IconButton(
                tooltip: context.t('Add playlist'),
                onPressed: () => _editPlaylist(context, library),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: library.playlists.isEmpty
              ? EmptyState(
                  icon: Icons.queue_music_outlined,
                  title: context.t('No playlists'),
                  action: FilledButton.icon(
                    onPressed: () => _editPlaylist(context, library),
                    icon: const Icon(Icons.add),
                    label: Text(context.t('Create playlist')),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: library.playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final playlist = library.playlists[index];
                    return _PlaylistCard(playlist: playlist);
                  },
                ),
        );
      },
    );
  }

  static Future<void> _editPlaylist(
    BuildContext context,
    LibraryProvider library, {
    Playlist? playlist,
  }) async {
    final controller = TextEditingController(
      text: playlist?.playlistName ?? '',
    );
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.t(playlist == null ? 'New playlist' : 'Rename playlist'),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: context.t('Playlist Name')),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(context.t('Save')),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty || !context.mounted) {
        return;
      }
      final saved = await library.savePlaylist(
        Playlist(
          id: playlist?.id,
          playlistName: name,
          songIds: playlist?.songIds ?? const [],
        ),
      );
      if (context.mounted) {
        _showSnack(
          context,
          saved
              ? context.t('Playlist saved')
              : library.errorMessage ?? context.t('Save failed'),
        );
      }
    } finally {
      controller.dispose();
    }
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final playlistFields = context.watch<SettingsProvider>().playlistItemFields;
    final songs = library.songsForPlaylist(playlist);

    return Card(
      child: ExpansionTile(
        title: Text(playlist.playlistName),
        subtitle: Text(context.t('{count} songs', {'count': songs.length})),
        leading: const Icon(Icons.queue_music),
        trailing: PopupMenuButton<_PlaylistAction>(
          onSelected: (action) => _handleAction(context, library, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _PlaylistAction.addSong,
              child: ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(context.t('Add songs')),
              ),
            ),
            PopupMenuItem(
              value: _PlaylistAction.rename,
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: Text(context.t('Rename')),
              ),
            ),
            PopupMenuItem(
              value: _PlaylistAction.delete,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.t('Delete')),
              ),
            ),
          ],
        ),
        children: [
          if (songs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.t('No songs added')),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: songs.length,
              onReorderItem: (oldIndex, newIndex) {
                context.read<LibraryProvider>().reorderPlaylist(
                      playlist,
                      oldIndex,
                      newIndex,
                    );
              },
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  key: ValueKey('playlist-${playlist.id}-song-${song.id}'),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: IconButton(
                      tooltip: context.t('Reorder'),
                      onPressed: () {},
                      icon: const Icon(Icons.drag_handle),
                    ),
                  ),
                  title: Text(song.name),
                  subtitle: playlistFields.isEmpty
                      ? null
                      : _PlaylistSongDetails(
                          song: song,
                          fields: playlistFields,
                        ),
                  onTap: () => _openSong(context, song),
                  trailing: IconButton(
                    tooltip: context.t('Remove'),
                    onPressed: () => _removeSong(context, library, song),
                    icon: const Icon(Icons.close),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addSongs(context, library),
                icon: const Icon(Icons.playlist_add),
                label: Text(context.t('Add songs')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    LibraryProvider library,
    _PlaylistAction action,
  ) async {
    switch (action) {
      case _PlaylistAction.addSong:
        await _addSongs(context, library);
        return;
      case _PlaylistAction.rename:
        if (context.mounted) {
          await PlaylistsScreen._editPlaylist(
            context,
            library,
            playlist: playlist,
          );
        }
        return;
      case _PlaylistAction.delete:
        if (!context.mounted) {
          return;
        }
        final confirmed = await confirmDialog(
          context,
          title: context.t('Delete playlist'),
          message: context.t(
            'Delete "{name}"?',
            {'name': playlist.playlistName},
          ),
        );
        if (confirmed && playlist.id != null) {
          final deleted = await library.deletePlaylist(playlist.id!);
          if (context.mounted) {
            _showSnack(
              context,
              deleted
                  ? context.t('Playlist deleted')
                  : library.errorMessage ?? context.t('Delete failed'),
            );
          }
        }
        return;
    }
  }

  Future<void> _addSongs(BuildContext context, LibraryProvider library) async {
    final playlistId = playlist.id;
    if (playlistId == null) {
      return;
    }
    final available = library.songs
        .where((song) => song.id != null && !playlist.songIds.contains(song.id))
        .toList();
    final selected = <int>{};
    final searchController = TextEditingController();
    Set<int>? result;
    try {
      result = await showDialog<Set<int>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? available
                : available
                    .where(
                      (song) =>
                          song.name.toLowerCase().contains(query) ||
                          song.myStartingKey.toLowerCase().contains(query) ||
                          song.rhythmSummary.toLowerCase().contains(query),
                    )
                    .toList();
            return AlertDialog(
              title: Text(context.t('Add songs')),
              content: SizedBox(
                width: double.maxFinite,
                child: available.isEmpty
                    ? Text(context.t('All songs are already in this playlist'))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: context.t('Search songs'),
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: visible.isEmpty
                                ? Text(context.t('No matching songs'))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: visible.length,
                                    itemBuilder: (context, index) {
                                      final song = visible[index];
                                      return CheckboxListTile(
                                        value: selected.contains(song.id),
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (value ?? false) {
                                              selected.add(song.id!);
                                            } else {
                                              selected.remove(song.id);
                                            }
                                          });
                                        },
                                        title: Text(song.name),
                                        subtitle: Text(song.myStartingKey),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t('Cancel')),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(selected),
                  child: Text(context.t('Add')),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }

    if (result == null || result.isEmpty) {
      return;
    }
    var ok = true;
    for (final songId in result) {
      ok = await library.addSongToPlaylist(playlistId, songId) && ok;
    }
    if (context.mounted) {
      _showSnack(
        context,
        ok
            ? context.t('Songs added')
            : library.errorMessage ?? context.t('Add failed'),
      );
    }
  }

  Future<void> _removeSong(
    BuildContext context,
    LibraryProvider library,
    Song song,
  ) async {
    if (playlist.id == null || song.id == null) {
      return;
    }
    final removed = await library.removeSongFromPlaylist(
      playlist.id!,
      song.id!,
    );
    if (context.mounted) {
      _showSnack(
        context,
        removed
            ? context.t('Song removed')
            : library.errorMessage ?? context.t('Remove failed'),
      );
    }
  }

  void _openSong(BuildContext context, Song song) {
    final id = song.id;
    if (id == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SongDetailsScreen(songId: id)),
    );
  }
}

enum _PlaylistAction { addSong, rename, delete }

class _PlaylistSongDetails extends StatelessWidget {
  const _PlaylistSongDetails({required this.song, required this.fields});

  final Song song;
  final List<PlaylistItemField> fields;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final field in fields) ..._chipsForField(context, field, song),
    ];
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Iterable<Widget> _chipsForField(
    BuildContext context,
    PlaylistItemField field,
    Song song,
  ) sync* {
    switch (field) {
      case PlaylistItemField.myKey:
        yield _PlaylistInfoChip(
            icon: Icons.music_note, label: song.myStartingKey);
      case PlaylistItemField.transpose:
        yield _PlaylistInfoChip(
          icon: Icons.swap_vert,
          label: _formatSignedInt(song.transposeValue),
        );
      case PlaylistItemField.rhythm:
        if (song.rhythmSummary.isNotEmpty) {
          yield _PlaylistInfoChip(
            icon: Icons.timer_outlined,
            label: song.rhythmSummary,
          );
        }
      case PlaylistItemField.bpm:
        if (song.bpm != null) {
          yield _PlaylistInfoChip(icon: Icons.speed, label: '${song.bpm} BPM');
        }
      case PlaylistItemField.quarterTone:
        if (song.hasQuarterTones) {
          yield _PlaylistInfoChip(
              icon: Icons.tune, label: song.quarterToneSummary);
        }
      case PlaylistItemField.chords:
        if (song.compactChordSummary.isNotEmpty) {
          yield _PlaylistInfoChip(
            icon: Icons.piano_outlined,
            label: song.compactChordSummary,
          );
        }
      case PlaylistItemField.tags:
        for (final tag in song.tags) {
          yield Chip(
            avatar: tag.color == null
                ? const Icon(Icons.sell_outlined, size: 16)
                : CircleAvatar(backgroundColor: Color(tag.color!)),
            label: Text(tag.name),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }
      case PlaylistItemField.originalScale:
        if (song.originalScale != null) {
          yield _PlaylistInfoChip(
            icon: Icons.stacked_line_chart_outlined,
            label: song.originalScale!,
          );
        }
      case PlaylistItemField.myScale:
        if (song.myScale != null) {
          yield _PlaylistInfoChip(
            icon: Icons.auto_graph_outlined,
            label: song.myScale!,
          );
        }
      case PlaylistItemField.originalKey:
        if (song.originalStartingKey != null) {
          yield _PlaylistInfoChip(
            icon: Icons.key_outlined,
            label: song.originalStartingKey!,
          );
        }
      case PlaylistItemField.notes:
        if (song.notesSummary.trim().isNotEmpty) {
          yield _PlaylistInfoChip(
            icon: Icons.notes_outlined,
            label: song.notesSummary.trim().split('\n').first,
          );
        }
    }
  }
}

class _PlaylistInfoChip extends StatelessWidget {
  const _PlaylistInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _formatSignedInt(int value) {
  return value >= 0 ? '+$value' : value.toString();
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
