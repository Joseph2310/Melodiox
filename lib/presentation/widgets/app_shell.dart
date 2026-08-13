import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/lyrics_library_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/piano_tutorials_screen.dart';
import '../screens/playlists_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tag_management_screen.dart';
import 'shell_navigation_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  final _sectionHistory = <int>[];
  final _sectionBackHandlers = <int, VoidCallback>{};
  late final List<Widget> _screens;

  static const _bottomDestinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Songs',
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
    ),
    _ShellDestination(
      label: 'Favorites',
      icon: Icons.star_border,
      selectedIcon: Icons.star,
    ),
    _ShellDestination(
      label: 'Playlists',
      icon: Icons.queue_music_outlined,
      selectedIcon: Icons.queue_music,
    ),
    _ShellDestination(
      label: 'More',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
    ),
  ];

  static const _moreDestinations = <_MoreDestination>[
    _MoreDestination(
      index: 4,
      label: 'Notes',
      icon: Icons.note_alt_outlined,
      selectedIcon: Icons.note_alt,
    ),
    _MoreDestination(
      index: 5,
      label: 'Lyrics library',
      icon: Icons.article_outlined,
      selectedIcon: Icons.article,
    ),
    _MoreDestination(
      index: 6,
      label: 'Piano Tutorials',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
    ),
    _MoreDestination(
      index: 7,
      label: 'Manage',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
    ),
    _MoreDestination(
      index: 8,
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onBackHandlerChanged: (handler) => _setSectionBackHandler(0, handler),
      ),
      FavoritesScreen(
        onBackHandlerChanged: (handler) => _setSectionBackHandler(1, handler),
      ),
      const PlaylistsScreen(),
      _MoreScreen(
        destinations: _moreDestinations,
        onDestinationSelected: _selectDestination,
      ),
      const NotesScreen(),
      const LyricsLibraryScreen(),
      const PianoTutorialsScreen(),
      const TagManagementScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        body: ShellNavigationScope(
          canGoBack: _canGoBack,
          onBack: _goBack,
          child: IndexedStack(index: _selectedIndex, children: _screens),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _bottomIndex,
          onDestinationSelected: _selectBottomDestination,
          destinations: [
            for (final destination in _bottomDestinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: context.t(destination.label),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canGoBack =>
      _sectionBackHandlers.containsKey(_selectedIndex) ||
      _sectionHistory.isNotEmpty;

  int get _bottomIndex {
    return switch (_selectedIndex) {
      0 => 0,
      1 => 1,
      2 => 2,
      _ => 3,
    };
  }

  void _selectBottomDestination(int value) {
    final destination = switch (value) {
      0 => 0,
      1 => 1,
      2 => 2,
      _ => 3,
    };
    _selectDestination(destination);
  }

  void _selectDestination(int value) {
    setState(() {
      if (value != _selectedIndex) {
        _sectionHistory
          ..remove(value)
          ..add(_selectedIndex);
      }
      _selectedIndex = value;
    });
  }

  void _goBack() {
    final handler = _sectionBackHandlers[_selectedIndex];
    if (handler != null) {
      handler();
      return;
    }
    if (_sectionHistory.isEmpty) {
      return;
    }
    setState(() => _selectedIndex = _sectionHistory.removeLast());
  }

  void _setSectionBackHandler(int index, VoidCallback? handler) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (handler == null) {
        _sectionBackHandlers.remove(index);
      } else {
        _sectionBackHandlers[index] = handler;
      }
    });
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.destinations,
    required this.onDestinationSelected,
  });

  final List<_MoreDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ShellBackButton.leading(context),
        title: Text(context.t('More')),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.08,
        ),
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return _MoreCard(
            destination: destination,
            onTap: () => onDestinationSelected(destination.index),
          );
        },
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.destination, required this.onTap});

  final _MoreDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.selectedIcon, size: 36, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                context.t(destination.label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _MoreDestination extends _ShellDestination {
  const _MoreDestination({
    required this.index,
    required super.label,
    required super.icon,
    required super.selectedIcon,
  });

  final int index;
}
