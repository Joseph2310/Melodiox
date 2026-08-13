import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/bidi_text.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/lyrics_library_entry.dart';
import '../../domain/repositories/lyrics_library_repository.dart';
import '../../services/backup_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/shell_navigation_scope.dart';

List<String> lyricsSlidesFromText(String? value) {
  final text = value?.replaceAll('\r\n', '\n').trim() ?? '';
  if (text.isEmpty) {
    return const [];
  }
  return text
      .split(RegExp(r'\n\s*---+\s*\n'))
      .map((slide) => slide.trim())
      .where((slide) => slide.isNotEmpty)
      .toList(growable: false);
}

class LyricsSlideViewer extends StatefulWidget {
  const LyricsSlideViewer({
    required this.slides,
    this.title,
    this.height,
    this.compact = false,
    super.key,
  });

  final List<String> slides;
  final String? title;
  final double? height;
  final bool compact;

  @override
  State<LyricsSlideViewer> createState() => _LyricsSlideViewerState();
}

class _LyricsSlideViewerState extends State<LyricsSlideViewer> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.compact ? 8 : 0),
      ),
      child: slides.isEmpty
          ? Center(
              child: Text(
                context.t('No lyrics'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    return _LyricsSlide(
                      text: slides[index],
                      compact: widget.compact,
                    );
                  },
                ),
                PositionedDirectional(
                  start: 12,
                  bottom: 10,
                  child:
                      _SlideCounter(current: _page + 1, total: slides.length),
                ),
                if (slides.length > 1)
                  PositionedDirectional(
                    end: 10,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          tooltip: context.t('Previous slide'),
                          onPressed: _page == 0
                              ? null
                              : () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: context.t('Next slide'),
                          onPressed: _page >= slides.length - 1
                              ? null
                              : () => _controller.nextPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    if (widget.height == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 8 : 0),
        child: content,
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 8 : 0),
        child: content,
      ),
    );
  }
}

