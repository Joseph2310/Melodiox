import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class MediaTrimService {
  static const _channel = MethodChannel('melodiox/media_trimmer');

  Future<void> trimInPlace({
    required String sourcePath,
    required Duration start,
    required Duration end,
  }) async {
    if (sourcePath.trim().isEmpty) {
      throw const MediaTrimException('Media file is missing.');
    }
    if (start < Duration.zero || end <= start) {
      throw const MediaTrimException('Choose a valid start and end time.');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw MediaTrimException('Media file was not found: $sourcePath');
    }

    final directory = path.dirname(sourcePath);
    final extension = path.extension(sourcePath);
    final baseName = path.basenameWithoutExtension(sourcePath);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final outputPath = path.join(
      directory,
      '$baseName.trim.$timestamp$extension',
    );
    final backupPath = path.join(
      directory,
      '$baseName.backup.$timestamp$extension',
    );

    final output = File(outputPath);
    final backup = File(backupPath);
    try {
      await _runTrimCommand(
        sourcePath: sourcePath,
        outputPath: outputPath,
        start: start,
        duration: end - start,
      );

      if (!await output.exists() || await output.length() == 0) {
        throw const MediaTrimException('Trim failed: no output was created.');
      }

      await source.rename(backupPath);
      try {
        await output.rename(sourcePath);
      } catch (_) {
        if (!await source.exists() && await backup.exists()) {
          await backup.rename(sourcePath);
        }
        rethrow;
      }
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (error) {
      if (await output.exists()) {
        await output.delete();
      }
      if (!await source.exists() && await backup.exists()) {
        await backup.rename(sourcePath);
      } else if (await backup.exists()) {
        await backup.delete();
      }
      if (error is MediaTrimException) {
        rethrow;
      }
      throw MediaTrimException('Trim failed: $error');
    }
  }

  Future<void> _runTrimCommand({
    required String sourcePath,
    required String outputPath,
    required Duration start,
    required Duration duration,
  }) async {
    try {
      await _channel.invokeMethod<void>('trimInPlace', {
        'sourcePath': sourcePath,
        'outputPath': outputPath,
        'startMs': start.inMilliseconds,
        'endMs': (start + duration).inMilliseconds,
      });
    } on MissingPluginException {
      throw const MediaTrimException(
        'Native trimming is currently available on Android only.',
      );
    } on PlatformException catch (error) {
      throw MediaTrimException(error.message ?? 'Trim failed.');
    }
  }
}

class MediaTrimException implements Exception {
  const MediaTrimException(this.message);

  final String message;

  @override
  String toString() => message;
}
