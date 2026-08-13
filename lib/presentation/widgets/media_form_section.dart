import 'package:flutter/material.dart';

import '../../core/constants/media_types.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';

class MediaFormSection extends StatelessWidget {
  const MediaFormSection({
    required this.media,
    required this.onAdd,
    required this.onRemove,
    this.availableTypes = MediaType.values,
    super.key,
  });

  final List<MediaItem> media;
  final ValueChanged<MediaType> onAdd;
  final ValueChanged<MediaItem> onRemove;
  final List<MediaType> availableTypes;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.perm_media_outlined),
      title: Text(context.t('Media')),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in availableTypes)
              OutlinedButton.icon(
                onPressed: () => onAdd(type),
                icon: Icon(_iconForType(type)),
                label: Text(context.t(type.label)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (media.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.t('No media added')),
          )
        else
          for (var index = 0; index < media.length; index++)
            ListTile(
              leading: Icon(_iconForType(media[index].mediaType)),
              title: Text(media[index].title),
              subtitle: Text(
                media[index].externalUrl ?? media[index].localPath ?? '',
              ),
              trailing: IconButton(
                tooltip: context.t('Remove'),
                onPressed: () => onRemove(media[index]),
                icon: const Icon(Icons.close),
              ),
            ),
      ],
    );
  }

  IconData _iconForType(MediaType type) {
    return switch (type) {
      MediaType.chordImage => Icons.image_outlined,
      MediaType.melodyImage => Icons.graphic_eq_outlined,
      MediaType.songAudio => Icons.audiotrack_outlined,
      MediaType.vocalAudio => Icons.record_voice_over_outlined,
      MediaType.performanceVideo => Icons.movie_outlined,
    };
  }
}
