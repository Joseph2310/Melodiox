import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database/database_provider.dart';
import '../data/database/database_schema.dart';

enum BackupStorageTarget { local, drive }

class BackupService {
  BackupService(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  static const _mediaRootName = 'melodiox_media';
  static const _databaseArchivePath = 'database/${DatabaseSchema.databaseName}';

  Future<String?> exportDatabase({
    BackupStorageTarget target = BackupStorageTarget.local,
  }) async {
    await _prepareDatabaseForBackup();
    final source = File(await _databaseProvider.databasePath);
    if (!await source.exists()) {
      return null;
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return FilePicker.saveFile(
      dialogTitle: _saveDialogTitle('Database backup', target),
      fileName: 'melodiox_backup_$timestamp.db',
      type: FileType.custom,
      allowedExtensions: const ['db'],
      bytes: await source.readAsBytes(),
    );
  }

  Future<String?> restoreDatabase({
    BackupStorageTarget source = BackupStorageTarget.local,
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: _pickDialogTitle('database backup', source),
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite', 'sqlite3'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) {
      return null;
    }

    await _databaseProvider.close();
    final destination = File(await _databaseProvider.databasePath);
    await File(selectedPath).copy(destination.path);
    await _repairMediaPaths();
    return destination.path;
  }

  Future<String?> exportFullBackup({
    BackupStorageTarget target = BackupStorageTarget.local,
  }) async {
    await _prepareDatabaseForBackup();
    final databaseFile = File(await _databaseProvider.databasePath);
    if (!await databaseFile.exists()) {
      return null;
    }

    final archive = Archive();
    archive.addFile(
      ArchiveFile.bytes(
        _databaseArchivePath,
        await databaseFile.readAsBytes(),
      ),
    );

    final mediaRoot = await mediaRootDirectory();
    if (await mediaRoot.exists()) {
      await for (final entity in mediaRoot.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = path.relative(entity.path, from: mediaRoot.path);
        final archivePath = path.posix.joinAll([
          _mediaRootName,
          ...path.split(relativePath),
        ]);
        archive.addFile(
          ArchiveFile.bytes(archivePath, await entity.readAsBytes()),
        );
      }
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final bytes = ZipEncoder().encodeBytes(archive);
    return FilePicker.saveFile(
      dialogTitle: _saveDialogTitle('Full backup', target),
      fileName: 'melodiox_full_backup_$timestamp.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
  }

  Future<String?> restoreFullBackup({
    BackupStorageTarget source = BackupStorageTarget.local,
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: _pickDialogTitle('full backup', source),
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) {
      return null;
    }

    final backupFile = File(selectedPath);
    final archive = ZipDecoder().decodeBytes(await backupFile.readAsBytes());
    final databaseEntry = _databaseEntry(archive);
    if (databaseEntry == null) {
      throw const FormatException('Full backup does not contain a database.');
    }

    await _databaseProvider.close();

    final databaseDestination = File(await _databaseProvider.databasePath);
    await databaseDestination.parent.create(recursive: true);
    await databaseDestination.writeAsBytes(databaseEntry.content);

    final mediaRoot = await mediaRootDirectory();
    if (await mediaRoot.exists()) {
      await mediaRoot.delete(recursive: true);
    }
    await mediaRoot.create(recursive: true);

    for (final entry in archive.files) {
      if (!entry.isFile) {
        continue;
      }
      final archivePath = _safeArchivePath(entry.name);
      if (archivePath == null || !archivePath.startsWith('$_mediaRootName/')) {
        continue;
      }
      final relativePath = archivePath.substring(_mediaRootName.length + 1);
      if (relativePath.trim().isEmpty) {
        continue;
      }
      final destination = File(
        path.joinAll([mediaRoot.path, ...relativePath.split('/')]),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(entry.content);
    }

    await _repairMediaPaths();
    return databaseDestination.path;
  }

  Future<String> defaultExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Directory> mediaRootDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory(path.join(directory.path, _mediaRootName));
  }

  Future<void> _prepareDatabaseForBackup() async {
    final db = await _databaseProvider.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  ArchiveFile? _databaseEntry(Archive archive) {
    for (final entry in archive.files) {
      final archivePath = _safeArchivePath(entry.name);
      if (entry.isFile && archivePath == _databaseArchivePath) {
        return entry;
      }
    }
    for (final entry in archive.files) {
      final archivePath = _safeArchivePath(entry.name);
      if (entry.isFile &&
          archivePath != null &&
          ['.db', '.sqlite', '.sqlite3']
              .contains(path.extension(archivePath))) {
        return entry;
      }
    }
    return null;
  }

  String? _safeArchivePath(String value) {
    final normalized = path.posix.normalize(value.replaceAll('\\', '/'));
    if (normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.contains('/../') ||
        path.posix.isAbsolute(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<void> _repairMediaPaths() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final db = await _databaseProvider.database;
    await _repairTableMediaPaths(
      db,
      table: 'media',
      pathColumn: 'localPath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'song_chord_item_images',
      pathColumn: 'localPath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'note_images',
      pathColumn: 'localPath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'musical_scales',
      pathColumn: 'imagePath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'musical_scales',
      pathColumn: 'videoPath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'chord_tutorials',
      pathColumn: 'imagePath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'chord_tutorials',
      pathColumn: 'videoPath',
      documentsPath: documentsDirectory.path,
    );
    await _repairJsonMediaPaths(
      db,
      table: 'chord_tutorials',
      jsonColumn: 'inversions',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'circle_tutorials',
      pathColumn: 'imagePath',
      documentsPath: documentsDirectory.path,
    );
    await _repairTableMediaPaths(
      db,
      table: 'circle_tutorials',
      pathColumn: 'videoPath',
      documentsPath: documentsDirectory.path,
    );
  }

  Future<void> _repairTableMediaPaths(
    DatabaseExecutor db, {
    required String table,
    required String pathColumn,
    required String documentsPath,
  }) async {
    if (!await _tableHasColumn(db, table, pathColumn)) {
      return;
    }
    final rows = await db.query(
      table,
      columns: ['id', pathColumn],
      where: '$pathColumn IS NOT NULL',
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      final localPath = row[pathColumn] as String?;
      if (id == null || localPath == null) {
        continue;
      }
      final repairedPath = _repairedMediaPath(localPath, documentsPath);
      if (repairedPath == null) {
        continue;
      }
      if (repairedPath == localPath) {
        continue;
      }
      await db.update(
        table,
        {pathColumn: repairedPath},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _repairJsonMediaPaths(
    DatabaseExecutor db, {
    required String table,
    required String jsonColumn,
    required String documentsPath,
  }) async {
    if (!await _tableHasColumn(db, table, jsonColumn)) {
      return;
    }
    final rows = await db.query(
      table,
      columns: ['id', jsonColumn],
      where: '$jsonColumn IS NOT NULL',
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      final payload = row[jsonColumn] as String?;
      if (id == null || payload == null || payload.trim().isEmpty) {
        continue;
      }

      Object? decoded;
      try {
        decoded = jsonDecode(payload);
      } catch (_) {
        continue;
      }
      if (decoded is! List) {
        continue;
      }

      var changed = false;
      final repaired = <Object?>[];
      for (final item in decoded) {
        if (item is! Map) {
          repaired.add(item);
          continue;
        }

        final next = Map<String, Object?>.from(item);
        for (final key in const ['imagePath', 'videoPath']) {
          final value = next[key];
          if (value is! String) {
            continue;
          }
          final repairedPath = _repairedMediaPath(value, documentsPath);
          if (repairedPath == null || repairedPath == value) {
            continue;
          }
          next[key] = repairedPath;
          changed = true;
        }
        repaired.add(next);
      }

      if (!changed) {
        continue;
      }
      await db.update(
        table,
        {jsonColumn: jsonEncode(repaired)},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  String? _repairedMediaPath(String localPath, String documentsPath) {
    final normalized = localPath.replaceAll('\\', '/');
    final markerIndex = normalized.indexOf(_mediaRootName);
    if (markerIndex < 0) {
      return null;
    }
    final relativePath = normalized.substring(markerIndex);
    return path.joinAll([documentsPath, ...relativePath.split('/')]);
  }

  Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tables.isEmpty) {
      return false;
    }
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((item) => item['name'] == column);
  }

  String _saveDialogTitle(String action, BackupStorageTarget target) {
    return switch (target) {
      BackupStorageTarget.local => action,
      BackupStorageTarget.drive => '$action - choose Google Drive',
    };
  }

  String _pickDialogTitle(String action, BackupStorageTarget source) {
    return switch (source) {
      BackupStorageTarget.local => 'Select $action',
      BackupStorageTarget.drive => 'Select $action from Google Drive',
    };
  }
}
