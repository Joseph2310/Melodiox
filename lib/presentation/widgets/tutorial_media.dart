import 'dart:io';

import 'package:flutter/material.dart';

const tutorialAssetPrefix = 'asset://';

bool isTutorialAssetPath(String? path) {
  return path != null && path.startsWith(tutorialAssetPrefix);
}

String tutorialDisplayPath(String path) {
  return isTutorialAssetPath(path)
      ? path.substring(tutorialAssetPrefix.length)
      : path;
}

class TutorialThumbnail extends StatelessWidget {
  const TutorialThumbnail({
    required this.path,
    required this.fallbackIcon,
    this.size = 48,
    super.key,
  });

  final String? path;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.trim().isEmpty) {
      return Icon(fallbackIcon);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _TutorialImage(
          path: value,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class TutorialHeroImage extends StatelessWidget {
  const TutorialHeroImage({
    required this.path,
    this.height = 260,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String path;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _TutorialImage(
          path: path,
          height: height,
          width: double.infinity,
          fit: fit,
        ),
      ),
    );
  }
}

class TutorialFullImage extends StatelessWidget {
  const TutorialFullImage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: _TutorialImage(
        path: path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _TutorialImage extends StatelessWidget {
  const _TutorialImage({
    required this.path,
    this.width,
    this.height,
    this.fit,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (isTutorialAssetPath(path)) {
      return Image.asset(
        tutorialDisplayPath(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _brokenImage(context),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _brokenImage(context),
    );
  }

  Widget _brokenImage(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined, size: 40),
    );
  }
}
