import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_sort.dart';
import '../providers/library_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/shell_navigation_scope.dart';
import '../widgets/song_card.dart';
import '../widgets/sort_sheet.dart';
import 'song_details_screen.dart';
import 'song_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.favoritesOnly = false,
    this.title = 'Songs',
    this.onBackHandlerChanged,
    super.key,
  });

  final bool favoritesOnly;
  final String title;
  final ValueChanged<VoidCallback?>? onBackHandlerChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _selectedSongIds = <int>{};
  var _showSearch = false;

  @override
  void dispose() {
    widget.onBackHandlerChanged?.call(null);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBackHandlerChanged != widget.onBackHandlerChanged) {
      oldWidget.onBackHandlerChanged?.call(null);
      _syncBackHandler();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final songs =
            widget.favoritesOnly ? library.favoriteSongs : library.visibleSongs;
        final selectionMode = _selectedSongIds.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            leading: selectionMode || !widget.favoritesOnly
                ? null
                : ShellBackButton.leading(context),
            title: Text(
              selectionMode
                  ? context.t(
                      '{count} selected',
                      {'count': _selectedSongIds.length},
                    )
                  : context.t(widget.title),
            ),
            actions: selectionMode
                ? [
                    IconButton(
                      tooltip: context.t('Select all visible'),
                      onPressed: () => _selectAllVisible(songs),
                      icon: const Icon(Icons.select_all),
                    ),
                    IconButton(
                      tooltip: context.t('Add to playlists'),
                      onPressed: () => _bulkAddToPlaylists(context, library),
                      icon: const Icon(Icons.playlist_add),
                    ),
                    IconButton(
                      tooltip: context.t('Delete selected'),
                      onPressed: () => _bulkDelete(context, library),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: context.t('Clear selection'),
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close),
                    ),
                  ]
                : [
                    IconButton(
                      tooltip: context.t('Search'),
                      onPressed: _toggleSearch,
                      icon: Icon(_showSearch ? Icons.search_off : Icons.search),
                    ),
                    IconButton(
                      tooltip: context.t('Filter'),
                      onPressed: () => _showFilters(context, library),
                      icon: Icon(
                        library.filter.hasActiveFilters
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Sort'),
                      onPressed: () => _showSort(context, library),
                      icon: const Icon(Icons.sort),
                    ),
                    IconButton(
                      tooltip: context.t('Add song'),
                      onPressed: () => _openForm(context),
                      icon: const Icon(Icons.add),
                    ),
                  ],
            bottom: _showSearch && !selectionMode
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(68),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: context.t('Search hymns'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.t('Clear search'),
                                  onPressed: () {
                                    _searchController.clear();
                                    library.setSearchQuery('');
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                        onChanged: (value) {
                          library.setSearchQuery(value);
                          setState(() {});
                        },
                      ),
                    ),
                  )
                : null,
          ),
          body: _buildBody(context, library, songs),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    LibraryProvider library,
    List<Song> songs,
  ) {
    if (library.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (library.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: context.t('Library unavailable'),
        subtitle: library.errorMessage,
        action: FilledButton.icon(
          onPressed: library.load,
          icon: const Icon(Icons.refresh),
          label: Text(context.t('Retry')),
        ),
      );
    }
    if (songs.isEmpty) {
      return EmptyState(
        icon: widget.favoritesOnly
            ? Icons.star_border
            : Icons.library_music_outlined,
        title: widget.favoritesOnly
            ? context.t('No favorite songs')
            : context.t('No songs found'),
        action: widget.favoritesOnly
            ? null
            : FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: Text(context.t('Add song')),
              ),
      );
    }

    final canReorder = _canReorderSongs(library);
    return RefreshIndicator(
      onRefresh: library.load,
      child: canReorder
          ? ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: songs.length,
              onReorderItem: (oldIndex, newIndex) {
                library.reorderSongs(songs, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final song = songs[index];
                return Padding(
                  key: ValueKey('song-${song.id ?? song.name}'),
                  padding: EdgeInsets.only(
                    bottom: index == songs.length - 1 ? 0 : 10,
                  ),
                  child: _buildSongCard(context, song),
                );
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildSongCard(context, songs[index]);
              },
            ),
    );
  }

  Widget _buildSongCard(BuildContext context, Song song) {
    final selected = song.id != null && _selectedSongIds.contains(song.id);
    return SongCard(
      song: song,
      selectionMode: _selectedSongIds.isNotEmpty,
      selected: selected,
      onSelectedChanged: (value) => _setSongSelected(song, value),
      onLongPress: () => _setSongSelected(song, true),
      onTap: () => _selectedSongIds.isEmpty
          ? _openDetails(context, song)
          : _toggleSongSelection(song),
    );
  }

  bool _canReorderSongs(LibraryProvider library) {
    return !widget.favoritesOnly &&
        _selectedSongIds.isEmpty &&
        library.sort.field == SongSortField.manual &&
        library.searchQuery.trim().isEmpty &&
        !library.filter.hasActiveFilters;
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) {
      _searchController.clear();
      context.read<LibraryProvider>().setSearchQuery('');
    }
  }

  void _setSongSelected(Song song, bool selected) {
    final id = song.id;
    if (id == null) {
      return;
    }
    _updateSelection(() {
      if (selected) {
        _selectedSongIds.add(id);
      } else {
        _selectedSongIds.remove(id);
      }
    });
  }

  void _toggleSongSelection(Song song) {
    final id = song.id;
    if (id == null) {
      return;
    }
    _updateSelection(() {
      if (_selectedSongIds.contains(id)) {
        _selectedSongIds.remove(id);
      } else {
        _selectedSongIds.add(id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedSongIds.isEmpty) {
      return;
    }
    _updateSelection(_selectedSongIds.clear);
  }

  void _selectAllVisible(List<Song> songs) {
    final visibleIds = songs.map((song) => song.id).whereType<int>().toSet();
    if (visibleIds.isEmpty) {
      return;
    }
    _updateSelection(() {
      if (visibleIds.every(_selectedSongIds.contains)) {
        _selectedSongIds.removeAll(visibleIds);
      } else {
        _selectedSongIds.addAll(visibleIds);
      }
    });
  }

  void _updateSelection(VoidCallback mutation) {
    setState(mutation);
    _syncBackHandler();
  }

  void _syncBackHandler() {
    widget.onBackHandlerChanged?.call(
      _selectedSongIds.isEmpty ? null : _clearSelection,
    );
  }

  Future<void> _bulkDelete(
    BuildContext context,
    LibraryProvider library,
  ) async {
    final ids = _selectedSongIds.toList();
    if (ids.isEmpty) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete selected songs'),
      message: context.t(
        'Delete {count} selected song(s) from the library?',
        {'count': ids.length},
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    var ok = true;
    for (final id in ids) {
      ok = await library.deleteSong(id) && ok;
    }
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _showSnack(
      context,
      ok
          ? context.t('Songs deleted')
          : library.errorMessage ?? context.t('Delete failed'),
    );
  }

  Future<void> _bulkAddToPlaylists(
    BuildContext context,
    LibraryProvider library,
  ) async {
    final songIds = {..._selectedSongIds};
    if (songIds.isEmpty) {
      return;
    }

    final result = await showDialog<_BulkPlaylistResult>(
      context: context,
      builder: (context) => _BulkPlaylistDialog(playlists: library.playlists),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final activeLibrary = context.read<LibraryProvider>();
    final playlistIds = {...result.selectedPlaylistIds};
    final newPlaylistName = result.newPlaylistName?.trim();
    if (newPlaylistName != null && newPlaylistName.isNotEmpty) {
      await activeLibrary.savePlaylist(
        Playlist(playlistName: newPlaylistName, songIds: const []),
      );
      final created = activeLibrary.playlists.where(
        (playlist) =>
            playlist.playlistName.toLowerCase() ==
            newPlaylistName.toLowerCase(),
      );
      if (created.isNotEmpty && created.first.id != null) {
        playlistIds.add(created.first.id!);
      }
    }

    if (playlistIds.isEmpty) {
      return;
    }

    var ok = true;
    for (final playlistId in playlistIds) {
      for (final songId in songIds) {
        ok = await activeLibrary.addSongToPlaylist(playlistId, songId) && ok;
      }
    }
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _showSnack(
      context,
      ok
          ? context.t('Songs added to playlists')
          : activeLibrary.errorMessage ?? context.t('Add failed'),
    );
  }

  void _showFilters(BuildContext context, LibraryProvider library) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FilterSheet(
        initialFilter: widget.favoritesOnly
            ? library.filter.copyWith(favoriteOnly: true)
            : library.filter,
        tags: library.tags,
        songs: library.songs,
        scaleValues: library.scales.map((scale) => scale.displayName).toList(),
        scaleTypes: library.scales
            .map((scale) => scale.type)
            .where((type) => type.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
        onApply: library.setFilter,
        onClear: () =>
            library.clearFilters(keepFavoritesOnly: widget.favoritesOnly),
      ),
    );
  }

  void _showSort(BuildContext context, LibraryProvider library) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          SortSheet(initialSort: library.sort, onApply: library.setSort),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SongFormScreen()));
  }

  Future<void> _openDetails(BuildContext context, Song song) async {
    final id = song.id;
    if (id == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SongDetailsScreen(songId: id)),
    );
  }
}

