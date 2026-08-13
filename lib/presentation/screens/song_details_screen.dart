import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/bidi_text.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/musical_scale.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_chord_item.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../providers/library_provider.dart';
import '../widgets/media_section.dart';
import '../widgets/tutorial_media.dart';
import 'chord_tutorials_screen.dart';
import 'lyrics_library_screen.dart';
import 'scales_screen.dart';
import 'song_form_screen.dart';

class SongDetailsScreen extends StatelessWidget {
  const SongDetailsScreen({required this.songId, super.key});

  final int songId;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final song = library.songById(songId);
        if (song == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.music_off_outlined,
              title: context.t('Song not found'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(song.name),
            actions: [
              IconButton(
                tooltip: context.t(
                  song.favorite ? 'Remove favorite' : 'Add favorite',
                ),
                onPressed: () => library.toggleFavorite(song),
                icon: Icon(song.favorite ? Icons.star : Icons.star_border),
              ),
              IconButton(
                tooltip: context.t('Edit'),
                onPressed: () => _editSong(context, song),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: context.t('Add to playlists'),
                onPressed: () => _addToPlaylists(context, library, song),
                icon: const Icon(Icons.playlist_add),
              ),
              IconButton(
                tooltip: context.t('Delete'),
                onPressed: () => _deleteSong(context, library, song),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(song: song),
              _InfoSection(song: song, scales: library.scales),
              _RhythmDetailsSection(song: song),
              _LyricsExpansion(text: song.lyrics),
              _TextExpansion(
                title: 'Notes',
                icon: Icons.notes_outlined,
                text: song.noteItems.isEmpty ? song.notes : null,
                notes: song.noteItems,
              ),
              _SongChordsSection(song: song),
              ExpansionTile(
                leading: const Icon(Icons.graphic_eq_outlined),
                title: Text(context.t('Melody Images')),
                children: [
                  MediaSection(media: song.media, type: MediaType.melodyImage),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(context.t('Performance Video')),
                children: [
                  MediaSection(
                    media: song.media,
                    type: MediaType.performanceVideo,
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: Text(context.t('Audio')),
                children: [
                  MediaSection(media: song.media, type: MediaType.songAudio),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(context.t('Vocals Only')),
                children: [
                  MediaSection(media: song.media, type: MediaType.vocalAudio),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSong(BuildContext context, Song song) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SongFormScreen(song: song)));
  }

  Future<void> _deleteSong(
    BuildContext context,
    LibraryProvider library,
    Song song,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete song'),
      message: context.t(
        'Delete "{name}" from the library?',
        {'name': song.name},
      ),
    );
    if (!confirmed || song.id == null) {
      return;
    }
    final deleted = await library.deleteSong(song.id!);
    if (!context.mounted) {
      return;
    }
    if (deleted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('Song deleted'))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(library.errorMessage ?? context.t('Delete failed')),
        ),
      );
    }
  }

  Future<void> _addToPlaylists(
    BuildContext context,
    LibraryProvider library,
    Song song,
  ) async {
    final songId = song.id;
    if (songId == null) {
      return;
    }
    final selected = <int>{
      for (final playlist in library.playlists)
        if (playlist.id != null && playlist.songIds.contains(songId))
          playlist.id!,
    };
    final result = await showDialog<_PlaylistSelectionResult>(
      context: context,
      builder: (context) => _PlaylistSelectionDialog(
        songName: song.name,
        playlists: library.playlists,
        initialSelectedIds: selected,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final activeLibrary = context.read<LibraryProvider>();
    final playlistIds = {...result.selectedPlaylistIds};
    if (result.newPlaylistName != null) {
      final name = result.newPlaylistName!.trim();
      if (name.isNotEmpty) {
        await activeLibrary.savePlaylist(
          Playlist(playlistName: name, songIds: const []),
        );
        final created = activeLibrary.playlists.where(
          (playlist) =>
              playlist.playlistName.toLowerCase() == name.toLowerCase(),
        );
        if (created.isNotEmpty && created.first.id != null) {
          playlistIds.add(created.first.id!);
        }
      }
    }

    var ok = true;
    for (final playlist in activeLibrary.playlists) {
      final playlistId = playlist.id;
      if (playlistId == null) {
        continue;
      }
      final shouldContain = playlistIds.contains(playlistId);
      final alreadyContains = playlist.songIds.contains(songId);
      if (shouldContain && !alreadyContains) {
        ok = await activeLibrary.addSongToPlaylist(playlistId, songId) && ok;
      }
      if (!shouldContain && alreadyContains) {
        ok = await activeLibrary.removeSongFromPlaylist(playlistId, songId) &&
            ok;
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? context.t('Playlists updated')
                : activeLibrary.errorMessage ?? context.t('Update failed'),
          ),
        ),
      );
    }
  }
}

class _SongChordsSection extends StatelessWidget {
  const _SongChordsSection({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final chordItems = song.chordItems;
    final legacyChordImages = song.media
        .where((media) => media.mediaType == MediaType.chordImage)
        .toList(growable: false);
    final hasLegacySelectedChords = song.chordTutorials.isNotEmpty;
    final hasLegacyChordImages =
        legacyChordImages.any((media) => media.hasSource);
    final hasChordItems = chordItems.isNotEmpty;

    return ExpansionTile(
      leading: const Icon(Icons.piano_outlined),
      title: Text(context.t('Chords')),
      children: [
        if (!hasChordItems && !hasLegacySelectedChords && !hasLegacyChordImages)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.t('No items')),
            ),
          ),
        if (hasChordItems)
          for (var index = 0; index < chordItems.length; index++)
            _SongChordItemView(item: chordItems[index], index: index),
        if (!hasChordItems && hasLegacySelectedChords) ...[
          const _SectionLabel(label: 'Selected chords'),
          for (final chord in song.chordTutorials)
            _ChordTutorialTile(chord: chord),
        ],
        if (!hasChordItems && hasLegacyChordImages) ...[
          const _SectionLabel(label: 'Chord images'),
          MediaSection(media: legacyChordImages, type: MediaType.chordImage),
        ],
      ],
    );
  }
}

class _SongChordItemView extends StatelessWidget {
  const _SongChordItemView({required this.item, required this.index});

