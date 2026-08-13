import 'package:flutter/material.dart';

import 'home_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({this.onBackHandlerChanged, super.key});

  final ValueChanged<VoidCallback?>? onBackHandlerChanged;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      favoritesOnly: true,
      title: 'Favorites',
      onBackHandlerChanged: onBackHandlerChanged,
    );
  }
}
