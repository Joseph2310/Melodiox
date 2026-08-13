import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

class ShellNavigationScope extends InheritedWidget {
  const ShellNavigationScope({
    required this.canGoBack,
    required this.onBack,
    required super.child,
    super.key,
  });

  final bool canGoBack;
  final VoidCallback onBack;

  static ShellNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellNavigationScope>();
  }

  @override
  bool updateShouldNotify(ShellNavigationScope oldWidget) {
    return canGoBack != oldWidget.canGoBack || onBack != oldWidget.onBack;
  }
}

class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  static Widget? leading(BuildContext context) {
    final shellNavigation = ShellNavigationScope.maybeOf(context);
    if (shellNavigation?.canGoBack != true) {
      return null;
    }
    return const ShellBackButton();
  }

  @override
  Widget build(BuildContext context) {
    final shellNavigation = ShellNavigationScope.maybeOf(context);
    if (shellNavigation?.canGoBack != true) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: context.t('Back'),
      onPressed: shellNavigation!.onBack,
      icon: const Icon(Icons.arrow_back),
    );
  }
}
