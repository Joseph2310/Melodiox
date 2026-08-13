import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/chord_tutorial.dart';

class ChordTutorialFormSection extends StatelessWidget {
  const ChordTutorialFormSection({
    required this.tutorials,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<ChordTutorial> tutorials;
  final VoidCallback onAdd;
  final ValueChanged<ChordTutorial> onRemove;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.school_outlined),
      title: Text(context.t('Chord Tutorials')),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(context.t('Add tutorial')),
          ),
        ),
        const SizedBox(height: 12),
        if (tutorials.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.t('No tutorials added')),
          )
        else
          for (final tutorial in tutorials)
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(tutorial.displayName),
              subtitle: Text(tutorial.keys),
              trailing: IconButton(
                tooltip: context.t('Remove'),
                onPressed: () => onRemove(tutorial),
                icon: const Icon(Icons.close),
              ),
            ),
      ],
    );
  }
}
