import '../../domain/entities/tag.dart';
import '../../domain/repositories/tag_repository.dart';
import '../database/database_provider.dart';
import '../models/tag_model.dart';

class SqliteTagRepository implements TagRepository {
  SqliteTagRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<Tag>> getTags() async {
    final db = await _databaseProvider.database;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE');
    return rows.map(TagModel.fromMap).toList();
  }

  @override
  Future<int> saveTag(Tag tag) async {
    final db = await _databaseProvider.database;
    final row = TagModel.toMap(tag)..remove('id');
    if (tag.id == null) {
      return db.insert('tags', row);
    }
    await db.update('tags', row, where: 'id = ?', whereArgs: [tag.id]);
    return tag.id!;
  }

  @override
  Future<void> deleteTag(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }
}
