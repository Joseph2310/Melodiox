import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/app_localizations.dart';
import 'core/themes/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/widgets/app_shell.dart';
import 'presentation/widgets/mini_audio_player.dart';

class PersonalHymnsApp extends StatelessWidget {
  const PersonalHymnsApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Melodiox',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.night(),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Stack(
            children: [
              _EdgeBackGesture(
                navigatorKey: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              ),
              MiniAudioPlayerOverlay(navigatorKey: _navigatorKey),
            ],
          ),
          home: const AppShell(),
        );
      },
    );
  }
}

class _EdgeBackGesture extends StatefulWidget {
  const _EdgeBackGesture({
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_EdgeBackGesture> createState() => _EdgeBackGestureState();
}

class _EdgeBackGestureState extends State<_EdgeBackGesture> {
  static const _edgeWidth = 28.0;
  static const _triggerDistance = 72.0;

  int? _pointer;
  Offset? _start;
  bool _fromLeftEdge = false;
  bool _fromRightEdge = false;
  var _didPop = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _clearGesture,
      onPointerCancel: _clearGesture,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final width = MediaQuery.sizeOf(context).width;
    final x = event.localPosition.dx;
    final fromLeftEdge = x <= _edgeWidth;
    final fromRightEdge = x >= width - _edgeWidth;
    if (!fromLeftEdge && !fromRightEdge) {
      return;
    }

    _pointer = event.pointer;
    _start = event.localPosition;
    _fromLeftEdge = fromLeftEdge;
    _fromRightEdge = fromRightEdge;
    _didPop = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _start;
    if (_pointer != event.pointer || start == null || _didPop) {
      return;
    }

    final delta = event.localPosition - start;
    final inwardDistance = _fromLeftEdge
        ? delta.dx
        : _fromRightEdge
            ? -delta.dx
            : 0.0;
    if (inwardDistance < _triggerDistance || inwardDistance <= delta.dy.abs()) {
      return;
    }

    _didPop = true;
    widget.navigatorKey.currentState?.maybePop();
  }

  void _clearGesture(PointerEvent event) {
    if (_pointer != event.pointer) {
      return;
    }
    _pointer = null;
    _start = null;
    _fromLeftEdge = false;
    _fromRightEdge = false;
    _didPop = false;
  }
}
