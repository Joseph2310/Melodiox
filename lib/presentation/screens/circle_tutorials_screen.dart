import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/circle_tutorial.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/tutorial_detail.dart';
import '../../services/media_storage_service.dart';
import '../providers/library_provider.dart';
import '../widgets/tutorial_fields.dart';
import '../widgets/tutorial_media.dart';
import 'media_viewer_screen.dart';

class CircleTutorialsScreen extends StatelessWidget {
  const CircleTutorialsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final body = library.circleTutorials.isEmpty
            ? EmptyState(
                icon: Icons.circle_outlined,
                title: context.t('No circle tutorials'),
                action: FilledButton.icon(
                  onPressed: () => editCircleTutorial(context, library),
                  icon: const Icon(Icons.add),
                  label: Text(context.t('Create tutorial')),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: library.circleTutorials.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tutorial = library.circleTutorials[index];
                  return Card(
                    child: ListTile(
                      leading: TutorialThumbnail(
                        path: tutorial.imagePath,
                        fallbackIcon: Icons.circle_outlined,
                      ),
                      title: Text(tutorial.title),
                      subtitle: tutorial.summary == null
                          ? null
                          : Text(
                              tutorial.summary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CircleTutorialDetailsScreen(
                            tutorialId: tutorial.id,
                            fallbackTutorial: tutorial,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );

        if (embedded) {
          return Column(
            children: [
              _EmbeddedHeader(
                title: 'Circle of Fifths',
                onAdd: () => editCircleTutorial(context, library),
              ),
              Expanded(child: body),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.t('Circle of Fifths')),
            actions: [
              IconButton(
                tooltip: context.t('Add tutorial'),
                onPressed: () => editCircleTutorial(context, library),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

class CircleTutorialDetailsScreen extends StatelessWidget {
  const CircleTutorialDetailsScreen({
    required this.tutorialId,
    this.fallbackTutorial,
    super.key,
  });

  final int? tutorialId;
  final CircleTutorial? fallbackTutorial;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final tutorial = _findTutorial(library) ?? fallbackTutorial;
        if (tutorial == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.circle_outlined,
              title: context.t('Circle tutorial not found'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tutorial.title),
            actions: [
              IconButton(
                tooltip: context.t('Edit'),
                onPressed: () => editCircleTutorial(
                  context,
                  library,
                  tutorial: tutorial,
                ),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: context.t('Delete'),
                onPressed: () =>
                    deleteCircleTutorial(context, library, tutorial),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (tutorial.imagePath != null) ...[
                _CircleImage(tutorial: tutorial),
                const SizedBox(height: 16),
              ],
              Text(
                tutorial.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (tutorial.summary != null) ...[
                const SizedBox(height: 8),
                Text(tutorial.summary!),
              ],
              if (tutorial.videoPath != null) ...[
                const SizedBox(height: 12),
                _VideoTile(
                  title: tutorial.title,
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

  CircleTutorial? _findTutorial(LibraryProvider library) {
    final id = tutorialId;
    if (id == null) {
      return null;
    }
    for (final tutorial in library.circleTutorials) {
      if (tutorial.id == id) {
        return tutorial;
      }
    }
    return null;
  }
}

Future<void> editCircleTutorial(
  BuildContext context,
  LibraryProvider library, {
  CircleTutorial? tutorial,
}) async {
  final picker = ImagePicker();
  final titleController = TextEditingController(text: tutorial?.title ?? '');
  final summaryController =
      TextEditingController(text: tutorial?.summary ?? '');
  var imagePath = tutorial?.imagePath;
  var videoPath = tutorial?.videoPath;
  var notes = [...(tutorial?.notes ?? const <TutorialNote>[])];
  var links = [...(tutorial?.links ?? const <TutorialLink>[])];
  try {
    final edited = await showDialog<CircleTutorial>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.t(
              tutorial == null ? 'New circle tutorial' : 'Edit circle tutorial',
            ),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
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
                    controller: summaryController,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        InputDecoration(labelText: context.t('Summary')),
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
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                final now = DateTime.now();
                Navigator.of(context).pop(
                  CircleTutorial(
                    id: tutorial?.id,
                    title: title,
                    summary: _blankToNull(summaryController.text),
                    imagePath: imagePath,
                    videoPath: videoPath,
                    notes: notes,
                    links: links,
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
    final saved = await library.saveCircleTutorial(edited);
    if (context.mounted) {
      _showSnack(
        context,
        saved
            ? context.t('Tutorial saved')
            : library.errorMessage ?? context.t('Save failed'),
      );
    }
  } finally {
    titleController.dispose();
    summaryController.dispose();
  }
}

Future<void> deleteCircleTutorial(
  BuildContext context,
  LibraryProvider library,
  CircleTutorial tutorial,
) async {
  if (tutorial.id == null) {
    return;
  }
  final confirmed = await confirmDialog(
    context,
    title: context.t('Delete tutorial'),
    message: context.t('Delete "{name}"?', {'name': tutorial.title}),
  );
  if (!confirmed) {
    return;
  }
  final deleted = await library.deleteCircleTutorial(tutorial.id!);
  if (context.mounted) {
    if (deleted) {
      Navigator.of(context).maybePop();
    }
    _showSnack(
      context,
      deleted
          ? context.t('Tutorial deleted')
          : library.errorMessage ?? context.t('Delete failed'),
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  const _EmbeddedHeader({required this.title, required this.onAdd});

  final String title;
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
          IconButton(
            tooltip: context.t('Add tutorial'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _CircleImage extends StatelessWidget {
  const _CircleImage({required this.tutorial});

  final CircleTutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final path = tutorial.imagePath;
    if (path == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FullscreenImageScreen(path: path, title: tutorial.title),
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

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
