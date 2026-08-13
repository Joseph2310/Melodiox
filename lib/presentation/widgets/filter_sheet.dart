import 'package:flutter/material.dart';

import '../../core/constants/music_keys.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_filter.dart';
import '../../domain/entities/tag.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.initialFilter,
    required this.tags,
    required this.songs,
    required this.scaleValues,
    required this.scaleTypes,
    required this.onApply,
    required this.onClear,
    super.key,
  });

  final SongFilter initialFilter;
  final List<Tag> tags;
  final List<Song> songs;
  final List<String> scaleValues;
  final List<String> scaleTypes;
  final ValueChanged<SongFilter> onApply;
  final VoidCallback onClear;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late bool _favoriteOnly;
  late Set<int> _tagIds;
  String? _myKey;
  String? _originalKey;
  String? _scale;
  String? _scaleType;
  String? _rhythm;
  String? _quarterTone;
  bool? _completed;
  bool? _hasAudio;
  bool? _hasVideo;
  bool? _hasChordImages;
  bool? _hasLyrics;
  bool? _hasNotes;
  late final TextEditingController _minBpmController;
  late final TextEditingController _maxBpmController;
  late final TextEditingController _transposeController;

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _favoriteOnly = filter.favoriteOnly;
    _tagIds = {...filter.tagIds};
    _myKey = filter.myKey;
    _originalKey = filter.originalKey;
    _scale = filter.scale;
    _scaleType = filter.scaleType;
    _rhythm = filter.rhythm;
    _quarterTone = filter.quarterTone;
    _completed = filter.completed;
    _hasAudio = filter.hasAudio;
    _hasVideo = filter.hasVideo;
    _hasChordImages = filter.hasChordImages;
    _hasLyrics = filter.hasLyrics;
    _hasNotes = filter.hasNotes;
    _minBpmController = TextEditingController(
      text: filter.minBpm?.toString() ?? '',
    );
    _maxBpmController = TextEditingController(
      text: filter.maxBpm?.toString() ?? '',
    );
    _transposeController = TextEditingController(
      text: filter.transposeValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minBpmController.dispose();
    _maxBpmController.dispose();
    _transposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rhythms = widget.songs
        .expand(
          (song) => [
            if (song.primaryRhythm != null) song.primaryRhythm!,
            for (final item in song.rhythmItems)
              ...item.rhythms.map((rhythm) => rhythm.rhythmName),
          ],
        )
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Filters'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  widget.onClear();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.filter_alt_off),
                label: Text(context.t('Clear')),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('Favorites')),
            value: _favoriteOnly,
            onChanged: (value) => setState(() => _favoriteOnly = value),
          ),
          _PresenceDropdown(
            label: 'Ready',
            value: _completed,
            onChanged: (value) => setState(() => _completed = value),
          ),
          const SizedBox(height: 8),
          _TagFilterField(
            tags: widget.tags,
            selectedIds: _tagIds,
            onChanged: (value) => setState(() => _tagIds = value),
          ),
          _StringDropdown(
            label: 'My key',
            value: _myKey,
            values: MusicKeys.values,
            onChanged: (value) => setState(() => _myKey = value),
          ),
          _StringDropdown(
            label: 'Original key',
            value: _originalKey,
            values: MusicKeys.values,
            onChanged: (value) => setState(() => _originalKey = value),
          ),
          _StringDropdown(
            label: 'Scale',
            value: _scale,
            values: widget.scaleValues,
            onChanged: (value) => setState(() => _scale = value),
          ),
          _StringDropdown(
            label: 'Scale type',
            value: _scaleType,
            values: widget.scaleTypes,
            onChanged: (value) => setState(() => _scaleType = value),
          ),
          _StringDropdown(
            label: 'Rhythm',
            value: _rhythm,
            values: rhythms,
            onChanged: (value) => setState(() => _rhythm = value),
          ),
          _StringDropdown(
            label: 'Quarter tone',
            value: _quarterTone,
            values: MusicKeys.quarterToneValues,
            onChanged: (value) => setState(() => _quarterTone = value),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minBpmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('Min BPM')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxBpmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('Max BPM')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transposeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.t('Transpose')),
          ),
          const SizedBox(height: 12),
          _PresenceDropdown(
            label: 'Audio',
            value: _hasAudio,
            onChanged: (value) => setState(() => _hasAudio = value),
          ),
          _PresenceDropdown(
            label: 'Video',
            value: _hasVideo,
            onChanged: (value) => setState(() => _hasVideo = value),
          ),
          _PresenceDropdown(
            label: 'Chord images',
            value: _hasChordImages,
            onChanged: (value) => setState(() => _hasChordImages = value),
          ),
          _PresenceDropdown(
            label: 'Lyrics',
            value: _hasLyrics,
            onChanged: (value) => setState(() => _hasLyrics = value),
          ),
          _PresenceDropdown(
            label: 'Notes',
            value: _hasNotes,
            onChanged: (value) => setState(() => _hasNotes = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: Text(context.t('Apply')),
          ),
        ],
      ),
    );
  }

  void _apply() {
    widget.onApply(
      SongFilter(
        favoriteOnly: _favoriteOnly,
        tagIds: _tagIds,
        myKey: _myKey,
        originalKey: _originalKey,
        scale: _scale,
        scaleType: _scaleType,
        rhythm: _rhythm,
        minBpm: int.tryParse(_minBpmController.text.trim()),
        maxBpm: int.tryParse(_maxBpmController.text.trim()),
        transposeValue: int.tryParse(_transposeController.text.trim()),
        quarterTone: _quarterTone,
        completed: _completed,
        hasAudio: _hasAudio,
        hasVideo: _hasVideo,
        hasChordImages: _hasChordImages,
        hasLyrics: _hasLyrics,
        hasNotes: _hasNotes,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _TagFilterField extends StatelessWidget {
  const _TagFilterField({
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<Tag> tags;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedTags = tags
        .where((tag) => tag.id != null && selectedIds.contains(tag.id))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _selectTags(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.t('Tags'),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: selectedTags.isEmpty
              ? Text(context.t('Any'))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in selectedTags) Chip(label: Text(tag.name)),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _selectTags(BuildContext context) async {
    final selected = {...selectedIds};
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableTags = tags.where((tag) => tag.id != null).toList();
          return AlertDialog(
            title: Text(context.t('Tags')),
            content: SizedBox(
              width: double.maxFinite,
              child: availableTags.isEmpty
                  ? Text(context.t('No tags available'))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final tag in availableTags)
                          CheckboxListTile(
                            value: selected.contains(tag.id),
                            title: Text(tag.name),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked ?? false) {
                                  selected.add(tag.id!);
                                } else {
                                  selected.remove(tag.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(<int>{}),
                child: Text(context.t('Clear')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selected),
                child: Text(context.t('Apply')),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }
}

class _Dropdown<T extends Object> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> values;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        decoration: InputDecoration(labelText: context.t(label)),
        items: [
          DropdownMenuItem<T?>(child: Text(context.t('Any'))),
          ...values.entries.map(
            (entry) => DropdownMenuItem<T?>(
              value: entry.key,
              child: Text(entry.value),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final mergedValues = [
      if (value != null && !values.contains(value)) value!,
      ...values,
    ];
    return _Dropdown<String>(
      label: label,
      value: value,
      values: {for (final item in mergedValues) item: item},
      onChanged: onChanged,
    );
  }
}

class _PresenceDropdown extends StatelessWidget {
  const _PresenceDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<bool?>(
        initialValue: value,
        decoration: InputDecoration(labelText: context.t(label)),
        items: [
          DropdownMenuItem<bool?>(child: Text(context.t('Any'))),
          DropdownMenuItem<bool?>(value: true, child: Text(context.t('Yes'))),
          DropdownMenuItem<bool?>(value: false, child: Text(context.t('No'))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
