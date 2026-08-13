import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/music_key_sort.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/musical_scale.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../services/media_storage_service.dart';
import '../../services/scale_image_storage_service.dart';
import '../providers/library_provider.dart';
import '../widgets/tutorial_fields.dart';
import '../widgets/tutorial_media.dart';
import 'chord_tutorials_screen.dart';
import 'media_viewer_screen.dart';

enum _ScaleSort { keyOrder, alphabetical, type, newest, recentlyUpdated }

class ScalesScreen extends StatefulWidget {
  const ScalesScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<ScalesScreen> createState() => _ScalesScreenState();
}

class _ScalesScreenState extends State<ScalesScreen> {
  String? _typeFilter;
  var _sort = _ScaleSort.keyOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final types = library.scales
            .map((scale) => scale.type.trim())
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final activeType = _typeFilter != null && types.contains(_typeFilter)
            ? _typeFilter
            : null;
        final scales = _sortScales(
          activeType == null
              ? library.scales
              : library.scales.where((scale) => scale.type == activeType),
        );
        final body = _buildBody(library, types, activeType, scales);

        if (widget.embedded) {
          return Column(
            children: [
              _EmbeddedHeader(
                title: 'Scales',
                sortButton: _ScaleSortButton(
                  value: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                ),
                onAdd: () => editScale(context, library),
              ),
              Expanded(child: body),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.t('Scales')),
            actions: [
              _ScaleSortButton(
                value: _sort,
                onChanged: (value) => setState(() => _sort = value),
              ),
              IconButton(
                tooltip: context.t('Add scale'),
                onPressed: () => editScale(context, library),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  List<MusicalScale> _sortScales(Iterable<MusicalScale> scales) {
    final sorted = scales.toList();
    sorted.sort((left, right) {
      final comparison = switch (_sort) {
        _ScaleSort.keyOrder => _compareByKeyOrder(left, right),
        _ScaleSort.alphabetical => _compareText(
            left.displayName,
            right.displayName,
          ),
        _ScaleSort.type => _compareByType(left, right),
        _ScaleSort.newest => right.createdAt.compareTo(left.createdAt),
        _ScaleSort.recentlyUpdated => right.updatedAt.compareTo(left.updatedAt),
      };
      return comparison == 0
          ? _compareText(left.displayName, right.displayName)
          : comparison;
    });
    return sorted;
  }

  int _compareByKeyOrder(MusicalScale left, MusicalScale right) {
    final keyComparison = compareMusicKeys(left.name, right.name);
    if (keyComparison != 0) {
      return keyComparison;
    }
    return _compareText(left.type, right.type);
  }

  int _compareByType(MusicalScale left, MusicalScale right) {
    final typeComparison = _compareText(left.type, right.type);
    if (typeComparison != 0) {
      return typeComparison;
    }
    return _compareByKeyOrder(left, right);
  }

  int _compareText(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  Widget _buildBody(
    LibraryProvider library,
    List<String> types,
    String? activeType,
    List<MusicalScale> scales,
  ) {
    if (library.scales.isEmpty) {
      return EmptyState(
        icon: Icons.piano_outlined,
        title: context.t('No scales'),
        action: FilledButton.icon(
          onPressed: () => editScale(context, library),
          icon: const Icon(Icons.add),
          label: Text(context.t('Create scale')),
        ),
      );
    }
    return Column(
      children: [
        _ScaleTypeFilter(
          types: types,
          selectedType: activeType,
          onChanged: (type) => setState(() => _typeFilter = type),
        ),
        Expanded(
          child: scales.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: context.t('No scales for this type'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: scales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final scale = scales[index];
                    return Card(
                      child: ListTile(
                        leading: TutorialThumbnail(
                          path: scale.imagePath,
                          fallbackIcon: Icons.piano_outlined,
                        ),
                        title: Text(scale.displayName),
                        subtitle: _ScaleListSubtitle(scale: scale),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ScaleDetailsScreen(
                              scaleId: scale.id,
                              fallbackScale: scale,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  const _EmbeddedHeader({
    required this.title,
    required this.sortButton,
    required this.onAdd,
  });

  final String title;
  final Widget sortButton;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t(title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          sortButton,
          IconButton(
            tooltip: context.t('Add scale'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _ScaleSortButton extends StatelessWidget {
  const _ScaleSortButton({required this.value, required this.onChanged});

  final _ScaleSort value;
  final ValueChanged<_ScaleSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ScaleSort>(
      tooltip: context.t('Sort scales'),
      initialValue: value,
      icon: const Icon(Icons.sort),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final sort in _ScaleSort.values)
          PopupMenuItem(
            value: sort,
            child: Text(context.t(_sortLabel(sort))),
          ),
      ],
    );
  }

  String _sortLabel(_ScaleSort sort) {
    return switch (sort) {
      _ScaleSort.keyOrder => 'Key order',
      _ScaleSort.alphabetical => 'Alphabetical',
      _ScaleSort.type => 'Type',
      _ScaleSort.newest => 'Newest',
      _ScaleSort.recentlyUpdated => 'Recently updated',
    };
  }
}

class _ScaleTypeFilter extends StatelessWidget {
  const _ScaleTypeFilter({
    required this.types,
    required this.selectedType,
    required this.onChanged,
  });

  final List<String> types;
  final String? selectedType;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(context.t('All')),
              selected: selectedType == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final type in types)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(type),
                selected: selectedType == type,
                onSelected: (_) => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaleListSubtitle extends StatelessWidget {
  const _ScaleListSubtitle({required this.scale});

  final MusicalScale scale;

  @override
  Widget build(BuildContext context) {
    final chordSummary = _scaleChordSummary(scale.chordTutorials);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          scale.keys,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (chordSummary.isNotEmpty)
          Text(
            context.t('Chords: {value}', {'value': chordSummary}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class ScaleDetailsScreen extends StatelessWidget {
  const ScaleDetailsScreen({
    required this.scaleId,
    this.fallbackScale,
    super.key,
  });

  final int? scaleId;
  final MusicalScale? fallbackScale;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final scale = _findScale(library) ?? fallbackScale;
        if (scale == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.piano_off_outlined,
              title: context.t('Scale not found'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(scale.displayName),
            actions: [
              IconButton(
                tooltip: context.t('Edit'),
                onPressed: () => editScale(context, library, scale: scale),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: context.t('Delete'),
                onPressed: () => deleteScale(context, library, scale),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (scale.imagePath != null) ...[
                _ScaleImage(scale: scale),
                const SizedBox(height: 16),
              ],
              Text(
                scale.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _DetailBlock(
                icon: Icons.piano_outlined,
                label: 'Name',
                value: scale.name,
              ),
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.category_outlined,
                label: 'Type',
                value: scale.type,
              ),
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.music_note_outlined,
                label: 'Keys/Notes',
                value: scale.keys,
              ),
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.functions_outlined,
                label: 'Formula',
                value: scale.formula,
              ),
              const SizedBox(height: 16),
              _ScaleChordSection(chords: scale.chordTutorials),
              if (scale.videoPath != null) ...[
                const SizedBox(height: 12),
                _VideoTile(
                    title: scale.displayName, videoPath: scale.videoPath!),
              ],
              if (scale.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialNotesView(notes: scale.notes),
              ],
              if (scale.links.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialLinksView(links: scale.links),
              ],
              if (scale.customFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialCustomFieldsView(fields: scale.customFields),
              ],
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.update,
                label: 'Last Updated',
                value: _formatDate(scale.updatedAt),
              ),
            ],
          ),
        );
      },
    );
  }

  MusicalScale? _findScale(LibraryProvider library) {
    final id = scaleId;
    if (id == null) {
      return null;
    }
    for (final scale in library.scales) {
      if (scale.id == id) {
        return scale;
      }
    }
    return null;
  }
}

class _ScaleChordSection extends StatelessWidget {
  const _ScaleChordSection({required this.chords});

  final List<ChordTutorial> chords;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.queue_music_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.t('Scale Chords'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (chords.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_off_outlined),
              title: Text(context.t('No chords selected')),
            ),
          )
        else
          for (final chord in chords)
            Card(
              child: ListTile(
                leading: TutorialThumbnail(
                  path: chord.imagePath,
                  fallbackIcon: Icons.piano_outlined,
                ),
                title: Text(chord.displayName),
                subtitle: Text(
                  chord.keys,
                  maxLines: 1,
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
              ),
            ),
      ],
    );
  }
}

Future<void> editScale(
  BuildContext context,
  LibraryProvider library, {
  MusicalScale? scale,
}) async {
  final picker = ImagePicker();
  final nameController = TextEditingController(text: scale?.name ?? '');
  final typeController = TextEditingController(text: scale?.type ?? 'Major');
  final keysController = TextEditingController(text: scale?.keys ?? '');
  final formulaController = TextEditingController(text: scale?.formula ?? '');
  var imagePath = scale?.imagePath;
  var videoPath = scale?.videoPath;
  var chordTutorials = [
    ...(scale?.chordTutorials ?? const <ChordTutorial>[]),
  ];
  var notes = [...(scale?.notes ?? const <TutorialNote>[])];
  var links = [...(scale?.links ?? const <TutorialLink>[])];
  var customFields = [
    ...(scale?.customFields ?? const <TutorialCustomField>[]),
  ];
  try {
    final edited = await showDialog<MusicalScale>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.t(scale == null ? 'New scale' : 'Edit scale')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(labelText: context.t('Name')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeController,
                    decoration: InputDecoration(
                      labelText: context.t('Type'),
                      hintText: context.t('Major, Minor, Bayati'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keysController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.t('Keys/Notes'),
                      hintText: context.t('C, D, E, F, G, A, B'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: formulaController,
                    decoration: InputDecoration(
                      labelText: context.t('Formula'),
                      hintText: context.t('1, 1, 1/2, 1, 1, 1, 1/2'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              final copiedPath =
                                  await ScaleImageStorageService()
                                      .importImage(image.path);
                              setDialogState(() => imagePath = copiedPath);
                            }
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: Text(context.t('Choose image')),
                        ),
                      ),
                      if (imagePath != null)
                        IconButton(
                          tooltip: context.t('Clear image'),
                          onPressed: () {
                            setDialogState(() => imagePath = null);
                          },
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  if (imagePath != null) _PathPreview(path: imagePath!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final video = await picker.pickVideo(
                              source: ImageSource.gallery,
                            );
                            if (video != null) {
                              final copiedPath =
                                  await MediaStorageService().importFile(
                                video.path,
                                MediaType.performanceVideo,
                              );
                              setDialogState(() => videoPath = copiedPath);
                            }
                          },
                          icon: const Icon(Icons.video_library_outlined),
                          label: Text(context.t('Choose video')),
                        ),
                      ),
                      if (videoPath != null)
                        IconButton(
                          tooltip: context.t('Clear video'),
                          onPressed: () {
                            setDialogState(() => videoPath = null);
                          },
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  if (videoPath != null) _PathPreview(path: videoPath!),
                  const SizedBox(height: 8),
                  _ScaleChordSelector(
                    availableChords: library.chordTutorials,
                    selectedChords: chordTutorials,
                    onChanged: (value) {
                      setDialogState(() => chordTutorials = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TutorialNotesEditor(
                    notes: notes,
                    onChanged: (value) {
                      setDialogState(() => notes = value);
                    },
                  ),
                  TutorialLinksEditor(
                    links: links,
                    onChanged: (value) {
                      setDialogState(() => links = value);
                    },
                  ),
                  TutorialCustomFieldsEditor(
                    fields: customFields,
                    onChanged: (value) {
                      setDialogState(() => customFields = value);
                    },
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
              onPressed: () {
                final name = nameController.text.trim();
                final type = typeController.text.trim();
                final keys = keysController.text.trim();
                final formula = formulaController.text.trim();
                if (name.isEmpty ||
                    type.isEmpty ||
                    keys.isEmpty ||
                    formula.isEmpty) {
                  return;
                }
                final now = DateTime.now();
                Navigator.of(context).pop(
                  MusicalScale(
                    id: scale?.id,
                    name: name,
                    type: type,
                    keys: keys,
                    formula: formula,
                    imagePath: imagePath,
                    videoPath: videoPath,
                    chordTutorials: chordTutorials,
                    notes: notes,
                    links: links,
                    customFields: customFields,
                    createdAt: scale?.createdAt ?? now,
                    updatedAt: scale?.updatedAt ?? now,
                  ),
                );
              },
              child: Text(context.t('Save')),
            ),
          ],
        ),
      ),
    );

    if (edited == null) {
      return;
    }
    final saved = await library.saveScale(edited);
    if (context.mounted) {
      _showSnack(
        context,
        saved
            ? context.t('Scale saved')
            : library.errorMessage ?? context.t('Save failed'),
      );
    }
  } finally {
    nameController.dispose();
    typeController.dispose();
    keysController.dispose();
    formulaController.dispose();
  }
}

class _ScaleChordSelector extends StatelessWidget {
  const _ScaleChordSelector({
    required this.availableChords,
    required this.selectedChords,
    required this.onChanged,
  });

  final List<ChordTutorial> availableChords;
  final List<ChordTutorial> selectedChords;
  final ValueChanged<List<ChordTutorial>> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDialog(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.t('Scale Chords'),
          prefixIcon: const Icon(Icons.queue_music_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selectedChords.isEmpty
            ? Text(context.t('No chords selected'))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chord in selectedChords)
                    Chip(label: Text(chord.displayName)),
                ],
              ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final selected = [...selectedChords];
    final values = [...availableChords]..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    var query = '';
    String? typeFilter;
    final result = await showDialog<List<ChordTutorial>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final types = values
              .map((chord) => chord.type.trim())
              .where((type) => type.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final normalizedQuery = query.trim().toLowerCase();
          final visibleValues = values.where((chord) {
            final matchesType = typeFilter == null || chord.type == typeFilter;
            if (!matchesType) {
              return false;
            }
            if (normalizedQuery.isEmpty) {
              return true;
            }
            final text = '${chord.displayName} ${chord.keys}'.toLowerCase();
            return text.contains(normalizedQuery);
          }).toList(growable: false);
          return AlertDialog(
            title: Text(context.t('Select scale chords')),
            content: SizedBox(
              width: double.maxFinite,
              height: values.isEmpty ? null : 420,
              child: values.isEmpty
                  ? Text(context.t('No chord tutorials'))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: context.t('Search chords'),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            setDialogState(() => query = value);
                          },
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
                                  selected: typeFilter == null,
                                  onSelected: (_) {
                                    setDialogState(() => typeFilter = null);
                                  },
                                ),
                              ),
                              for (final type in types)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(context.t(type)),
                                    selected: typeFilter == type,
                                    onSelected: (_) {
                                      setDialogState(() => typeFilter = type);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selected.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.t('Selected order'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          SizedBox(
                            height: 124,
                            child: ReorderableListView.builder(
                              itemCount: selected.length,
                              onReorderItem: (oldIndex, newIndex) {
                                setDialogState(() {
                                  final item = selected.removeAt(oldIndex);
                                  selected.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final chord = selected[index];
                                return ListTile(
                                  key: ValueKey(
                                    'scale-selected-chord-${chord.id}-$index',
                                  ),
                                  dense: true,
                                  leading: ReorderableDragStartListener(
                                    index: index,
                                    child: IconButton(
                                      tooltip: context.t('Reorder'),
                                      onPressed: () {},
                                      icon: const Icon(Icons.drag_handle),
                                    ),
                                  ),
                                  title: Text(chord.displayName),
                                  trailing: IconButton(
                                    tooltip: context.t('Remove'),
                                    onPressed: () {
                                      setDialogState(() {
                                        selected.removeAt(index);
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Expanded(
                          child: visibleValues.isEmpty
                              ? Center(
                                  child: Text(context.t('No matching items')),
                                )
                              : ListView.builder(
                                  itemCount: visibleValues.length,
                                  itemBuilder: (context, index) {
                                    final chord = visibleValues[index];
                                    final selectedIndex =
                                        _selectedIndex(selected, chord);
                                    return CheckboxListTile(
                                      value: selectedIndex >= 0,
                                      secondary: TutorialThumbnail(
                                        path: chord.imagePath,
                                        fallbackIcon: Icons.piano_outlined,
                                      ),
                                      title: Text(chord.displayName),
                                      subtitle: Text(chord.keys),
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked ?? false) {
                                            if (selectedIndex < 0) {
                                              selected.add(chord);
                                            }
                                          } else if (selectedIndex >= 0) {
                                            selected.removeAt(selectedIndex);
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

  int _selectedIndex(List<ChordTutorial> selected, ChordTutorial chord) {
    return selected.indexWhere((item) => _sameChord(item, chord));
  }

  bool _sameChord(ChordTutorial a, ChordTutorial b) {
    if (a.id != null && b.id != null) {
      return a.id == b.id;
    }
    return a.displayName == b.displayName && a.type == b.type;
  }
}

Future<void> deleteScale(
  BuildContext context,
  LibraryProvider library,
  MusicalScale scale,
) async {
  final id = scale.id;
  if (id == null) {
    return;
  }
  final confirmed = await confirmDialog(
    context,
    title: context.t('Delete scale'),
    message: context.t(
      'Delete "{name}"? Songs that already show this scale will keep the text value.',
      {'name': scale.displayName},
    ),
  );
  if (!confirmed) {
    return;
  }
  final deleted = await library.deleteScale(id);
  if (context.mounted) {
    if (deleted) {
      Navigator.of(context).maybePop();
    }
    _showSnack(
      context,
      deleted
          ? context.t('Scale deleted')
          : library.errorMessage ?? context.t('Delete failed'),
    );
  }
}

class _ScaleImage extends StatelessWidget {
  const _ScaleImage({required this.scale});

  final MusicalScale scale;

  @override
  Widget build(BuildContext context) {
    final imagePath = scale.imagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FullscreenImageScreen(
            path: imagePath,
            title: scale.displayName,
          ),
        ),
      ),
      child: TutorialHeroImage(path: imagePath),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.title, required this.videoPath});

  final String title;
  final String videoPath;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.play_circle_outline),
      title: Text(context.t('Video')),
      subtitle: Text(
        tutorialDisplayPath(videoPath),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(
            media: MediaItem(
              mediaType: MediaType.performanceVideo,
              localPath: videoPath,
              title: title,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(context.t(label), style: theme.textTheme.labelLarge),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
    );
  }
}

class _PathPreview extends StatelessWidget {
  const _PathPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        tutorialDisplayPath(path),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String _scaleChordSummary(List<ChordTutorial> chords) {
  return chords.map((chord) => chord.displayName).join(', ');
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
