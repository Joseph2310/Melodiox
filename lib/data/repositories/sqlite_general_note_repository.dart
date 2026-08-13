import 'package:sqflite/sqflite.dart';

import '../../domain/entities/general_note.dart';
import '../../domain/repositories/general_note_repository.dart';
import '../database/database_provider.dart';
import '../models/general_note_model.dart';

class SqliteGeneralNoteRepository implements GeneralNoteRepository {
  SqliteGeneralNoteRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<GeneralNote>> getNotes() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'general_notes',
      orderBy: 'pinned DESC, updatedAt DESC, title COLLATE NOCASE',
    );
    final notes = <GeneralNote>[];
    for (final row in rows) {
      final id = row['id'] as int;
      notes.add(
        GeneralNoteModel.fromMap(
          row,
          images: await _loadImages(db, id),
        ),
      );
    }
    return notes;
  }

  @override
  Future<int> saveNote(GeneralNote note) async {
    final db = await _databaseProvider.database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final effectiveNote = note.copyWith(
        createdAt: note.id == null ? now : note.createdAt,
        updatedAt: now,
      );
      final row = GeneralNoteModel.toMap(effectiveNote)..remove('id');
      final noteId =
          note.id == null ? await txn.insert('general_notes', row) : note.id!;
      if (note.id != null) {
        await txn.update(
          'general_notes',
          row,
          where: 'id = ?',
          whereArgs: [note.id],
        );
      }

      await txn.delete(
        'note_images',
        where: 'noteId = ?',
        whereArgs: [noteId],
      );
      for (var index = 0; index < effectiveNote.images.length; index++) {
        final image = effectiveNote.images[index];
        if (image.localPath.trim().isEmpty) {
          continue;
        }
        await txn.insert(
          'note_images',
          GeneralNoteModel.imageToMap(
            image.copyWith(sortOrder: index),
            noteId,
          )..remove('id'),
        );
      }
      return noteId;
    });
  }

  @override
  Future<void> deleteNote(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('general_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NoteImage>> _loadImages(DatabaseExecutor db, int noteId) async {
    final rows = await db.query(
      'note_images',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map(GeneralNoteModel.imageFromMap).toList();
  }
}