class _BulkPlaylistDialog extends StatefulWidget {
  const _BulkPlaylistDialog({required this.playlists});

  final List<Playlist> playlists;

  @override
  State<_BulkPlaylistDialog> createState() => _BulkPlaylistDialogState();
}

class _BulkPlaylistDialogState extends State<_BulkPlaylistDialog> {
  final _selectedPlaylistIds = <int>{};
  final _newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newPlaylistController.addListener(_refresh);
  }

  @override
  void dispose() {
    _newPlaylistController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedPlaylistIds.isNotEmpty ||
        _newPlaylistController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(context.t('Add to playlists')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(context.t('No playlists yet')),
                )
              else
                for (final playlist in widget.playlists)
                  CheckboxListTile(
                    value: playlist.id != null &&
                        _selectedPlaylistIds.contains(playlist.id),
                    title: Text(playlist.playlistName),
                    onChanged: playlist.id == null
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selectedPlaylistIds.add(playlist.id!);
                              } else {
                                _selectedPlaylistIds.remove(playlist.id);
                              }
                            });
                          },
                  ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPlaylistController,
                decoration: InputDecoration(
                  labelText: context.t('New playlist'),
                  prefixIcon: const Icon(Icons.add),
                ),
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
          onPressed: canSave
              ? () => Navigator.of(context).pop(
                    _BulkPlaylistResult(
                      selectedPlaylistIds: _selectedPlaylistIds,
                      newPlaylistName:
                          _newPlaylistController.text.trim().isEmpty
                              ? null
                              : _newPlaylistController.text.trim(),
                    ),
                  )
              : null,
          child: Text(context.t('Add')),
        ),
      ],
    );
  }

  void _refresh() => setState(() {});
}

class _BulkPlaylistResult {
  const _BulkPlaylistResult({
    required this.selectedPlaylistIds,
    this.newPlaylistName,
  });

  final Set<int> selectedPlaylistIds;
  final String? newPlaylistName;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
