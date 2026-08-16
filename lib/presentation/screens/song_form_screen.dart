import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/media_types.dart';
import '../../core/constants/music_keys.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/song_validation.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/lyrics_library_entry.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/musical_scale.dart';
import '../../domain/entities/rhythm.dart';
import '../../domain/entities/rhythm_item.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_chord_item.dart';
import '../../domain/entities/tag.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../services/media_storage_service.dart';
import '../providers/library_provider.dart';
import '../widgets/media_form_section.dart';
import '../widgets/tutorial_fields.dart';
import '../widgets/tutorial_media.dart';
import 'lyrics_library_screen.dart';

class SongFormScreen extends StatefulWidget {
  const SongFormScreen({this.song, super.key});

  final Song? song;

  @override
  State<SongFormScreen> createState() => _SongFormScreenState();
}

class _SongFormScreenState extends State<SongFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _transposeController;
  late final TextEditingController _lyricsController;

  late String _myStartingKey;
  String? _originalScale;
  String? _myScale;
  String? _originalStartingKey;
  late List<Tag> _tags;
  late bool _favorite;
  late bool _completed;
  late List<String> _quarterTones;
  late List<RhythmItem> _rhythmItems;
  late List<SongChordItem> _chordItems;
  late List<TutorialNote> _noteItems;
  late List<MediaItem> _media;
  var _isSaving = false;

  bool get _isEditing => widget.song != null;

  @override
  void initState() {
    super.initState();
    final song = widget.song;
    _nameController = TextEditingController(text: song?.name ?? '');
    _transposeController = TextEditingController(
      text: _formatSignedInt(song?.transposeValue ?? 0),
    );
    _lyricsController = TextEditingController(text: song?.lyrics ?? '');
    _myStartingKey = song?.myStartingKey ?? MusicKeys.values.first;
    _originalScale = song?.originalScale;
    _myScale = song?.myScale;
    _originalStartingKey = song?.originalStartingKey;
    _tags = [...(song?.tags ?? const [])];
    _favorite = song?.favorite ?? false;
    _completed = song?.completed ?? false;
    _quarterTones = [...(song?.quarterTones ?? const [])];
    _rhythmItems = [...(song?.rhythmItems ?? const [])];
    _noteItems = _initialNoteItems(song);
    _chordItems = _initialChordItems(song);
    _media = [
      for (final item in song?.media ?? const <MediaItem>[])
        if (item.mediaType != MediaType.chordImage) item,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _transposeController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  List<TutorialNote> _initialNoteItems(Song? song) {
    final items = [...(song?.noteItems ?? const <TutorialNote>[])];
    final legacyNotes = song?.notes?.trim();
    if (items.isEmpty && legacyNotes != null && legacyNotes.isNotEmpty) {
      items.add(TutorialNote(body: legacyNotes));
    }
    return items;
  }

  List<SongChordItem> _initialChordItems(Song? song) {
    final items = [...(song?.chordItems ?? const <SongChordItem>[])];
    if (items.isNotEmpty || song == null) {
      return items;
    }

    final chordImages = song.media
        .where((item) => item.mediaType == MediaType.chordImage)
        .toList(growable: false);
    if (song.chordTutorials.isEmpty && chordImages.isEmpty) {
      return items;
    }
    return [
      SongChordItem(
        chords: [
          for (final chord in song.chordTutorials)
            SongChordSelection(chord: chord),
        ],
        images: chordImages,
      ),
    ];
  }

  Widget _buildTransposeField() {
    return Row(
      children: [
        SizedBox.square(
          dimension: 48,
          child: IconButton.filledTonal(
            tooltip: context.t('Decrease transpose'),
            onPressed: () => _stepTranspose(-1),
            icon: const Icon(Icons.remove),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _transposeController,
            decoration: InputDecoration(
              labelText: context.t('Transpose Value'),
              prefixIcon: const Icon(Icons.swap_vert),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onEditingComplete: _normalizeTransposeText,
            onFieldSubmitted: (_) => _normalizeTransposeText(),
            validator: (value) =>
                SongValidation.requiredInt(value, context.t('Transpose')),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 48,
          child: IconButton.filledTonal(
            tooltip: context.t('Increase transpose'),
            onPressed: () => _stepTranspose(1),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _stepTranspose(int delta) {
    final next = _currentTransposeValue() + delta;
    _transposeController.text = _formatSignedInt(next);
  }

  void _normalizeTransposeText() {
    final parsed = int.tryParse(_transposeController.text.trim());
    if (parsed == null) {
      return;
    }
    _transposeController.text = _formatSignedInt(parsed);
  }

  int _currentTransposeValue() {
    return int.tryParse(_transposeController.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final scaleValues =
        library.scales.map((scale) => scale.displayName).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(_isEditing ? 'Edit Song' : 'Add Song')),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(context.t('Save')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.t('Song Name'),
                prefixIcon: const Icon(Icons.library_music_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  SongValidation.requiredText(value, context.t('Song name')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _myStartingKey,
              decoration: InputDecoration(
                labelText: context.t('My Starting Key'),
                prefixIcon: const Icon(Icons.music_note),
              ),
              items: [
                for (final key in MusicKeys.values)
                  DropdownMenuItem(value: key, child: Text(key)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _myStartingKey = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildTransposeField(),
            const SizedBox(height: 12),
            _QuarterTonePicker(
              values: _quarterTones,
              onChanged: (values) => setState(() => _quarterTones = values),
            ),
            const SizedBox(height: 12),
            _OptionalFields(
              originalScale: _originalScale,
              myScale: _myScale,
              scaleValues: scaleValues,
              originalStartingKey: _originalStartingKey,
              onOriginalScaleChanged: (value) =>
                  setState(() => _originalScale = value),
              onMyScaleChanged: (value) => setState(() => _myScale = value),
              onOriginalStartingKeyChanged: (value) {
                setState(() => _originalStartingKey = value);
              },
            ),
            const SizedBox(height: 12),
            _MultiSelectField<Tag>(
              label: 'Tags',
              icon: Icons.sell_outlined,
              values: library.tags,
              selectedValues: _tags,
              valueLabel: (tag) => tag.name,
              emptyLabel: 'No tags selected',
              dialogTitle: 'Select tags',
              onChanged: (values) => setState(() => _tags = values),
            ),
            const SizedBox(height: 12),
            _SongChordItemsEditor(
              availableChords: library.chordTutorials,
              availableScales: library.scales,
              originalScale: _originalScale,
              myScale: _myScale,
              chordItems: _chordItems,
              onChanged: (items) => setState(() => _chordItems = items),
              onPickImage: _pickChordImage,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _favorite ? Icons.star : Icons.star_border,
              ),
              title: Text(context.t('Favorite')),
              value: _favorite,
              onChanged: (value) => setState(() => _favorite = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.task_alt_outlined),
              title: Text(context.t('Ready')),
              subtitle: Text(context.t('Has enough information for use')),
              value: _completed,
              onChanged: (value) => setState(() => _completed = value),
            ),
            _RhythmItemEditor(
              availableRhythms: library.rhythms,
              rhythmItems: _rhythmItems,
              onChanged: (values) => setState(() => _rhythmItems = values),
              onCreate: () => _createRhythm(context),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('Lyrics'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _importLyrics,
                  icon: const Icon(Icons.search),
                  label: Text(context.t('Find in lyrics library')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lyricsController,
              minLines: 4,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: context.t('Lyrics'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TutorialNotesEditor(
              notes: _noteItems,
              onChanged: (items) => setState(() => _noteItems = items),
            ),
            const SizedBox(height: 12),
            MediaFormSection(
              media: _media,
              availableTypes: const [
                MediaType.melodyImage,
                MediaType.performanceVideo,
                MediaType.songAudio,
                MediaType.vocalAudio,
              ],
              onAdd: _addMedia,
              onRemove: (item) => setState(() => _media.remove(item)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMedia(MediaType initialType) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    var selectedType = initialType;
    var useExternalLink = false;
    String? selectedPath;

    try {
      final item = await showDialog<MediaItem>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.t('Add media')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<MediaType>(
                      initialValue: selectedType,
                      decoration: InputDecoration(labelText: context.t('Type')),
                      items: [
                        for (final type in MediaType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(context.t(type.label)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                            selectedPath = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration:
                          InputDecoration(labelText: context.t('Title')),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('External link')),
                      value: useExternalLink,
                      onChanged: (value) {
                        setDialogState(() {
                          useExternalLink = value;
                          selectedPath = null;
                        });
                      },
                    ),
                    if (useExternalLink)
                      TextField(
                        controller: urlController,
                        decoration:
                            InputDecoration(labelText: context.t('URL')),
                        keyboardType: TextInputType.url,
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final path = await _pickMediaPath(selectedType);
                              if (path != null) {
                                setDialogState(() => selectedPath = path);
                              }
                            },
                            icon: const Icon(Icons.attach_file),
                            label: Text(context.t('Choose file')),
                          ),
                          if (selectedPath != null)
                            Text(
                              selectedPath!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
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
                  onPressed: () {
                    final title = titleController.text.trim();
                    final url = urlController.text.trim();
                    final hasSource =
                        useExternalLink ? url.isNotEmpty : selectedPath != null;
                    if (title.isEmpty || !hasSource) {
                      return;
                    }
                    Navigator.of(context).pop(
                      MediaItem(
                        mediaType: selectedType,
                        title: title,
                        localPath: useExternalLink ? null : selectedPath,
                        externalUrl: useExternalLink ? url : null,
                        sortOrder: _media.length,
                      ),
                    );
                  },
                  child: Text(context.t('Add')),
                ),
              ],
            );
          },
        ),
      );
      if (item != null) {
        setState(() => _media.add(item));
      }
    } finally {
      titleController.dispose();
      urlController.dispose();
    }
  }

  Future<String?> _pickMediaPath(MediaType type) async {
    String? selectedPath;
    switch (type) {
      case MediaType.melodyImage:
      case MediaType.chordImage:
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        selectedPath = image?.path;
        break;
      case MediaType.performanceVideo:
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        selectedPath = video?.path;
        break;
      case MediaType.songAudio:
      case MediaType.vocalAudio:
        final result = await FilePicker.pickFiles(
          type: FileType.audio,
        );
        selectedPath = result?.files.single.path;
        break;
    }
    if (selectedPath == null) {
      return null;
    }
    return MediaStorageService().importFile(selectedPath, type);
  }

  Future<MediaItem?> _pickChordImage() async {
    final path = await _pickMediaPath(MediaType.chordImage);
    if (path == null) {
      return null;
    }
    return MediaItem(
      mediaType: MediaType.chordImage,
      title: 'Chord image',
      localPath: path,
    );
  }

  Future<void> _createRhythm(BuildContext context) async {
    final nameController = TextEditingController();
    final sectionController = TextEditingController();
    try {
      final rhythm = await showDialog<Rhythm>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t('New rhythm')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: context.t('Rhythm Name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectionController,
                decoration: InputDecoration(
                  labelText: context.t('Section'),
                  hintText: context.t('Annual, Kiahk, Holy Week'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  Rhythm(
                    rhythmName: name,
                    section: _blankToNull(sectionController.text),
                  ),
                );
              },
              child: Text(context.t('Save')),
            ),
          ],
        ),
      );
      if (rhythm == null || !context.mounted) {
        return;
      }
      final library = context.read<LibraryProvider>();
      final saved = await library.saveRhythm(rhythm);
      if (!context.mounted) {
        return;
      }
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(library.errorMessage ?? context.t('Save failed')),
          ),
        );
        return;
      }
      final created = library.rhythms.where(
        (item) =>
            item.rhythmName.toLowerCase() == rhythm.rhythmName.toLowerCase(),
      );
      if (created.isNotEmpty) {
        setState(() {
          _rhythmItems = [
            ..._rhythmItems,
            RhythmItem(
              position: _rhythmItems.length,
              rhythms: [created.first],
            ),
          ];
        });
      }
    } finally {
      nameController.dispose();
      sectionController.dispose();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final existing = widget.song;
    final rhythmItems = _normalizeRhythmItems();
    final noteItems = _normalizeNoteItems();
    final chordItems = _normalizeChordItems();
    final chordTutorials = _flattenChordTutorials(chordItems);
    final song = Song(
      id: existing?.id,
      name: _nameController.text.trim(),
      myStartingKey: _myStartingKey,
      transposeValue: int.parse(_transposeController.text.trim()),
      originalScale: _originalScale,
      myScale: _myScale,
      originalStartingKey: _originalStartingKey,
      bpm: rhythmItems.isEmpty ? existing?.bpm : rhythmItems.first.bpm,
      lyrics: _blankToNull(_lyricsController.text),
      notes: _blankToNull(
        noteItems.map((note) => note.body.trim()).join('\n\n'),
      ),
      primaryRhythm: rhythmItems.isEmpty ? null : rhythmItems.first.summary,
      tags: _tags,
      favorite: _favorite,
      completed: _completed,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      quarterTones: _quarterTones,
      rhythmItems: rhythmItems,
      chordTutorials: chordTutorials,
      chordItems: chordItems,
      noteItems: noteItems,
      media: [
        for (var i = 0; i < _media.length; i++)
          _media[i].copyWith(sortOrder: i),
      ],
    );

    final validationError = SongValidation.validateSong(song);
    if (validationError != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final saved = await context.read<LibraryProvider>().saveSong(song);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    final library = context.read<LibraryProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? context.t('Song saved')
              : library.errorMessage ?? context.t('Save failed'),
        ),
      ),
    );
    if (saved) {
      Navigator.of(context).pop();
    }
  }

  List<RhythmItem> _normalizeRhythmItems() {
    return [
      for (var i = 0; i < _rhythmItems.length; i++)
        if (_rhythmItems[i].rhythms.isNotEmpty)
          _rhythmItems[i].copyWith(position: i),
    ];
  }

  List<TutorialNote> _normalizeNoteItems() {
    return [
      for (final note in _noteItems)
        if (!note.isEmpty)
          TutorialNote(title: note.title.trim(), body: note.body.trim()),
    ];
  }

  List<SongChordItem> _normalizeChordItems() {
    return [
      for (var i = 0; i < _chordItems.length; i++)
        if (!_chordItems[i].isEmpty)
          _chordItems[i].copyWith(
            position: i,
            chords: [
              for (final selection in _chordItems[i].chords)
                if (selection.chord.id != null) selection,
            ],
            images: [
              for (var imageIndex = 0;
                  imageIndex < _chordItems[i].images.length;
                  imageIndex++)
                if (_chordItems[i].images[imageIndex].hasSource)
                  _chordItems[i].images[imageIndex].copyWith(
                        mediaType: MediaType.chordImage,
                        sortOrder: imageIndex,
                      ),
            ],
          ),
    ];
  }

  List<ChordTutorial> _flattenChordTutorials(List<SongChordItem> items) {
    final seen = <int>{};
    final chords = <ChordTutorial>[];
    for (final selection in items.expand((item) => item.chords)) {
      final id = selection.chord.id;
      if (id == null || !seen.add(id)) {
        continue;
      }
      chords.add(selection.chord);
    }
    return chords;
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _importLyrics() async {
    final selected = await Navigator.of(context).push<LyricsLibraryEntry>(
      MaterialPageRoute<LyricsLibraryEntry>(
        builder: (_) => LyricsLibraryPickerScreen(
          initialQuery: _nameController.text.trim(),
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _lyricsController.text = selected.songLyricsText;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('Lyrics imported'))),
    );
  }

  String _formatSignedInt(int value) {
    return value >= 0 ? '+$value' : value.toString();
  }
}

class _QuarterTonePicker extends StatelessWidget {
  const _QuarterTonePicker({required this.values, required this.onChanged});

  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _MultiSelectField<String>(
      label: 'Quarter-toned Keys',
      icon: Icons.tune,
      values: MusicKeys.quarterToneValues,
      selectedValues: values,
      valueLabel: (value) => value,
      emptyLabel: 'No quarter-toned keys',
      dialogTitle: 'Quarter-toned keys',
      onChanged: onChanged,
    );
  }
}

class _SongChordItemsEditor extends StatelessWidget {
  const _SongChordItemsEditor({
    required this.availableChords,
    required this.availableScales,
    required this.originalScale,
    required this.myScale,
    required this.chordItems,
    required this.onChanged,
    required this.onPickImage,
  });

  final List<ChordTutorial> availableChords;
  final List<MusicalScale> availableScales;
  final String? originalScale;
  final String? myScale;
  final List<SongChordItem> chordItems;
  final ValueChanged<List<SongChordItem>> onChanged;
  final Future<MediaItem?> Function() onPickImage;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.piano_outlined),
      title: Text(context.t('Chord Items')),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _editItem(context),
            icon: const Icon(Icons.add),
            label: Text(context.t('Add chord item')),
          ),
        ),
        const SizedBox(height: 8),
        if (chordItems.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.t('No chord items selected')),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chordItems.length,
            onReorderItem: (oldIndex, newIndex) {
              onChanged(_reposition(_reorder(chordItems, oldIndex, newIndex)));
            },
            itemBuilder: (context, index) {
              final item = chordItems[index];
              return ListTile(
                key: ValueKey('song-chord-item-$index-${item.summary}'),
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(
                  context.t('Chord Item {index}', {'index': index + 1}),
                ),
                subtitle: Text(
                  item.summary.isEmpty ? context.t('No items') : item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: IconButton(
                        tooltip: context.t('Reorder'),
                        onPressed: () {},
                        icon: const Icon(Icons.drag_handle),
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Edit'),
                      onPressed: () => _editItem(context, index: index),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: context.t('Remove'),
                      onPressed: () {
                        final next = [...chordItems]..removeAt(index);
                        onChanged(_reposition(next));
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _editItem(BuildContext context, {int? index}) async {
    final result = await showDialog<SongChordItem>(
      context: context,
      builder: (context) => _SongChordItemDialog(
        availableChords: availableChords,
        availableScales: availableScales,
        originalScale: originalScale,
        myScale: myScale,
        item: index == null ? null : chordItems[index],
        onPickImage: onPickImage,
      ),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    final next = [...chordItems];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(_reposition(next));
  }

  List<SongChordItem> _reposition(List<SongChordItem> items) {
    return [
      for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
    ];
  }
}

class _SongChordItemDialog extends StatefulWidget {
  const _SongChordItemDialog({
    required this.availableChords,
    required this.availableScales,
    required this.originalScale,
    required this.myScale,
    required this.onPickImage,
    this.item,
  });

  final List<ChordTutorial> availableChords;
  final List<MusicalScale> availableScales;
  final String? originalScale;
  final String? myScale;
  final SongChordItem? item;
  final Future<MediaItem?> Function() onPickImage;

  @override
  State<_SongChordItemDialog> createState() => _SongChordItemDialogState();
}

class _SongChordItemDialogState extends State<_SongChordItemDialog> {
  late List<SongChordSelection> _chords = [...?widget.item?.chords];
  late List<MediaItem> _images = [...?widget.item?.images];

  @override
  Widget build(BuildContext context) {
    final originalScale = _scaleFor(widget.originalScale);
    final myScale = _scaleFor(widget.myScale);
    return AlertDialog(
      title: Text(context.t('Chord Item')),
      content: SizedBox(
        width: double.maxFinite,
        height: 520,
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectChords,
                  icon: const Icon(Icons.piano_outlined),
                  label: Text(context.t('Select chords')),
                ),
                OutlinedButton.icon(
                  onPressed: _addImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.t('Add image')),
                ),
                OutlinedButton.icon(
                  onPressed: originalScale == null
                      ? null
                      : () => _importScaleChords(originalScale),
                  icon: const Icon(Icons.library_add_outlined),
                  label: Text(context.t('Import original scale')),
                ),
                OutlinedButton.icon(
                  onPressed: myScale == null
                      ? null
                      : () => _importScaleChords(myScale),
                  icon: const Icon(Icons.library_add_check_outlined),
                  label: Text(context.t('Import my scale')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DialogSectionTitle(
              icon: Icons.piano_outlined,
              label: context.t('Selected chords'),
            ),
            if (_chords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.t('No chords selected')),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _chords.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    _chords = _reorder(_chords, oldIndex, newIndex);
                  });
                },
                itemBuilder: (context, index) {
                  final selection = _chords[index];
                  return ListTile(
                    key: ValueKey(
                      'selected-chord-${selection.chord.id}-$index-${selection.inversionIndex}',
                    ),
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
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: IconButton(
                            tooltip: context.t('Reorder'),
                            onPressed: () {},
                            icon: const Icon(Icons.drag_handle),
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('Remove'),
                          onPressed: () {
                            setState(() => _chords.removeAt(index));
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            _DialogSectionTitle(
              icon: Icons.image_outlined,
              label: context.t('Chord images'),
            ),
            if (_images.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.t('No images')),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _images.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    _images = _reorder(_images, oldIndex, newIndex);
                  });
                },
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return ListTile(
                    key: ValueKey(
                      'song-chord-image-${image.localPath ?? image.externalUrl ?? index}',
                    ),
                    contentPadding: EdgeInsets.zero,
                    leading: TutorialThumbnail(
                      path: image.localPath,
                      fallbackIcon: Icons.image_outlined,
                    ),
                    title: Text(image.title),
                    subtitle: Text(
                      image.localPath ?? image.externalUrl ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: IconButton(
                            tooltip: context.t('Reorder'),
                            onPressed: () {},
                            icon: const Icon(Icons.drag_handle),
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('Remove'),
                          onPressed: () {
                            setState(() => _images.removeAt(index));
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  );
                },
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
          onPressed: _chords.isEmpty && _images.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    SongChordItem(chords: _chords, images: _images),
                  ),
          child: Text(context.t('Save')),
        ),
      ],
    );
  }

  Future<void> _selectChords() async {
    final result = await showDialog<List<SongChordSelection>>(
      context: context,
      builder: (context) => _ChordSelectionDialog(
        availableChords: widget.availableChords,
        selectedChords: _chords,
      ),
    );
    if (result != null) {
      setState(() => _chords = result);
    }
  }

  MusicalScale? _scaleFor(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    for (final scale in widget.availableScales) {
      if (scale.displayName.toLowerCase() == normalized &&
          scale.chordTutorials.isNotEmpty) {
        return scale;
      }
    }
    return null;
  }

  Future<void> _importScaleChords(MusicalScale scale) async {
    final result = await showDialog<List<ChordTutorial>>(
      context: context,
      builder: (context) => _ScaleChordImportDialog(scale: scale),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    setState(() {
      for (final chord in result) {
        final chordId = chord.id;
        final exists = _chords.any(
          (selection) => chordId != null
              ? selection.chord.id == chordId
              : selection.chord == chord,
        );
        if (!exists) {
          _chords.add(SongChordSelection(chord: chord));
        }
      }
    });
  }

  Future<void> _addImage() async {
    final image = await widget.onPickImage();
    if (image == null) {
      return;
    }
    setState(() {
      _images.add(
        image.copyWith(
          title: '${context.t('Chord image')} ${_images.length + 1}',
          sortOrder: _images.length,
        ),
      );
    });
  }
}

class _ScaleChordImportDialog extends StatefulWidget {
  const _ScaleChordImportDialog({required this.scale});

  final MusicalScale scale;

  @override
  State<_ScaleChordImportDialog> createState() =>
      _ScaleChordImportDialogState();
}

class _ScaleChordImportDialogState extends State<_ScaleChordImportDialog> {
  late final Set<ChordTutorial> _selected = {...widget.scale.chordTutorials};

  @override
  Widget build(BuildContext context) {
    final chords = widget.scale.chordTutorials;
    return AlertDialog(
      title: Text(
        context.t(
          'Import chords from {scale}',
          {'scale': widget.scale.displayName},
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: chords.isEmpty
            ? Center(child: Text(context.t('No chords selected')))
            : ListView.builder(
                itemCount: chords.length,
                itemBuilder: (context, index) {
                  final chord = chords[index];
                  return CheckboxListTile(
                    value: _selected.contains(chord),
                    secondary: TutorialThumbnail(
                      path: chord.imagePath,
                      fallbackIcon: Icons.piano_outlined,
                    ),
                    title: Text(chord.displayName),
                    subtitle: Text(
                      chord.keys,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selected.add(chord);
                        } else {
                          _selected.remove(chord);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('Cancel')),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                    for (final chord in chords)
                      if (_selected.contains(chord)) chord,
                  ]),
          child: Text(context.t('Import')),
        ),
      ],
    );
  }
}

class _ChordSelectionDialog extends StatefulWidget {
  const _ChordSelectionDialog({
    required this.availableChords,
    required this.selectedChords,
  });

  final List<ChordTutorial> availableChords;
  final List<SongChordSelection> selectedChords;

  @override
  State<_ChordSelectionDialog> createState() => _ChordSelectionDialogState();
}

class _ChordSelectionDialogState extends State<_ChordSelectionDialog> {
  late final List<SongChordSelection> _selected = [...widget.selectedChords];
  var _query = '';
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final types = widget.availableChords
        .map((chord) => chord.type)
        .where((type) => type.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final query = _query.trim().toLowerCase();
    final visible = widget.availableChords.where((chord) {
      final matchesType = _typeFilter == null || chord.type == _typeFilter;
      final text = '${chord.displayName} ${chord.keys}'.toLowerCase();
      return matchesType && (query.isEmpty || text.contains(query));
    }).toList();

    return AlertDialog(
      title: Text(context.t('Select chords')),
      content: SizedBox(
        width: double.maxFinite,
        height: 520,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: context.t('Search chords'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(context.t('All')),
                      selected: _typeFilter == null,
                      onSelected: (_) => setState(() => _typeFilter = null),
                    ),
                  ),
                  for (final type in types)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(context.t(type)),
                        selected: _typeFilter == type,
                        onSelected: (_) => setState(() => _typeFilter = type),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? Center(child: Text(context.t('No matching items')))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final chord = visible[index];
                        final selectedIndex = _selectedIndex(chord);
                        final selected = selectedIndex >= 0
                            ? _selected[selectedIndex]
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: selectedIndex >= 0,
                                secondary: TutorialThumbnail(
                                  path: selected?.imagePath ?? chord.imagePath,
                                  fallbackIcon: Icons.piano_outlined,
                                ),
                                title: Text(chord.displayName),
                                subtitle: Text(
                                  chord.keys,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked ?? false) {
                                      if (selectedIndex < 0) {
                                        _selected.add(
                                          SongChordSelection(chord: chord),
                                        );
                                      }
                                    } else if (selectedIndex >= 0) {
                                      _selected.removeAt(selectedIndex);
                                    }
                                  });
                                },
                              ),
                              if (selectedIndex >= 0)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: DropdownButtonFormField<int?>(
                                    initialValue: _validInversionIndex(
                                      chord,
                                      selected?.inversionIndex,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: context.t('Version'),
                                    ),
                                    items: [
                                      DropdownMenuItem<int?>(
                                        child: Text(context.t('Root')),
                                      ),
                                      for (var i = 0;
                                          i < chord.inversions.length;
                                          i++)
                                        DropdownMenuItem<int?>(
                                          value: i,
                                          child: Text(
                                            chord.inversions[i].name
                                                    .trim()
                                                    .isEmpty
                                                ? context.t(
                                                    'Inversion {index}',
                                                    {'index': i + 1},
                                                  )
                                                : chord.inversions[i].name,
                                          ),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selected[selectedIndex] =
                                            _selected[selectedIndex].copyWith(
                                          inversionIndex: value,
                                          clearInversion: value == null,
                                        );
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
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
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(context.t('Apply')),
        ),
      ],
    );
  }

  int _selectedIndex(ChordTutorial chord) {
    return _selected.indexWhere((selection) => selection.chord == chord);
  }

  int? _validInversionIndex(ChordTutorial chord, int? value) {
    if (value == null || value < 0 || value >= chord.inversions.length) {
      return null;
    }
    return value;
  }
}

class _DialogSectionTitle extends StatelessWidget {
  const _DialogSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

List<T> _reorder<T>(List<T> items, int oldIndex, int newIndex) {
  final next = [...items];
  final item = next.removeAt(oldIndex);
  next.insert(newIndex, item);
  return next;
}

class _MultiSelectField<T> extends StatelessWidget {
  const _MultiSelectField({
    required this.label,
    required this.icon,
    required this.values,
    required this.selectedValues,
    required this.valueLabel,
    required this.emptyLabel,
    required this.dialogTitle,
    required this.onChanged,
    this.valueSubtitle,
    this.emptyValuesLabel,
    this.searchHint,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final List<T> values;
  final List<T> selectedValues;
  final String Function(T value) valueLabel;
  final String emptyLabel;
  final String dialogTitle;
  final ValueChanged<List<T>> onChanged;
  final String? Function(T value)? valueSubtitle;
  final String? emptyValuesLabel;
  final String? searchHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDialog(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.t(label),
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selectedValues.isEmpty
            ? Text(context.t(emptyLabel))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in selectedValues)
                    Chip(label: Text(valueLabel(value))),
                ],
              ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final selected = [...selectedValues];
    var query = '';
    final result = await showDialog<List<T>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedQuery = query.trim().toLowerCase();
          final visibleValues = normalizedQuery.isEmpty
              ? values
              : values.where((value) {
                  final subtitle = valueSubtitle?.call(value) ?? '';
                  final text = '${valueLabel(value)} $subtitle'.toLowerCase();
                  return text.contains(normalizedQuery);
                }).toList(growable: false);
          return AlertDialog(
            title: Text(context.t(dialogTitle)),
            content: SizedBox(
              width: double.maxFinite,
              height: values.isEmpty ? null : 420,
              child: values.isEmpty
                  ? Text(context.t(emptyValuesLabel ?? emptyLabel))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchHint != null) ...[
                          TextField(
                            decoration: InputDecoration(
                              labelText: context.t(searchHint!),
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setDialogState(() => query = value);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        Expanded(
                          child: visibleValues.isEmpty
                              ? Center(
                                  child: Text(context.t('No matching items')))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: visibleValues.length,
                                  itemBuilder: (context, index) {
                                    final value = visibleValues[index];
                                    final subtitle = valueSubtitle?.call(value);
                                    return CheckboxListTile(
                                      value: selected.contains(value),
                                      title: Text(valueLabel(value)),
                                      subtitle: subtitle == null
                                          ? null
                                          : Text(subtitle),
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked ?? false) {
                                            if (!selected.contains(value)) {
                                              selected.add(value);
                                            }
                                          } else {
                                            selected.remove(value);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (trailing != null) trailing!,
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

class _OptionalFields extends StatelessWidget {
  const _OptionalFields({
    required this.originalScale,
    required this.myScale,
    required this.scaleValues,
    required this.originalStartingKey,
    required this.onOriginalScaleChanged,
    required this.onMyScaleChanged,
    required this.onOriginalStartingKeyChanged,
  });

  final String? originalScale;
  final String? myScale;
  final List<String> scaleValues;
  final String? originalStartingKey;
  final ValueChanged<String?> onOriginalScaleChanged;
  final ValueChanged<String?> onMyScaleChanged;
  final ValueChanged<String?> onOriginalStartingKeyChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.more_horiz),
      title: Text(context.t('Optional Information')),
      childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      children: [
        _StringDropdownField(
          label: 'Original Scale',
          value: originalScale,
          values: scaleValues,
          onChanged: onOriginalScaleChanged,
        ),
        const SizedBox(height: 12),
        _StringDropdownField(
          label: 'My Scale',
          value: myScale,
          values: scaleValues,
          onChanged: onMyScaleChanged,
        ),
        const SizedBox(height: 12),
        _StringDropdownField(
          label: 'Original Starting Key',
          value: originalStartingKey,
          values: MusicKeys.values,
          onChanged: onOriginalStartingKeyChanged,
        ),
      ],
    );
  }
}

class _StringDropdownField extends StatelessWidget {
  const _StringDropdownField({
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
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: context.t(label)),
      items: [
        DropdownMenuItem<String?>(child: Text(context.t('None'))),
        for (final item in mergedValues)
          DropdownMenuItem<String?>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    );
  }
}

class _RhythmItemEditor extends StatelessWidget {
  const _RhythmItemEditor({
    required this.availableRhythms,
    required this.rhythmItems,
    required this.onChanged,
    required this.onCreate,
  });

  final List<Rhythm> availableRhythms;
  final List<RhythmItem> rhythmItems;
  final ValueChanged<List<RhythmItem>> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(context.t('Rhythm Items')),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _editItem(context),
            icon: const Icon(Icons.add),
            label: Text(context.t('Add item')),
          ),
        ),
        const SizedBox(height: 8),
        if (rhythmItems.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.t('No rhythm items selected')),
          )
        else
          for (var i = 0; i < rhythmItems.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(rhythmItems[i].summary),
              subtitle: _rhythmItemSubtitle(context, rhythmItems[i], i),
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (i > 0)
                    IconButton(
                      tooltip: context.t('Make primary'),
                      onPressed: () => _makePrimary(i),
                      icon: const Icon(Icons.star_border),
                    ),
                  IconButton(
                    tooltip: context.t('Edit'),
                    onPressed: () => _editItem(context, index: i),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: context.t('Remove'),
                    onPressed: () {
                      final next = [...rhythmItems]..removeAt(i);
                      onChanged(_reposition(next));
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  void _makePrimary(int index) {
    final next = [...rhythmItems];
    final item = next.removeAt(index);
    next.insert(0, item);
    onChanged(_reposition(next));
  }

  Widget? _rhythmItemSubtitle(
    BuildContext context,
    RhythmItem item,
    int index,
  ) {
    final parts = [
      if (index == 0) context.t('Primary'),
      if (item.bpm != null) '${item.bpm} BPM',
    ];
    if (parts.isEmpty) {
      return null;
    }
    return Text(parts.join(' - '));
  }

  Future<void> _editItem(BuildContext context, {int? index}) async {
    final current = index == null ? const RhythmItem() : rhythmItems[index];
    final selected = await showDialog<RhythmItem>(
      context: context,
      builder: (context) {
        return _RhythmItemDialog(
          availableRhythms: availableRhythms,
          item: current,
          onCreate: onCreate,
        );
      },
    );
    if (selected == null || selected.rhythms.isEmpty) {
      return;
    }
    final next = [...rhythmItems];
    final item = selected.copyWith(position: index ?? next.length);
    if (index == null) {
      next.add(item);
    } else {
      next[index] = item;
    }
    onChanged(_reposition(next));
  }

  List<RhythmItem> _reposition(List<RhythmItem> items) {
    return [
      for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
    ];
  }
}

class _RhythmItemDialog extends StatefulWidget {
  const _RhythmItemDialog({
    required this.availableRhythms,
    required this.item,
    required this.onCreate,
  });

  final List<Rhythm> availableRhythms;
  final RhythmItem item;
  final VoidCallback onCreate;

  @override
  State<_RhythmItemDialog> createState() => _RhythmItemDialogState();
}

class _RhythmItemDialogState extends State<_RhythmItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<Rhythm> _selected = [...widget.item.rhythms];
  late final TextEditingController _bpmController =
      TextEditingController(text: widget.item.bpm?.toString() ?? '');

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('Rhythm item')),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _bpmController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.t('BPM')),
                validator: (value) => SongValidation.optionalInt(value, 'BPM'),
              ),
              const SizedBox(height: 12),
              if (widget.availableRhythms.isEmpty)
                Text(context.t('No rhythms created yet'))
              else
                for (final rhythm in widget.availableRhythms)
                  CheckboxListTile(
                    value: _selected.contains(rhythm),
                    title: Text(rhythm.rhythmName),
                    subtitle:
                        rhythm.section == null ? null : Text(rhythm.section!),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selected.add(rhythm);
                        } else {
                          _selected.remove(rhythm);
                        }
                      });
                    },
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onCreate();
          },
          icon: const Icon(Icons.add),
          label: Text(context.t('New')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('Cancel')),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(
                    RhythmItem(
                      bpm: int.tryParse(_bpmController.text.trim()),
                      rhythms: _selected,
                    ),
                  );
                },
          child: Text(context.t('Apply')),
        ),
      ],
    );
  }
}
