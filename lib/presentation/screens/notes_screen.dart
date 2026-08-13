import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/bidi_text.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/general_note.dart';
import '../../services/note_image_storage_service.dart';
import '../providers/library_provider.dart';
import '../widgets/shell_navigation_scope.dart';

enum _NoteSort { newest, oldest, titleAsc, titleDesc }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchController = TextEditingController();
  var _showSearch = false;
  var _sort = _NoteSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final notes = _visibleNotes(library.notes);
        return Scaffold(
          appBar: AppBar(
            leading: ShellBackButton.leading(context),
            title: Text(context.t('Notes')),
            actions: [
              IconButton(
                tooltip: context.t('Search'),
                onPressed: _toggleSearch,
                icon: Icon(_showSearch ? Icons.search_off : Icons.search),
              ),
              PopupMenuButton<_NoteSort>(
                tooltip: context.t('Sort notes'),
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _NoteSort.newest,
                    child: Text(context.t('Modified newest')),
                  ),
                  PopupMenuItem(
                    value: _NoteSort.oldest,
                    child: Text(context.t('Modified oldest')),
                  ),
                  PopupMenuItem(
                    value: _NoteSort.titleAsc,
                    child: Text(context.t('Title A-Z')),
                  ),
                  PopupMenuItem(
                    value: _NoteSort.titleDesc,
                    child: Text(context.t('Title Z-A')),
                  ),
                ],
                icon: const Icon(Icons.sort),
              ),
              IconButton(
                tooltip: context.t('Add note'),
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
              ),
            ],
            bottom: _showSearch
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(68),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: context.t('Search notes'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.t('Clear search'),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  )
                : null,
          ),
          body: notes.isEmpty
              ? EmptyState(
                  icon: Icons.note_alt_outlined,
                  title: library.notes.isEmpty
                      ? context.t('No notes')
                      : context.t('No notes found'),
                  action: library.notes.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => _openEditor(context),
                          icon: const Icon(Icons.add),
                          label: Text(context.t('Add note')),
                        )
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _NoteCard(
                      note: notes[index],
                      onTap: () => _openEditor(context, note: notes[index]),
                      onTogglePin: () => _togglePin(context, notes[index]),
                      onDelete: () => _deleteNote(context, notes[index]),
                    );
                  },
                ),
        );
      },
    );
  }

  List<GeneralNote> _visibleNotes(List<GeneralNote> notes) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? [...notes]
        : notes.where((note) {
            return note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query);
          }).toList();
    visible.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return switch (_sort) {
        _NoteSort.newest => b.updatedAt.compareTo(a.updatedAt),
        _NoteSort.oldest => a.updatedAt.compareTo(b.updatedAt),
        _NoteSort.titleAsc =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        _NoteSort.titleDesc =>
          b.title.toLowerCase().compareTo(a.title.toLowerCase()),
      };
    });
    return visible;
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
      }
    });
  }

  Future<void> _openEditor(BuildContext context, {GeneralNote? note}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteFormScreen(note: note)),
    );
  }

  Future<void> _togglePin(BuildContext context, GeneralNote note) async {
    await context.read<LibraryProvider>().saveNote(
          note.copyWith(pinned: !note.pinned),
        );
  }

  Future<void> _deleteNote(BuildContext context, GeneralNote note) async {
    final id = note.id;
    if (id == null) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete note'),
      message: context.t('Delete "{name}"?', {'name': note.title}),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final deleted = await context.read<LibraryProvider>().deleteNote(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted ? context.t('Note deleted') : context.t('Delete failed'),
          ),
        ),
      );
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final GeneralNote note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: BidiText(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<_NoteAction>(
                    onSelected: (value) {
                      switch (value) {
                        case _NoteAction.pin:
                          onTogglePin();
                          return;
                        case _NoteAction.delete:
                          onDelete();
                          return;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _NoteAction.pin,
                        child: ListTile(
                          leading: Icon(
                            note.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                          ),
                          title: Text(context.t(note.pinned ? 'Unpin' : 'Pin')),
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteAction.delete,
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(context.t('Delete')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.t(
                  'Modified {date}',
                  {'date': _formatDateTime(note.updatedAt)},
                ),
                style: theme.textTheme.labelMedium,
              ),
              if (note.body.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                BidiText(
                  note.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: note.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return _NoteImageThumbnail(
                          path: note.images[index].localPath);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _NoteAction { pin, delete }

class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({this.note, super.key});

  final GeneralNote? note;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imagePicker = ImagePicker();
  late List<NoteImage> _images;
  var _pinned = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController.text = note?.title ?? '';
    _bodyController.text = note?.body ?? '';
    _pinned = note?.pinned ?? false;
    _images = [...(note?.images ?? const [])];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleDirection = textDirectionForText(_titleController.text);
    final bodyDirection = textDirectionForText(_bodyController.text);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(widget.note == null ? 'New Note' : 'Edit Note')),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _titleController,
            textDirection: titleDirection,
            textAlign: titleDirection == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.start,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.t('Title'),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            textDirection: bodyDirection,
            textAlign: bodyDirection == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.start,
            minLines: 10,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.t('Note'),
              alignLabelWithHint: true,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('Pinned')),
            value: _pinned,
            onChanged: (value) => setState(() => _pinned = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Images'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(context.t('Add')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_images.isEmpty)
            Text(context.t('No images'))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final image in _images)
                  Stack(
                    children: [
                      _NoteImageThumbnail(path: image.localPath, size: 104),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.t('Remove image'),
                          onPressed: () {
                            setState(() => _images.remove(image));
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    final path = await NoteImageStorageService().importImage(picked.path);
    setState(() {
      _images = [
        ..._images,
        NoteImage(localPath: path, sortOrder: _images.length),
      ];
    });
  }

  Future<void> _save() async {
    final body = _bodyController.text.trim();
    final title = _resolvedTitle(body);
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('Add a title or note text'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final existing = widget.note;
    final note = GeneralNote(
      id: existing?.id,
      title: title.isEmpty ? context.t('Untitled note') : title,
      body: body,
      pinned: _pinned,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      images: [
        for (var index = 0; index < _images.length; index++)
          _images[index].copyWith(sortOrder: index),
      ],
    );
    final saved = await context.read<LibraryProvider>().saveNote(note);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      final library = context.read<LibraryProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(library.errorMessage ?? context.t('Save failed'))),
      );
    }
  }

  String _resolvedTitle(String body) {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      return title;
    }
    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed.length <= 48
            ? trimmed
            : '${trimmed.substring(0, 48)}...';
      }
    }
    return '';
  }
}

class _NoteImageThumbnail extends StatelessWidget {
  const _NoteImageThumbnail({required this.path, this.size = 72});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
