import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities/song_sort.dart';

class SortSheet extends StatefulWidget {
  const SortSheet({
    required this.initialSort,
    required this.onApply,
    super.key,
  });

  final SongSort initialSort;
  final ValueChanged<SongSort> onApply;

  @override
  State<SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<SortSheet> {
  late SongSortField _field;
  late SortDirection _direction;

  @override
  void initState() {
    super.initState();
    _field = widget.initialSort.field;
    _direction = widget.initialSort.direction;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.t('Sort'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_field != SongSortField.manual) ...[
            SegmentedButton<SortDirection>(
              segments: [
                ButtonSegment(
                  value: SortDirection.ascending,
                  icon: const Icon(Icons.north),
                  label: Text(context.t('Ascending')),
                ),
                ButtonSegment(
                  value: SortDirection.descending,
                  icon: const Icon(Icons.south),
                  label: Text(context.t('Descending')),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (value) {
                setState(() => _direction = value.first);
              },
            ),
            const SizedBox(height: 8),
          ],
          for (final field in SongSortField.values)
            ListTile(
              leading: Icon(
                _field == field
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(context.t(_labelForField(field))),
              selected: _field == field,
              onTap: () => setState(() => _field = field),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              widget.onApply(SongSort(field: _field, direction: _direction));
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check),
            label: Text(context.t('Apply')),
          ),
        ],
      ),
    );
  }

  String _labelForField(SongSortField field) {
    return switch (field) {
      SongSortField.manual => 'Manual order',
      SongSortField.alphabetical => 'Alphabetical',
      SongSortField.newest => 'Newest',
      SongSortField.oldest => 'Oldest',
      SongSortField.recentlyUpdated => 'Recently updated',
      SongSortField.favoriteFirst => 'Favorite first',
      SongSortField.rhythm => 'Rhythm',
      SongSortField.key => 'Key',
      SongSortField.bpm => 'BPM',
      SongSortField.tag => 'Tag',
    };
  }
}
