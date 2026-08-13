import '../../domain/entities/chord_tutorial.dart';
import '../../domain/repositories/chord_tutorial_repository.dart';
import '../database/database_provider.dart';
import '../models/chord_tutorial_model.dart';

class SqliteChordTutorialRepository implements ChordTutorialRepository {
  SqliteChordTutorialRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<ChordTutorial>> getChordTutorials() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'chord_tutorials',
      orderBy: 'name COLLATE NOCASE, type COLLATE NOCASE',
    );
    return rows.map(ChordTutorialModel.fromMap).toList();
  }

  @override
  Future<int> saveChordTutorial(ChordTutorial tutorial) async {
    final db = await _databaseProvider.database;
    final row = ChordTutorialModel.toMap(tutorial)..remove('id');
    if (tutorial.id == null) {
      return db.insert('chord_tutorials', row);
    }
    await db.update(
      'chord_tutorials',
      row,
      where: 'id = ?',
      whereArgs: [tutorial.id],
    );
    return tutorial.id!;
  }

  @override
  Future<void> deleteChordTutorial(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('chord_tutorials', where: 'id = ?', whereArgs: [id]);
  }
}
