import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import 'chord_tutorials_screen.dart';
import 'circle_tutorials_screen.dart';
import 'scales_screen.dart';
import '../widgets/shell_navigation_scope.dart';

class PianoTutorialsScreen extends StatelessWidget {
  const PianoTutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: ShellBackButton.leading(context),
          title: Text(context.t('Piano Tutorials')),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.school_outlined),
                text: context.t('Chords'),
              ),
              Tab(
                icon: const Icon(Icons.piano_outlined),
                text: context.t('Scales'),
              ),
              Tab(
                icon: const Icon(Icons.circle_outlined),
                text: context.t('Circle'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ChordTutorialsScreen(embedded: true),
            ScalesScreen(embedded: true),
            CircleTutorialsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
