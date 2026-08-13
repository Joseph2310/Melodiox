enum SongSortField {
  manual,
  alphabetical,
  newest,
  oldest,
  recentlyUpdated,
  favoriteFirst,
  rhythm,
  key,
  bpm,
  tag,
}

enum SortDirection { ascending, descending }

class SongSort {
  const SongSort({
    this.field = SongSortField.alphabetical,
    this.direction = SortDirection.ascending,
  });

  final SongSortField field;
  final SortDirection direction;

  SongSort copyWith({SongSortField? field, SortDirection? direction}) {
    return SongSort(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }
}
