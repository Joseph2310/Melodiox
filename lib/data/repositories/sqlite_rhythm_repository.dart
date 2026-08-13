import 'package:sqflite/sqflite.dart';

import '../../domain/entities/rhythm.dart';
import '../../domain/repositories/rhythm_repository.dart';
import '../database/database_provider.dart';
import '../models/rhythm_model.dart';

class SqliteRhythmRepository implements RhythmRepository {
  SqliteRhythmRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<Rhythm>> getRhythms() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'rhythms',
      orderBy: 'section COLLATE NOCASE, rhythmName COLLATE NOCASE',
    );
    return rows.map(RhythmModel.fromMap).toList();
  }

  @override
  Future<int> saveRhythm(Rhythm rhythm) async {
    final db = await _databaseProvider.database;
    final row = RhythmModel.toMap(rhythm)..remove('id');
    if (rhythm.id == null) {
      return db.insert(
        'rhythms',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    await db.update(
      'rhythms',
      row,
      where: 'id = ?',
      whereArgs: [rhythm.id],
    );
    return rhythm.id!;
  }

  @override
  Future<void> deleteRhythm(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('rhythms', where: 'id = ?', whereArgs: [id]);
  }
}