  final SongChordItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final title = context.t('Chord Item {index}', {'index': index + 1});
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (item.chords.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final selection in item.chords)
                  _ChordSelectionTile(selection: selection),
              ],
              if (item.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                MediaSection(media: item.images, type: MediaType.chordImage),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChordSelectionTile extends StatelessWidget {
  const _ChordSelectionTile({required this.selection});

  final SongChordSelection selection;

  @override
  Widget build(BuildContext context) {
    final chord = selection.chord;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: TutorialThumbnail(
        path: selection.imagePath,
        fallbackIcon: Icons.piano_outlined,
      ),
      title: Text(selection.displayName),
      subtitle: Text(
        selection.keys,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChordTutorialDetailsScreen(
            tutorialId: chord.id,
            fallbackTutorial: chord,
          ),
        ),
      ),
    );
  }
}

class _ChordTutorialTile extends StatelessWidget {
  const _ChordTutorialTile({required this.chord});

  final ChordTutorial chord;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: TutorialThumbnail(
        path: chord.imagePath,
        fallbackIcon: Icons.piano_outlined,
      ),
      title: Text(chord.displayName),
      subtitle: Text(
        chord.keys,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChordTutorialDetailsScreen(
            tutorialId: chord.id,
            fallbackTutorial: chord,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.t(label),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _PlaylistSelectionDialog extends StatefulWidget {
  const _PlaylistSelectionDialog({
    required this.songName,
    required this.playlists,
    required this.initialSelectedIds,
  });

  final String songName;
  final List<Playlist> playlists;
  final Set<int> initialSelectedIds;

  @override
  State<_PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState extends State<_PlaylistSelectionDialog> {
  late final Set<int> _selectedIds = {...widget.initialSelectedIds};
  final _newPlaylistController = TextEditingController();

  @override
  void dispose() {
    _newPlaylistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('Add "{name}"', {'name': widget.songName})),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(context.t('No playlists yet')),
                )
              else
                for (final playlist in widget.playlists)
                  CheckboxListTile(
                    value: playlist.id != null &&
                        _selectedIds.contains(playlist.id),
                    title: Text(playlist.playlistName),
                    onChanged: playlist.id == null
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selectedIds.add(playlist.id!);
                              } else {
                                _selectedIds.remove(playlist.id);
                              }
                            });
                          },
                  ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPlaylistController,
                decoration: InputDecoration(
                  labelText: context.t('New playlist'),
                  prefixIcon: const Icon(Icons.add),
                ),
              ),
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
          onPressed: () => Navigator.of(context).pop(
            _PlaylistSelectionResult(
              selectedPlaylistIds: _selectedIds,
              newPlaylistName: _newPlaylistController.text.trim().isEmpty
                  ? null
                  : _newPlaylistController.text.trim(),
            ),
          ),
          child: Text(context.t('Save')),
        ),
      ],
    );
  }
}

