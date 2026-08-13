import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/music_key_sort.dart';
import '../../core/utils/relative_chords.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../services/media_storage_service.dart';
import '../providers/library_provider.dart';
import '../widgets/tutorial_fields.dart';
import '../widgets/tutorial_media.dart';
import 'media_viewer_screen.dart';

enum _ChordTutorialSort {
  keyOrder,
  alphabetical,
  type,
  newest,
  recentlyUpdated
}

class ChordTutorialsScreen extends StatefulWidget {
  const ChordTutorialsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<ChordTutorialsScreen> createState() => _ChordTutorialsScreenState();
}

class _ChordTutorialsScreenState extends State<ChordTutorialsScreen> {
  String? _typeFilter;
  var _sort = _ChordTutorialSort.keyOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final types = library.chordTutorials
            .map((tutorial) => tutorial.type.trim())
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final activeType = _typeFilter != null && types.contains(_typeFilter)
            ? _typeFilter
            : null;
        final tutorials = _sortTutorials(
          activeType == null
              ? library.chordTutorials
              : library.chordTutorials.where(
                  (tutorial) => tutorial.type == activeType,
                ),
        );
        final body = _buildBody(library, types, activeType, tutorials);

        if (widget.embedded) {
          return Column(
            children: [
              _EmbeddedHeader(
                title: 'Chords',
                sortButton: _ChordSortButton(
                  value: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                ),
                onAdd: () => editChordTutorial(context, library),
              ),
              Expanded(child: body),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.t('Chords')),
            actions: [
              _ChordSortButton(
                value: _sort,
                onChanged: (value) => setState(() => _sort = value),
              ),
              IconButton(
                tooltip: context.t('Add chord tutorial'),
                onPressed: () => editChordTutorial(context, library),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  List<ChordTutorial> _sortTutorials(Iterable<ChordTutorial> tutorials) {
    final sorted = tutorials.toList();
    sorted.sort((left, right) {
      final comparison = switch (_sort) {
        _ChordTutorialSort.keyOrder => _compareByKeyOrder(left, right),
        _ChordTutorialSort.alphabetical => _compareText(
            left.displayName,
            right.displayName,
          ),
        _ChordTutorialSort.type => _compareByType(left, right),
        _ChordTutorialSort.newest => right.createdAt.compareTo(left.createdAt),
        _ChordTutorialSort.recentlyUpdated =>
          right.updatedAt.compareTo(left.updatedAt),
      };
      return comparison == 0
          ? _compareText(left.displayName, right.displayName)
          : comparison;
    });
    return sorted;
  }

  int _compareByKeyOrder(ChordTutorial left, ChordTutorial right) {
    final keyComparison = compareMusicKeys(left.name, right.name);
    if (keyComparison != 0) {
      return keyComparison;
    }
    return _compareText(left.type, right.type);
  }

  int _compareByType(ChordTutorial left, ChordTutorial right) {
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
    List<ChordTutorial> tutorials,
  ) {
    if (library.chordTutorials.isEmpty) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: context.t('No chord tutorials'),
        action: FilledButton.icon(
          onPressed: () => editChordTutorial(context, library),
          icon: const Icon(Icons.add),
          label: Text(context.t('Create tutorial')),
        ),
      );
    }
    return Column(
      children: [
        _ChordTypeFilter(
          types: types,
          selectedType: activeType,
          onChanged: (type) => setState(() => _typeFilter = type),
        ),
        Expanded(
          child: tutorials.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: context.t('No chords for this type'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tutorials.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tutorial = tutorials[index];
                    return Card(
                      child: ListTile(
                        leading: TutorialThumbnail(
                          path: tutorial.imagePath,
                          fallbackIcon: Icons.school_outlined,
                        ),
                        title: Text(tutorial.displayName),
                        subtitle: Text(
                          tutorial.keys,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChordTutorialDetailsScreen(
                              tutorialId: tutorial.id,
                              fallbackTutorial: tutorial,
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
            tooltip: context.t('Add chord tutorial'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _ChordSortButton extends StatelessWidget {
  const _ChordSortButton({required this.value, required this.onChanged});

  final _ChordTutorialSort value;
  final ValueChanged<_ChordTutorialSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChordTutorialSort>(
      tooltip: context.t('Sort chords'),
      initialValue: value,
      icon: const Icon(Icons.sort),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final sort in _ChordTutorialSort.values)
          PopupMenuItem(
            value: sort,
            child: Text(context.t(_sortLabel(sort))),
          ),
      ],
    );
  }

  String _sortLabel(_ChordTutorialSort sort) {
    return switch (sort) {
      _ChordTutorialSort.keyOrder => 'Key order',
      _ChordTutorialSort.alphabetical => 'Alphabetical',
      _ChordTutorialSort.type => 'Type',
      _ChordTutorialSort.newest => 'Newest',
      _ChordTutorialSort.recentlyUpdated => 'Recently updated',
    };
  }
}

class _ChordTypeFilter extends StatelessWidget {
  const _ChordTypeFilter({
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

class ChordTutorialDetailsScreen extends StatelessWidget {
  const ChordTutorialDetailsScreen({
    required this.tutorialId,
    this.fallbackTutorial,
    super.key,
  });

  final int? tutorialId;
  final ChordTutorial? fallbackTutorial;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final tutorial = _findTutorial(library) ?? fallbackTutorial;
        if (tutorial == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.school_outlined,
              title: context.t('Chord not found'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tutorial.displayName),
            actions: [
              IconButton(
                tooltip: context.t('Edit'),
                onPressed: () => editChordTutorial(
                  context,
                  library,
                  tutorial: tutorial,
                ),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: context.t('Delete'),
                onPressed: () =>
                    deleteChordTutorial(context, library, tutorial),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (tutorial.imagePath != null) ...[
                _ChordImage(tutorial: tutorial),
                const SizedBox(height: 16),
              ],
              Text(
                tutorial.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _DetailBlock(
                icon: Icons.music_note_outlined,
                label: 'Name',
                value: tutorial.name,
              ),
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.category_outlined,
                label: 'Type',
                value: tutorial.type,
              ),
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.piano_outlined,
                label: 'Keys/Notes',
                value: tutorial.keys,
              ),
              if (tutorial.inversions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InversionsView(inversions: tutorial.inversions),
              ],
              _RelativeChordView(
                tutorial: tutorial,
                catalog: library.chordTutorials,
              ),
              if (tutorial.videoPath != null) ...[
                const SizedBox(height: 12),
                _VideoTile(
                  title: tutorial.displayName,
                  videoPath: tutorial.videoPath!,
                ),
              ],
              if (tutorial.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialNotesView(notes: tutorial.notes),
              ],
              if (tutorial.links.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialLinksView(links: tutorial.links),
              ],
              if (tutorial.customFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                TutorialCustomFieldsView(fields: tutorial.customFields),
              ],
              const SizedBox(height: 12),
              _DetailBlock(
                icon: Icons.update,
                label: 'Last Updated',
                value: _formatDate(tutorial.updatedAt),
              ),
            ],
          ),
        );
      },
    );
  }

  ChordTutorial? _findTutorial(LibraryProvider library) {
    final id = tutorialId;
    if (id == null) {
      return null;
    }
    for (final tutorial in library.chordTutorials) {
      if (tutorial.id == id) {
        return tutorial;
      }
    }
    return null;
  }
}

class _RelativeChordView extends StatelessWidget {
  const _RelativeChordView({
    required this.tutorial,
    required this.catalog,
  });

  final ChordTutorial tutorial;
  final List<ChordTutorial> catalog;

  @override
  Widget build(BuildContext context) {
    final relativeChord = RelativeChords.findFor(tutorial, catalog);
    if (relativeChord == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('Relative Chord'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: TutorialThumbnail(
                path: relativeChord.chord.imagePath,
                fallbackIcon: Icons.piano_outlined,
              ),
              title: Text(relativeChord.chord.displayName),
              subtitle: Text(
                '${context.t(relativeChord.label)} - ${relativeChord.chord.keys}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChordTutorialDetailsScreen(
                    tutorialId: relativeChord.chord.id,
                    fallbackTutorial: relativeChord.chord,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> editChordTutorial(
  BuildContext context,
  LibraryProvider library, {
  ChordTutorial? tutorial,
}) async {
  final picker = ImagePicker();
  final nameController = TextEditingController(text: tutorial?.name ?? '');
  final typeController = TextEditingController(text: tutorial?.type ?? 'Major');
  final keysController = TextEditingController(text: tutorial?.keys ?? '');
  var imagePath = tutorial?.imagePath;
  var videoPath = tutorial?.videoPath;
  var notes = [...(tutorial?.notes ?? const <TutorialNote>[])];
  var links = [...(tutorial?.links ?? const <TutorialLink>[])];
  var customFields = [
    ...(tutorial?.customFields ?? const <TutorialCustomField>[]),
  ];
  var inversions = [...(tutorial?.inversions ?? const <ChordInversion>[])];
  final currentId = tutorial?.id;
  final relativeChordOptions = library.chordTutorials
      .where(
        (item) =>
            item.id != null && (currentId == null || item.id != currentId),
      )
      .toList(growable: false);
  var relativeChordId = tutorial?.relativeChordId;
  if (relativeChordId != null &&
      !relativeChordOptions.any((chord) => chord.id == relativeChordId)) {
    relativeChordId = null;
  }
  try {
    final edited = await showDialog<ChordTutorial>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.t(tutorial == null ? 'New chord' : 'Edit chord')),
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
                    decoration: InputDecoration(labelText: context.t('Type')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keysController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.t('Keys/Notes'),
                      hintText: context.t('C, E, G'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: relativeChordId,
                    decoration: InputDecoration(
                      labelText: context.t('Relative Chord'),
                      prefixIcon: const Icon(Icons.hub_outlined),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(context.t('No relative chord selected')),
                      ),
                      for (final chord in relativeChordOptions)
                        DropdownMenuItem<int?>(
                          value: chord.id,
                          child: Text(chord.displayName),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => relativeChordId = value);
                    },
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
                              final copiedPath = await MediaStorageService()
                                  .importFile(image.path, MediaType.chordImage);
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
                  _ChordInversionsEditor(
                    inversions: inversions,
                    onChanged: (value) {
                      setDialogState(() => inversions = value);
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
                if (name.isEmpty || type.isEmpty || keys.isEmpty) {
                  return;
                }
                final now = DateTime.now();
                Navigator.of(context).pop(
                  ChordTutorial(
                    id: tutorial?.id,
                    name: name,
                    type: type,
                    keys: keys,
                    imagePath: imagePath,
                    videoPath: videoPath,
                    relativeChordId: relativeChordId,
                    inversions: inversions,
                    notes: notes,
                    links: links,
                    customFields: customFields,
                    createdAt: tutorial?.createdAt ?? now,
                    updatedAt: now,
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
    final saved = await library.saveChordTutorial(edited);
    if (context.mounted) {
      _showSnack(
        context,
        saved
            ? context.t('Chord saved')
            : library.errorMessage ?? context.t('Save failed'),
      );
    }
  } finally {
    nameController.dispose();
    typeController.dispose();
    keysController.dispose();
  }
}

Future<void> deleteChordTutorial(
  BuildContext context,
  LibraryProvider library,
  ChordTutorial tutorial,
) async {
  if (tutorial.id == null) {
    return;
  }
  final confirmed = await confirmDialog(
    context,
    title: context.t('Delete chord tutorial'),
    message: context.t('Delete "{name}"?', {'name': tutorial.displayName}),
  );
  if (!confirmed) {
    return;
  }
  final deleted = await library.deleteChordTutorial(tutorial.id!);
  if (context.mounted) {
    _showSnack(
      context,
      deleted
          ? context.t('Chord deleted')
          : library.errorMessage ?? context.t('Delete failed'),
    );
  }
}

class _InversionsView extends StatelessWidget {
  const _InversionsView({required this.inversions});

  final List<ChordInversion> inversions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flip_to_front,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.t('Inversions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final inversion in inversions)
          Card(
            child: ExpansionTile(
              leading: TutorialThumbnail(
                path: inversion.imagePath,
                fallbackIcon: Icons.flip_to_front,
              ),
              title: Text(context.t(inversion.name)),
              subtitle: Text(inversion.keys),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (inversion.imagePath != null) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FullscreenImageScreen(
                          path: inversion.imagePath!,
                          title: context.t(inversion.name),
                        ),
                      ),
                    ),
                    child: TutorialHeroImage(
                      path: inversion.imagePath!,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (inversion.videoPath != null)
                  _VideoTile(
                    title: inversion.name,
                    videoPath: inversion.videoPath!,
                  ),
                if (inversion.notes.isNotEmpty)
                  TutorialNotesView(notes: inversion.notes),
                if (inversion.links.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TutorialLinksView(links: inversion.links),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ChordInversionsEditor extends StatelessWidget {
  const _ChordInversionsEditor({
    required this.inversions,
    required this.onChanged,
  });

  final List<ChordInversion> inversions;
  final ValueChanged<List<ChordInversion>> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.flip_to_front),
      title: Text(context.t('Inversions')),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _editInversion(context),
            icon: const Icon(Icons.add),
            label: Text(context.t('Add inversion')),
          ),
        ),
        if (inversions.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.t('No inversions')),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: inversions.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final inversion = inversions[index];
              return Card(
                key: ValueKey(
                  'chord-inversion-$index-${inversion.name}',
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TutorialThumbnail(
                            path: inversion.imagePath,
                            fallbackIcon: Icons.flip_to_front,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.t(inversion.name),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inversion.keys,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
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
                              onPressed: () =>
                                  _editInversion(context, index: index),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: context.t('Delete'),
                              onPressed: () => _remove(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _editInversion(BuildContext context, {int? index}) async {
    final picker = ImagePicker();
    final existing = index == null ? null : inversions[index];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final keysController = TextEditingController(text: existing?.keys ?? '');
    var imagePath = existing?.imagePath;
    var videoPath = existing?.videoPath;
    var notes = [...(existing?.notes ?? const <TutorialNote>[])];
    var links = [...(existing?.links ?? const <TutorialLink>[])];

    try {
      final edited = await showDialog<ChordInversion>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setInversionDialogState) => AlertDialog(
            title: Text(
              context.t(index == null ? 'New inversion' : 'Edit inversion'),
            ),
            content: SizedBox(
              width: 500,
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
                      controller: keysController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.t('Keys/Notes'),
                        hintText: context.t('E, G, C'),
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
                                    await MediaStorageService().importFile(
                                  image.path,
                                  MediaType.chordImage,
                                );
                                setInversionDialogState(
                                  () => imagePath = copiedPath,
                                );
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
                              setInversionDialogState(() => imagePath = null);
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
                                setInversionDialogState(
                                  () => videoPath = copiedPath,
                                );
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
                              setInversionDialogState(() => videoPath = null);
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    if (videoPath != null) _PathPreview(path: videoPath!),
                    const SizedBox(height: 8),
                    TutorialNotesEditor(
                      notes: notes,
                      onChanged: (value) {
                        setInversionDialogState(() => notes = value);
                      },
                    ),
                    TutorialLinksEditor(
                      links: links,
                      onChanged: (value) {
                        setInversionDialogState(() => links = value);
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
                  final keys = keysController.text.trim();
                  if (name.isEmpty || keys.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(
                    ChordInversion(
                      name: name,
                      keys: keys,
                      imagePath: imagePath,
                      videoPath: videoPath,
                      notes: notes,
                      links: links,
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
      final next = [...inversions];
      if (index == null) {
        next.add(edited);
      } else {
        next[index] = edited;
      }
      onChanged(next);
    } finally {
      nameController.dispose();
      keysController.dispose();
    }
  }

  void _remove(int index) {
    final next = [...inversions]..removeAt(index);
    onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...inversions];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    onChanged(next);
  }
}

class _ChordImage extends StatelessWidget {
  const _ChordImage({required this.tutorial});

  final ChordTutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final path = tutorial.imagePath;
    if (path == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FullscreenImageScreen(
            path: path,
            title: tutorial.displayName,
          ),
        ),
      ),
      child: TutorialHeroImage(path: path),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(label),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ],
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
