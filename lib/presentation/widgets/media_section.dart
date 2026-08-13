import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';
import '../../services/link_service.dart';
import '../screens/media_viewer_screen.dart';

class MediaSection extends StatelessWidget {
  const MediaSection({required this.media, required this.type, super.key});

  final List<MediaItem> media;
  final MediaType type;

  @override
  Widget build(BuildContext context) {
    final items = media.where((item) => item.mediaType == type).toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.t('No items')),
      );
    }

    if (type == MediaType.chordImage || type == MediaType.melodyImage) {
      return _ImageGrid(items: items);
    }

    return Column(
      children: [
        for (final item in items)
          type == MediaType.performanceVideo
              ? _VideoTile(media: item)
              : _AudioTile(media: item),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final path = item.localPath;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openImage(context, item),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: path == null || path.trim().isEmpty
                ? const Icon(Icons.link)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openImage(BuildContext context, MediaItem item) async {
    if (item.isExternal) {
      final opened = await LinkService.openExternal(item.externalUrl!);
      if (!opened && context.mounted) {
        _showSnack(context, context.t('Unable to open link'));
      }
      return;
    }
    final path = item.localPath;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    if (!await File(path).exists()) {
      if (context.mounted) {
        _showSnack(context, context.t('Image file was not found'));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final viewerItems = <ImageViewerItem>[];
    var initialIndex = 0;
    for (final candidate in items) {
      if (candidate.isExternal) {
        continue;
      }
      final candidatePath = candidate.localPath;
      if (candidatePath == null || candidatePath.trim().isEmpty) {
        continue;
      }
      if (candidatePath == path) {
        initialIndex = viewerItems.length;
      }
      viewerItems.add(
        ImageViewerItem(path: candidatePath, title: candidate.title),
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenImageScreen(
          path: path,
          title: item.title,
          items: viewerItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.media});

  final MediaItem media;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.movie_outlined),
      title: Text(media.title),
      subtitle: Text(
        media.isExternal ? context.t('External link') : media.localPath ?? '',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (media.isExternal) {
      final opened = await LinkService.openExternal(media.externalUrl!);
      if (!opened && context.mounted) {
        _showSnack(context, context.t('Unable to open link'));
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VideoPlayerScreen(media: media)),
    );
  }
}

class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.media});

  final MediaItem media;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.audiotrack_outlined),
      title: Text(widget.media.title),
      subtitle: Text(
        widget.media.isExternal
            ? context.t('External link')
            : widget.media.localPath ?? '',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _open,
    );
  }

  Future<void> _open() async {
    if (widget.media.isExternal) {
      final opened = await LinkService.openExternal(widget.media.externalUrl!);
      if (!opened && mounted) {
        _showSnack(context, context.t('Unable to open link'));
      }
      return;
    }

    final path = widget.media.localPath;
    if (path == null || path.trim().isEmpty || !await File(path).exists()) {
      if (mounted) {
        _showSnack(context, context.t('Audio file was not found'));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AudioPlayerScreen(media: widget.media),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
