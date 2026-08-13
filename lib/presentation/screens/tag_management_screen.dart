import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/rhythm.dart';
import '../../domain/entities/tag.dart';
import '../providers/library_provider.dart';
import '../widgets/shell_navigation_scope.dart';

class TagManagementScreen extends StatelessWidget {
  const TagManagementScreen({super.key});

  static const _colors = <int>[
    0xFF2F6F6D,
    0xFF7B4B94,
    0xFFB23A48,
    0xFF3D5A80,
    0xFF795548,
    0xFF5B6C2F,
  ];

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _ManagementAppBar(),
        body: TabBarView(children: [_TagsTab(), _RhythmsTab()]),
      ),
    );
  }
}

class _ManagementAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ManagementAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: ShellBackButton.leading(context),
      title: Text(context.t('Manage')),
      bottom: TabBar(
        tabs: [
          Tab(icon: const Icon(Icons.sell_outlined), text: context.t('Tags')),
          Tab(
            icon: const Icon(Icons.timer_outlined),
            text: context.t('Rhythms'),
          ),
        ],
      ),
    );
  }
}

class _TagsTab extends StatelessWidget {
  const _TagsTab();

  static const _colors = TagManagementScreen._colors;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: context.t('Add tag'),
            onPressed: () => _editTag(context, library),
            child: const Icon(Icons.add),
          ),
          body: library.tags.isEmpty
              ? EmptyState(
                  icon: Icons.sell_outlined,
                  title: context.t('No tags'),
                  action: FilledButton.icon(
                    onPressed: () => _editTag(context, library),
                    icon: const Icon(Icons.add),
                    label: Text(context.t('Create tag')),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: library.tags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tag = library.tags[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tag.color == null
                              ? Theme.of(context).colorScheme.primary
                              : Color(tag.color!),
                        ),
                        title: Text(tag.name),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: context.t('Rename'),
                              onPressed: () =>
                                  _editTag(context, library, tag: tag),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: context.t('Delete'),
                              onPressed: () =>
                                  _deleteTag(context, library, tag),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _editTag(
    BuildContext context,
    LibraryProvider library, {
    Tag? tag,
  }) async {
    final controller = TextEditingController(text: tag?.name ?? '');
    var selectedColor = tag?.color ?? _colors.first;
    try {
      final edited = await showDialog<Tag>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(context.t(tag == null ? 'New tag' : 'Edit tag')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(labelText: context.t('Tag Name')),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color in _colors)
                      ChoiceChip(
                        label: const SizedBox.shrink(),
                        avatar: CircleAvatar(backgroundColor: Color(color)),
                        selected: selectedColor == color,
                        onSelected: (_) {
                          setDialogState(() => selectedColor = color);
                        },
                      ),
                  ],
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
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(Tag(id: tag?.id, name: name, color: selectedColor));
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
      final saved = await library.saveTag(edited);
      if (context.mounted) {
        _showSnack(
          context,
          saved
              ? context.t('Tag saved')
              : library.errorMessage ?? context.t('Save failed'),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteTag(
    BuildContext context,
    LibraryProvider library,
    Tag tag,
  ) async {
    if (tag.id == null) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete tag'),
      message: context.t(
        'Delete "{name}"? Songs using it will keep no tag.',
        {'name': tag.name},
      ),
    );
    if (!confirmed) {
      return;
    }
    final deleted = await library.deleteTag(tag.id!);
    if (context.mounted) {
      _showSnack(
        context,
        deleted
            ? context.t('Tag deleted')
            : library.errorMessage ?? context.t('Delete failed'),
      );
    }
  }
}

class _RhythmsTab extends StatelessWidget {
  const _RhythmsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: context.t('Add rhythm'),
            onPressed: () => _editRhythm(context, library),
            child: const Icon(Icons.add),
          ),
          body: library.rhythms.isEmpty
              ? EmptyState(
                  icon: Icons.timer_outlined,
                  title: context.t('No rhythms'),
                  action: FilledButton.icon(
                    onPressed: () => _editRhythm(context, library),
                    icon: const Icon(Icons.add),
                    label: Text(context.t('Create rhythm')),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: library.rhythms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rhythm = library.rhythms[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(rhythm.rhythmName),
                        subtitle: rhythm.section == null
                            ? null
                            : Text(rhythm.section!),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: context.t('Edit'),
                              onPressed: () => _editRhythm(
                                context,
                                library,
                                rhythm: rhythm,
                              ),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: context.t('Delete'),
                              onPressed: () =>
                                  _deleteRhythm(context, library, rhythm),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _editRhythm(
    BuildContext context,
    LibraryProvider library, {
    Rhythm? rhythm,
  }) async {
    final nameController =
        TextEditingController(text: rhythm?.rhythmName ?? '');
    final sectionController =
        TextEditingController(text: rhythm?.section ?? '');
    try {
      final edited = await showDialog<Rhythm>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t(rhythm == null ? 'New rhythm' : 'Edit rhythm')),
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
                    id: rhythm?.id,
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

      if (edited == null) {
        return;
      }
      final saved = await library.saveRhythm(edited);
      if (context.mounted) {
        _showSnack(
          context,
          saved
              ? context.t('Rhythm saved')
              : library.errorMessage ?? context.t('Save failed'),
        );
      }
    } finally {
      nameController.dispose();
      sectionController.dispose();
    }
  }

  Future<void> _deleteRhythm(
    BuildContext context,
    LibraryProvider library,
    Rhythm rhythm,
  ) async {
    if (rhythm.id == null) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete rhythm'),
      message: context.t(
        'Delete "{name}"? Songs using it will keep the rhythm text.',
        {'name': rhythm.rhythmName},
      ),
    );
    if (!confirmed) {
      return;
    }
    final deleted = await library.deleteRhythm(rhythm.id!);
    if (context.mounted) {
      _showSnack(
        context,
        deleted
            ? context.t('Rhythm deleted')
            : library.errorMessage ?? context.t('Delete failed'),
      );
    }
  }
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