class _PlaylistSelectionResult {
  const _PlaylistSelectionResult({
    required this.selectedPlaylistIds,
    this.newPlaylistName,
  });

  final Set<int> selectedPlaylistIds;
  final String? newPlaylistName;
}

class _Header extends StatelessWidget {
  const _Header({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in song.tags) Chip(label: Text(tag.name)),
              if (song.favorite)
                Chip(
                  avatar: const Icon(Icons.star, size: 18),
                  label: Text(context.t('Favorite')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.song, required this.scales});

  final Song song;
  final List<MusicalScale> scales;

  @override
  Widget build(BuildContext context) {
    final originalScale = _scaleFor(song.originalScale);
    final myScale = _scaleFor(song.myScale);
    final info = <_InfoItem>[
      _InfoItem('My Key', song.myStartingKey),
      _InfoItem('Transpose', _formatSignedInt(song.transposeValue)),
      if (song.hasQuarterTones)
        _InfoItem('Quarter Tone', song.quarterToneSummary),
      if (song.originalScale != null)
        _InfoItem(
          'Original Scale',
          song.originalScale!,
          onTap: originalScale == null
              ? null
              : () => _openScale(context, originalScale),
        ),
      if (song.myScale != null)
        _InfoItem(
          'My Scale',
          song.myScale!,
          onTap: myScale == null ? null : () => _openScale(context, myScale),
        ),
      if (song.originalStartingKey != null)
        _InfoItem('Original Key', song.originalStartingKey!),
      if (song.rhythmSummary.isNotEmpty)
        _InfoItem('Rhythm', song.rhythmSummary),
      if (song.bpm != null) _InfoItem('BPM', song.bpm.toString()),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final item in info) _InfoTile(item: item)],
      ),
    );
  }

  MusicalScale? _scaleFor(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    for (final scale in scales) {
      final displayName = scale.displayName.toLowerCase();
      final name = scale.name.trim().toLowerCase();
      if (name.isEmpty) {
        continue;
      }
      if (normalized == displayName ||
          normalized == name ||
          normalized.endsWith(' $name')) {
        return scale;
      }
    }
    return null;
  }

  void _openScale(BuildContext context, MusicalScale scale) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScaleDetailsScreen(
          scaleId: scale.id,
          fallbackScale: scale,
        ),
      ),
    );
  }
}

class _RhythmDetailsSection extends StatelessWidget {
  const _RhythmDetailsSection({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final items = song.rhythmItems
        .where((item) => item.rhythms.isNotEmpty)
        .toList(growable: false);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(context.t('Rhythm Details')),
      initiallyExpanded: true,
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index == 0
                        ? context.t(
                            'Primary: {value}',
                            {'value': items[index].summary},
                          )
                        : context.t(
                            'Item {index}: {value}',
                            {
                              'index': index + 1,
                              'value': items[index].summary,
                            },
                          ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rhythm in items[index].rhythms)
                        Chip(
                          avatar: const Icon(Icons.music_note, size: 18),
                          label: Text(
                            rhythm.section == null ||
                                    rhythm.section!.trim().isEmpty
                                ? rhythm.rhythmName
                                : '${rhythm.rhythmName} - ${rhythm.section}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value, {this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t(item.label), style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (item.onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: item.onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: item.onTap,
                child: content,
              ),
      ),
    );
  }
}

class _LyricsExpansion extends StatelessWidget {
  const _LyricsExpansion({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final slides = lyricsSlidesFromText(text);
    return ExpansionTile(
      leading: const Icon(Icons.article_outlined),
      title: Text(context.t('Lyrics')),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: slides.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: BidiText(
                    context.t('No {title}', {'title': context.t('Lyrics')}),
                  ),
                )
              : LyricsSlideViewer(
                  slides: slides,
                  height: 420,
                  compact: true,
                ),
        ),
      ],
    );
  }
}

class _TextExpansion extends StatelessWidget {
  const _TextExpansion({
    required this.title,
    required this.icon,
    required this.text,
    this.notes = const [],
  });

  final String title;
  final IconData icon;
  final String? text;
  final List<TutorialNote> notes;

  @override
  Widget build(BuildContext context) {
    final body = text == null || text!.trim().isEmpty
        ? context.t('No {title}', {'title': context.t(title)})
        : text!;
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(context.t(title)),
      children: [
        if (notes.isNotEmpty)
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BidiText(
                          context.t(note.displayTitle),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        BidiText(note.body),
                      ],
                    ),
                  ),
                ),
              ),
            )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: BidiText(body),
            ),
          ),
      ],
    );
  }
}

String _formatSignedInt(int value) {
  return value >= 0 ? '+$value' : value.toString();
}