class _LyricsSlide extends StatelessWidget {
  const _LyricsSlide({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final direction = textDirectionForText(text);
    final settings = context.watch<SettingsProvider>();
    final fontSize = (settings.lyricsFontSize * (compact ? 0.9 : 1))
        .clamp(18, 44)
        .toDouble();
    return Directionality(
      textDirection: direction,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 28,
          compact ? 28 : 36,
          compact ? 20 : 28,
          compact ? 46 : 54,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              text,
              textAlign: TextAlign.center,
              softWrap: true,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    height: 1.85,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideCounter extends StatelessWidget {
  const _SlideCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '$current / $total',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}

class LyricsLibraryScreen extends StatefulWidget {
  const LyricsLibraryScreen({super.key});

  @override
  State<LyricsLibraryScreen> createState() => _LyricsLibraryScreenState();
}

class _LyricsLibraryScreenState extends State<LyricsLibraryScreen> {
  static const _pageSize = 300;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  var _entries = <LyricsLibraryEntry>[];
  var _totalEntries = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  String? _busyMessage;
  final _selectedIds = <int>{};
  var _sortMode = _LyricsSortMode.titleAsc;
  var _loadSerial = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_scheduleLoad);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_scheduleLoad)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selectedIds.isNotEmpty;
    final searching = _searchController.text.trim().isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selecting
              ? IconButton(
                  tooltip: context.t('Clear selection'),
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close),
                )
              : ShellBackButton.leading(context),
          title: Text(
            selecting
                ? context.t('{count} selected', {'count': _selectedIds.length})
                : context.t('Lyrics library'),
          ),
          actions: selecting
              ? [
                  IconButton(
                    tooltip: context.t('Select all visible'),
                    onPressed: _toggleSelectAllVisible,
                    icon: Icon(
                      _allVisibleSelected
                          ? Icons.deselect_outlined
                          : Icons.select_all_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('Delete selected'),
                    onPressed: _deleteSelectedEntries,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]
              : [
                  PopupMenuButton<_LyricsSortMode>(
                    tooltip: context.t('Sort lyrics'),
                    icon: const Icon(Icons.sort),
                    enabled: !searching,
                    initialValue: _sortMode,
                    onSelected: (value) {
                      setState(() {
                        _sortMode = value;
                      });
                      _load();
                    },
                    itemBuilder: (context) => [
                      for (final mode in _LyricsSortMode.values)
                        PopupMenuItem(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(mode.icon),
                              const SizedBox(width: 12),
                              Text(context.t(mode.label)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<_LyricsLibraryAction>(
                    tooltip: context.t('Lyrics actions'),
                    icon: const Icon(Icons.more_vert),
                    enabled: _busyMessage == null,
                    onSelected: _handleAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _LyricsLibraryAction.add,
                        child: Row(
                          children: [
                            const Icon(Icons.add),
                            const SizedBox(width: 12),
                            Text(context.t('Add lyrics entry')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _LyricsLibraryAction.importJson,
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file_outlined),
                            const SizedBox(width: 12),
                            Text(context.t('Import JSON')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _LyricsLibraryAction.exportJson,
                        child: Row(
                          children: [
                            const Icon(Icons.download_outlined),
                            const SizedBox(width: 12),
                            Text(context.t('Export lyrics library JSON')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: context.t('Search lyrics library'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.t('Clear search'),
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const _Tasbe7naRightsNotice(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      searching
                          ? context.t(
                              '{loaded} of {total} search results',
                              {
                                'loaded': _entries.length,
                                'total': _totalEntries,
                              },
                            )
                          : context.t(
                              '{loaded} of {total} lyrics entries',
                              {
                                'loaded': _entries.length,
                                'total': _totalEntries,
                              },
                            ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _entries.isEmpty
                          ? EmptyState(
                              icon: Icons.article_outlined,
                              title: context.t('No lyrics entries'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _entries.length + (_hasMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index >= _entries.length) {
                                    return const _LyricsLoadMoreFooter();
                                  }
                                  final entry = _entries[index];
                                  final id = entry.id;
                                  final selected =
                                      id != null && _selectedIds.contains(id);
                                  return _LyricsEntryCard(
                                    entry: entry,
                                    selected: selected,
                                    selecting: selecting,
                                    onPreview: () {
                                      if (selecting) {
                                        _toggleEntrySelection(entry);
                                      } else {
                                        _openPreview(entry);
                                      }
                                    },
                                    onSelect: () =>
                                        _toggleEntrySelection(entry),
                                    onEdit: () => _openEditor(entry),
                                    onDelete: () => _deleteEntry(entry),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
            if (_busyMessage case final message?)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.scrim.withValues(alpha: 0.45),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    if (mounted) {
      setState(() => _loading = true);
    }
    final repository = context.read<LyricsLibraryRepository>();
    final query = _searchController.text.trim();
    final total = await repository.countEntries(query: query);
    final entries = await repository.getEntries(
      query: query,
      limit: _pageSize,
      sort: _repositorySortMode(_sortMode),
    );
    if (!mounted || serial != _loadSerial) {
      return;
    }
    setState(() {
      _entries = entries;
      _totalEntries = total;
      _hasMore = _entries.length < _totalEntries;
      _loadingMore = false;
      final visibleIds = _entries.map((entry) => entry.id).whereType<int>();
      _selectedIds.removeWhere((id) => !visibleIds.contains(id));
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }
    final serial = _loadSerial;
    final repository = context.read<LyricsLibraryRepository>();
    final query = _searchController.text.trim();
    setState(() => _loadingMore = true);
    final entries = await repository.getEntries(
      query: query,
      limit: _pageSize,
      offset: _entries.length,
      sort: _repositorySortMode(_sortMode),
    );
    if (!mounted || serial != _loadSerial) {
      return;
    }
    setState(() {
      _entries.addAll(entries);
      _hasMore = entries.isNotEmpty && _entries.length < _totalEntries;
      _loadingMore = false;
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 700) {
      _loadMore();
    }
  }

  LyricsLibrarySort _repositorySortMode(_LyricsSortMode mode) {
    return switch (mode) {
      _LyricsSortMode.titleAsc => LyricsLibrarySort.titleAsc,
      _LyricsSortMode.titleDesc => LyricsLibrarySort.titleDesc,
      _LyricsSortMode.newest => LyricsLibrarySort.newest,
      _LyricsSortMode.oldest => LyricsLibrarySort.oldest,
      _LyricsSortMode.mostSlides => LyricsLibrarySort.mostSlides,
      _LyricsSortMode.source => LyricsLibrarySort.source,
    };
  }

  bool get _allVisibleSelected {
    final visibleIds = _entries.map((entry) => entry.id).whereType<int>();
    return visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);
  }

  void _toggleSelectAllVisible() {
    final visibleIds = _entries.map((entry) => entry.id).whereType<int>();
    setState(() {
      if (_allVisibleSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  void _toggleEntrySelection(LyricsLibraryEntry entry) {
    final id = entry.id;
    if (id == null) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  void _scheduleLoad() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        _load();
      }
    });
  }

  void _handleAction(_LyricsLibraryAction action) {
    switch (action) {
      case _LyricsLibraryAction.add:
        _openEditor();
        return;
      case _LyricsLibraryAction.importJson:
        _importFromJson();
        return;
      case _LyricsLibraryAction.exportJson:
        _exportJson();
        return;
    }
  }

  Future<void> _importFromJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || !mounted) {
      return;
    }

    final confirmed = await confirmDialog(
      context,
      title: context.t('Import lyrics JSON'),
      message: context.t(
        'This will merge the selected lyrics into the library. Custom entries will stay saved.',
      ),
      confirmLabel: context.t('Import'),
    );
    if (!confirmed || !mounted) {
      return;
    }

    final repository = context.read<LyricsLibraryRepository>();
    setState(() => _busyMessage = context.t('Importing lyrics JSON'));
    try {
      final source = await _readPickedJson(result.files.single);
      final count = await repository.importFromJson(source);
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        context.t('Lyrics JSON imported', {'count': count}),
      );
    } catch (error) {
      if (mounted) {
        _showSnack(
          context,
          '${context.t('Import failed')}: ${_lyricsErrorMessage(context, error)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyMessage = null;
          _loading = false;
        });
      }
    }
  }

  Future<String> _readPickedJson(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) {
      return utf8.decode(bytes);
    }
    final path = file.path;
    if (path == null) {
      throw const FileSystemException('Selected file has no readable path.');
    }
    return File(path).readAsString();
  }

  Future<void> _exportJson() async {
    final target = await _chooseExportTarget();
    if (target == null || !mounted) {
      return;
    }
    setState(() => _busyMessage = context.t('Exporting lyrics library'));
    try {
      final repository = context.read<LyricsLibraryRepository>();
      final json = await repository.exportJson();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      if (!mounted) {
        return;
      }
      final path = await FilePicker.saveFile(
        dialogTitle: target == BackupStorageTarget.drive
            ? context.t('Export lyrics library to Drive')
            : context.t('Export lyrics library'),
        fileName: 'melodiox_lyrics_library_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (mounted) {
        _showSnack(
          context,
          path == null
              ? context.t('Export cancelled')
              : context.t('Lyrics library exported'),
        );
      }
    } catch (error) {
      if (mounted) {
        _showSnack(context, '${context.t('Export failed')}: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyMessage = null);
      }
    }
  }

  Future<BackupStorageTarget?> _chooseExportTarget() {
    return showModalBottomSheet<BackupStorageTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(context.t('Save locally')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(context.t('Save to Google Drive')),
              subtitle: Text(context.t('Choose Drive in the save picker')),
              onTap: () => Navigator.of(context).pop(BackupStorageTarget.drive),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreview(LyricsLibraryEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LyricsLibraryPreviewScreen(entry: entry),
      ),
    );
  }

  Future<void> _openEditor([LyricsLibraryEntry? entry]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LyricsLibraryEditorScreen(entry: entry),
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteEntry(LyricsLibraryEntry entry) async {
    final id = entry.id;
    if (id == null) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete lyrics entry'),
      message: context.t('Delete "{name}"?', {'name': entry.title}),
      confirmLabel: context.t('Delete'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    await context.read<LyricsLibraryRepository>().deleteEntry(id);
    if (!mounted) {
      return;
    }
    await _load();
    if (mounted) {
      _showSnack(context, context.t('Lyrics entry deleted'));
    }
  }

  Future<void> _deleteSelectedEntries() async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: context.t('Delete selected lyrics'),
      message: context.t(
        'Delete {count} selected lyrics entries?',
        {'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final repository = context.read<LyricsLibraryRepository>();
    for (final id in ids) {
      await repository.deleteEntry(id);
    }
    if (!mounted) {
      return;
    }
    _clearSelection();
    await _load();
    if (mounted) {
      _showSnack(context, context.t('Lyrics entries deleted'));
    }
  }
}

class _Tasbe7naRightsNotice extends StatelessWidget {
  const _Tasbe7naRightsNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Tooltip(
          message: context.t('Lyrics rights are preserved for tasbe7na.com'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copyright_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t('Lyrics rights: tasbe7na.com'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsLoadMoreFooter extends StatelessWidget {
  const _LyricsLoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

enum _LyricsSortMode {
  titleAsc('Title A-Z', Icons.sort_by_alpha),
  titleDesc('Title Z-A', Icons.sort_by_alpha),
  newest('Newest first', Icons.update),
  oldest('Oldest first', Icons.history),
  mostSlides('Most slides', Icons.view_carousel_outlined),
  source('Source', Icons.source_outlined);

  const _LyricsSortMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _LyricsLibraryAction {
  add,
  importJson,
  exportJson,
}

class LyricsLibraryPickerScreen extends StatefulWidget {
  const LyricsLibraryPickerScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  State<LyricsLibraryPickerScreen> createState() =>
      _LyricsLibraryPickerScreenState();
}

class _LyricsLibraryPickerScreenState extends State<LyricsLibraryPickerScreen> {
  late final TextEditingController _searchController;
  var _entries = <LyricsLibraryEntry>[];
  var _loading = true;
  var _loadSerial = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchController.addListener(_scheduleLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_scheduleLoad)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Import lyrics'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.t('Search lyrics library'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.t('Clear search'),
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? EmptyState(
                        icon: Icons.article_outlined,
                        title: context.t('No lyrics found'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _LyricsEntryCard(
                            entry: entry,
                            onPreview: () => _openImportPreview(entry),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    if (mounted) {
      setState(() => _loading = true);
    }
    final query = _searchController.text.trim();
    final entries = await context.read<LyricsLibraryRepository>().getEntries(
          query: query,
          limit: query.isEmpty ? 300 : 600,
        );
    if (!mounted || serial != _loadSerial) {
      return;
    }
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _scheduleLoad() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _openImportPreview(LyricsLibraryEntry entry) async {
    final selected = await Navigator.of(context).push<LyricsLibraryEntry>(
      MaterialPageRoute<LyricsLibraryEntry>(
        builder: (_) => LyricsLibraryPreviewScreen(
          entry: entry,
          allowImport: true,
        ),
      ),
    );
    if (selected != null && mounted) {
      Navigator.of(context).pop(selected);
    }
  }
}

class LyricsLibraryPreviewScreen extends StatelessWidget {
  const LyricsLibraryPreviewScreen({
    required this.entry,
    this.allowImport = false,
    super.key,
  });

  final LyricsLibraryEntry entry;
  final bool allowImport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: LyricsSlideViewer(slides: entry.slides),
              ),
              if (allowImport) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(entry),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(context.t('Use these lyrics')),
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

class LyricsLibraryEditorScreen extends StatefulWidget {
  const LyricsLibraryEditorScreen({this.entry, super.key});

  final LyricsLibraryEntry? entry;

  @override
  State<LyricsLibraryEditorScreen> createState() =>
      _LyricsLibraryEditorScreenState();
}

class _LyricsLibraryEditorScreenState extends State<LyricsLibraryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _chorusController;
  late final TextEditingController _verseSlidesController;
  late bool _chorusFirst;
  var _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _chorusController = TextEditingController(
      text: entry == null ? '' : entry.chorusSlides.join('\n\n---\n\n'),
    );
    _verseSlidesController = TextEditingController(
      text: entry == null ? '' : entry.verseSlides.join('\n\n---\n\n'),
    );
    _chorusFirst = entry?.chorusFirst ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _chorusController.dispose();
    _verseSlidesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chorusSlides = lyricsSlidesFromText(_chorusController.text);
    final verseSlides = lyricsSlidesFromText(_verseSlidesController.text);
    final previewEntry = LyricsLibraryEntry.fromParts(
      title: _titleController.text,
      verseSlides: verseSlides,
      chorusSlides: chorusSlides,
      chorusFirst: _chorusFirst,
    );
    final previewSlides = previewEntry.slides;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t(_isEditing ? 'Edit lyrics entry' : 'Add lyrics entry'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(context.t('Save')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.t('Title'),
                prefixIcon: const Icon(Icons.title),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.t('Title is required');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.repeat_outlined),
              title: Text(context.t('Show chorus first')),
              subtitle: Text(
                context.t('The chorus is also shown after every verse slide.'),
              ),
              value: _chorusFirst,
              onChanged: (value) => setState(() => _chorusFirst = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _chorusController,
              minLines: 4,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.t('Chorus'),
                alignLabelWithHint: true,
                helperText:
                    context.t('Optional. Separate chorus slides with ---'),
                prefixIcon: const Icon(Icons.repeat_outlined),
              ),
              textDirection:
                  textDirectionForText(_chorusController.text.trim()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _RepeatMarkerButtons(
              onInsert: (count) => _insertRepeatMarker(
                _chorusController,
                count,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _verseSlidesController,
              minLines: 10,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.t('Verse slides'),
                alignLabelWithHint: true,
                helperText: context.t('Separate verse slides with ---'),
                prefixIcon: const Icon(Icons.view_carousel_outlined),
              ),
              textDirection:
                  textDirectionForText(_verseSlidesController.text.trim()),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (lyricsSlidesFromText(value).isEmpty &&
                    lyricsSlidesFromText(_chorusController.text).isEmpty) {
                  return context.t('Add at least one verse or chorus slide');
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _RepeatMarkerButtons(
              onInsert: (count) => _insertRepeatMarker(
                _verseSlidesController,
                count,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('{count} slides', {'count': previewSlides.length}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            LyricsSlideViewer(
              slides: previewSlides,
              height: 320,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final existing = widget.entry;
    final entry = LyricsLibraryEntry.fromParts(
      id: existing?.id,
      title: _titleController.text.trim(),
      verseSlides: lyricsSlidesFromText(_verseSlidesController.text),
      chorusSlides: lyricsSlidesFromText(_chorusController.text),
      chorusFirst: _chorusFirst,
      createdAt: existing?.createdAt,
    );
    await context.read<LyricsLibraryRepository>().saveEntry(entry);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    _showSnack(context, context.t('Lyrics entry saved'));
    Navigator.of(context).pop(true);
  }

  void _insertRepeatMarker(TextEditingController controller, int count) {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(0, text.length).toInt();
    final selected = text.substring(safeStart, safeEnd);
    final opening = _lyricsRepeatOpeningMarker(count);
    final replacement = selected.isEmpty ? '$opening)' : '$opening$selected)';
    final nextText = text.replaceRange(safeStart, safeEnd, replacement);
    final cursorOffset = selected.isEmpty
        ? safeStart + opening.length
        : safeStart + replacement.length;
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
    setState(() {});
  }
}

class _RepeatMarkerButtons extends StatelessWidget {
  const _RepeatMarkerButtons({required this.onInsert});

  final ValueChanged<int> onInsert;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            context.t('Repeat marker'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          for (final count in const [2, 3, 4])
            OutlinedButton.icon(
              onPressed: () => onInsert(count),
              icon: const Icon(Icons.repeat, size: 18),
              label: Text(_lyricsRepeatSuperscript(count)),
            ),
        ],
      ),
    );
  }
}

String _lyricsRepeatOpeningMarker(int count) {
  return '${_lyricsRepeatSuperscript(count)}(';
}

String _lyricsRepeatSuperscript(int value) {
  const digits = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
  };
  return value
      .toString()
      .split('')
      .map((digit) => digits[digit] ?? digit)
      .join();
}

class _LyricsEntryCard extends StatelessWidget {
  const _LyricsEntryCard({
    required this.entry,
    required this.onPreview,
    this.selected = false,
    this.selecting = false,
    this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  final LyricsLibraryEntry entry;
  final VoidCallback onPreview;
  final bool selected;
  final bool selecting;
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: selecting
            ? Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
              )
            : Icon(
                entry.source == LyricsLibraryEntry.tasbe7naSource
                    ? Icons.article
                    : Icons.article_outlined,
              ),
        title: BidiText(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          context.t('{count} slides', {'count': entry.slideCount}),
        ),
        trailing: selecting
            ? IconButton(
                tooltip:
                    context.t(selected ? 'Unselect lyrics' : 'Select lyrics'),
                onPressed: onSelect,
                icon: Icon(
                  selected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank_outlined,
                ),
              )
            : onEdit == null && onDelete == null
                ? const Icon(Icons.chevron_right)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('Edit'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: context.t('Delete'),
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
        onTap: onPreview,
        onLongPress: onSelect,
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _lyricsErrorMessage(BuildContext context, Object error) {
  return context.t(error.toString());
}
