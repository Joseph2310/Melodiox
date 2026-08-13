import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/chord_tutorial.dart';
import '../screens/media_viewer_screen.dart';
import 'tutorial_media.dart';

class ChordTutorialSection extends StatelessWidget {
  const ChordTutorialSection({
    required this.tutorials,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final List<ChordTutorial> tutorials;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (tutorials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.t('No tutorials')),
      );
    }

    return ListView.separated(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tutorials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tutorial = tutorials[index];
        return Card(
          child: ListTile(
            leading: _Thumbnail(tutorial: tutorial),
            title: Text(tutorial.displayName),
            subtitle: Text(
              [
                tutorial.keys,
                if (tutorial.notes.isNotEmpty)
                  tutorial.notes.map((note) => note.displayTitle).join(', '),
              ].where((value) => value.trim().isNotEmpty).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: tutorial.imagePath == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FullscreenImageScreen(
                          path: tutorial.imagePath!,
                          title: tutorial.displayName,
                        ),
                      ),
                    ),
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.tutorial});

  final ChordTutorial tutorial;

  @override
  Widget build(BuildContext context) {
    return TutorialThumbnail(
      path: tutorial.imagePath,
      fallbackIcon: Icons.school_outlined,
    );
  }
}
