import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/song.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';

class SongCard extends StatelessWidget {
  const SongCard({
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    super.key,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final cardFields = settings.songCardFields;

    return Card(
      color: _cardColor(
        theme,
        selected: selected,
        completed: song.completed,
        incompleteStyle: settings.incompleteSongCardStyle,
        incompleteColor: settings.incompleteSongCardColor,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (value) =>
                          onSelectedChanged?.call(value ?? false),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      song.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!selectionMode)
                    IconButton(
                      tooltip: context.t(
                        song.favorite ? 'Remove favorite' : 'Add favorite',
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        context.read<LibraryProvider>().toggleFavorite(song);
                      },
                      icon: Icon(
                        song.favorite ? Icons.star : Icons.star_border,
                        color: song.favorite ? Colors.amber.shade700 : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final field in cardFields)
                    ..._chipsForField(field, song),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _chipsForField(SongCardField field, Song song) sync* {
    switch (field) {
      case SongCardField.myKey:
        yield _InfoChip(icon: Icons.music_note, label: song.myStartingKey);
      case SongCardField.transpose:
        yield _InfoChip(
          icon: Icons.swap_vert,
          label: _formatSignedInt(song.transposeValue),
        );
      case SongCardField.rhythm:
        if (song.rhythmSummary.isNotEmpty) {
          yield _InfoChip(
              icon: Icons.timer_outlined, label: song.rhythmSummary);
        }
      case SongCardField.bpm:
        if (song.bpm != null) {
          yield _InfoChip(icon: Icons.speed, label: '${song.bpm} BPM');
        }
      case SongCardField.quarterTone:
        if (song.hasQuarterTones) {
          yield _InfoChip(icon: Icons.tune, label: song.quarterToneSummary);
        }
      case SongCardField.chords:
        if (song.compactChordSummary.isNotEmpty) {
          yield _InfoChip(
            icon: Icons.piano_outlined,
            label: song.compactChordSummary,
          );
        }
      case SongCardField.tags:
        for (final tag in song.tags) {
          yield Chip(
            avatar: tag.color == null
                ? null
                : CircleAvatar(backgroundColor: Color(tag.color!)),
            label: Text(tag.name),
          );
        }
      case SongCardField.originalScale:
        if (song.originalScale != null) {
          yield _InfoChip(
            icon: Icons.stacked_line_chart_outlined,
            label: song.originalScale!,
          );
        }
      case SongCardField.myScale:
        if (song.myScale != null) {
          yield _InfoChip(
            icon: Icons.auto_graph_outlined,
            label: song.myScale!,
          );
        }
      case SongCardField.originalKey:
        if (song.originalStartingKey != null) {
          yield _InfoChip(
            icon: Icons.key_outlined,
            label: song.originalStartingKey!,
          );
        }
      case SongCardField.notes:
        if (song.notesSummary.trim().isNotEmpty) {
          yield _InfoChip(
            icon: Icons.notes_outlined,
            label: song.notesSummary.trim().split('\n').first,
          );
        }
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

Color? _cardColor(
  ThemeData theme, {
  required bool selected,
  required bool completed,
  required IncompleteSongCardStyle incompleteStyle,
  required IncompleteSongCardColor incompleteColor,
}) {
  final colors = theme.colorScheme;
  if (selected) {
    return colors.secondaryContainer;
  }
  if (completed || incompleteStyle == IncompleteSongCardStyle.none) {
    return null;
  }
  final alpha = switch (incompleteStyle) {
    IncompleteSongCardStyle.none => 0.0,
    IncompleteSongCardStyle.soft => 0.12,
    IncompleteSongCardStyle.strong => 0.24,
  };
  return Color.alphaBlend(
    incompleteColor.color.withValues(alpha: alpha),
    colors.surface,
  );
}

String _formatSignedInt(int value) {
  return value >= 0 ? '+$value' : value.toString();
}
