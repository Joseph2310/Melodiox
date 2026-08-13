import '../../domain/entities/circle_tutorial.dart';
import '../../domain/repositories/circle_tutorial_repository.dart';
import '../database/database_provider.dart';
import '../models/circle_tutorial_model.dart';

class SqliteCircleTutorialRepository implements CircleTutorialRepository {
  SqliteCircleTutorialRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<CircleTutorial>> getCircleTutorials() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'circle_tutorials',
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map(CircleTutorialModel.fromMap).toList();
  }

  @override
  Future<int> saveCircleTutorial(CircleTutorial tutorial) async {
    final db = await _databaseProvider.database;
    final row = CircleTutorialModel.toMap(tutorial)..remove('id');
    if (tutorial.id == null) {
      return db.insert('circle_tutorials', row);
    }
    await db.update(
      'circle_tutorials',
      row,
      where: 'id = ?',
      whereArgs: [tutorial.id],
    );
    return tutorial.id!;
  }

  @override
  Future<void> deleteCircleTutorial(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('circle_tutorials', where: 'id = ?', whereArgs: [id]);
  }
}
