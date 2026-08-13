import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/bidi_text.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../services/link_service.dart';

class TutorialNotesEditor extends StatelessWidget {
  const TutorialNotesEditor({
    required this.notes,
    required this.onChanged,
    super.key,
  });

  final List<TutorialNote> notes;
  final ValueChanged<List<TutorialNote>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorBlock(
      title: context.t('Note items'),
      icon: Icons.notes_outlined,
      onAdd: () => _editNote(context),
      addLabel: context.t('Add note item'),
      emptyLabel: context.t('No note items'),
      children: [
        if (notes.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              return ListTile(
                key: ValueKey('tutorial-note-$index-${notes[index].body}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: BidiText(notes[index].displayTitle),
                subtitle: BidiText(
                  notes[index].body,
                  maxLines: 3,
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
                      onPressed: () => _editNote(context, index: index),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: context.t('Delete'),
                      onPressed: () => _remove(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, {int? index}) async {
    final existing = index == null ? null : notes[index];
    final titleController = TextEditingController(text: existing?.title ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');
    try {
      final edited = await showDialog<TutorialNote>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              context.t(index == null ? 'New note item' : 'Edit note item')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: context.t('Title')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: context.t('Notes')),
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
                final note = TutorialNote(
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                );
                if (note.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(note);
              },
              child: Text(context.t('Save')),
            ),
          ],
        ),
      );
      if (edited == null) {
        return;
      }
      final next = [...notes];
      if (index == null) {
        next.add(edited);
      } else {
        next[index] = edited;
      }
      onChanged(next);
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  void _remove(int index) {
    final next = [...notes]..removeAt(index);
    onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...notes];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    onChanged(next);
  }
}

class TutorialLinksEditor extends StatelessWidget {
  const TutorialLinksEditor({
    required this.links,
    required this.onChanged,
    super.key,
  });

  final List<TutorialLink> links;
  final ValueChanged<List<TutorialLink>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorBlock(
      title: context.t('Links'),
      icon: Icons.link,
      onAdd: () => _editLink(context),
      addLabel: context.t('Add link'),
      emptyLabel: context.t('No links'),
      children: [
        for (var index = 0; index < links.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(links[index].displayLabel),
            subtitle: Text(
              links[index].url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: context.t('Edit'),
                  onPressed: () => _editLink(context, index: index),
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
    );
  }

  Future<void> _editLink(BuildContext context, {int? index}) async {
    final existing = index == null ? null : links[index];
    final labelController = TextEditingController(text: existing?.label ?? '');
    final urlController = TextEditingController(text: existing?.url ?? '');
    try {
      final edited = await showDialog<TutorialLink>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t(index == null ? 'New link' : 'Edit link')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: context.t('Label')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(labelText: context.t('URL')),
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
                final link = TutorialLink(
                  label: labelController.text.trim(),
                  url: urlController.text.trim(),
                );
                if (link.url.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(link);
              },
              child: Text(context.t('Save')),
            ),
          ],
        ),
      );
      if (edited == null) {
        return;
      }
      final next = [...links];
      if (index == null) {
        next.add(edited);
      } else {
        next[index] = edited;
      }
      onChanged(next);
    } finally {
      labelController.dispose();
      urlController.dispose();
    }
  }

  void _remove(int index) {
    final next = [...links]..removeAt(index);
    onChanged(next);
  }
}

class TutorialCustomFieldsEditor extends StatelessWidget {
  const TutorialCustomFieldsEditor({
    required this.fields,
    required this.onChanged,
    super.key,
  });

  final List<TutorialCustomField> fields;
  final ValueChanged<List<TutorialCustomField>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorBlock(
      title: context.t('Custom fields'),
      icon: Icons.fact_check_outlined,
      onAdd: () => _editField(context),
      addLabel: context.t('Add field'),
      emptyLabel: context.t('No custom fields'),
      children: [
        for (var index = 0; index < fields.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.label_outline),
            title: Text(fields[index].name),
            subtitle: Text(
              fields[index].value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: context.t('Edit'),
                  onPressed: () => _editField(context, index: index),
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
    );
  }

  Future<void> _editField(BuildContext context, {int? index}) async {
    final existing = index == null ? null : fields[index];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final valueController = TextEditingController(text: existing?.value ?? '');
    try {
      final edited = await showDialog<TutorialCustomField>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t(index == null ? 'New field' : 'Edit field')),
          content: SingleChildScrollView(
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
                  controller: valueController,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: context.t('Value')),
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
                final field = TutorialCustomField(
                  name: nameController.text.trim(),
                  value: valueController.text.trim(),
                );
                if (field.isEmpty || field.name.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(field);
              },
              child: Text(context.t('Save')),
            ),
          ],
        ),
      );
      if (edited == null) {
        return;
      }
      final next = [...fields];
      if (index == null) {
        next.add(edited);
      } else {
        next[index] = edited;
      }
      onChanged(next);
    } finally {
      nameController.dispose();
      valueController.dispose();
    }
  }

  void _remove(int index) {
    final next = [...fields]..removeAt(index);
    onChanged(next);
  }
}

class TutorialNotesView extends StatelessWidget {
  const TutorialNotesView({required this.notes, super.key});

  final List<TutorialNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.notes_outlined, label: context.t('Note items')),
        const SizedBox(height: 8),
        for (final note in notes)
          Card(
            child: ListTile(
              title: BidiText(context.t(note.displayTitle)),
              subtitle: BidiText(note.body),
            ),
          ),
      ],
    );
  }
}

class TutorialLinksView extends StatelessWidget {
  const TutorialLinksView({required this.links, super.key});

  final List<TutorialLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.link, label: context.t('Links')),
        const SizedBox(height: 8),
        for (final link in links)
          Card(
            child: ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(link.displayLabel),
              subtitle: Text(
                link.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final opened = await LinkService.openExternal(link.url);
                if (!context.mounted || opened) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('Unable to open link'))),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TutorialCustomFieldsView extends StatelessWidget {
  const TutorialCustomFieldsView({required this.fields, super.key});

  final List<TutorialCustomField> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.fact_check_outlined,
          label: context.t('Custom fields'),
        ),
        const SizedBox(height: 8),
        for (final field in fields)
          Card(
            child: ListTile(
              title: Text(field.name),
              subtitle: Text(field.value),
            ),
          ),
      ],
    );
  }
}

class _EditorBlock extends StatelessWidget {
  const _EditorBlock({
    required this.title,
    required this.icon,
    required this.addLabel,
    required this.emptyLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String addLabel;
  final String emptyLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
        if (children.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyLabel),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
