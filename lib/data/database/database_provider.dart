import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

class DatabaseProvider {
  Database? _database;

  Future<String> get databasePath async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return path.join(documentsDirectory.path, DatabaseSchema.databaseName);
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await openDatabase(
      await databasePath,
      version: DatabaseSchema.version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await DatabaseSchema.create(db);
        await DatabaseSchema.seed(db);
      },
      onUpgrade: DatabaseSchema.migrate,
      onDowngrade: (db, oldVersion, newVersion) => DatabaseSchema.reset(db),
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
