import 'package:sqflite/sqflite.dart';

import '../../domain/entities/chord_tutorial.dart';
import '../../domain/entities/musical_scale.dart';
import '../../domain/repositories/musical_scale_repository.dart';
import '../database/database_provider.dart';
import '../models/chord_tutorial_model.dart';
import '../models/musical_scale_model.dart';

class SqliteMusicalScaleRepository implements MusicalScaleRepository {
  SqliteMusicalScaleRepository(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  @override
  Future<List<MusicalScale>> getScales() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'musical_scales',
      orderBy: 'id ASC',
    );
    final scales = <MusicalScale>[];
    for (final row in rows) {
      final scaleId = row['id'] as int;
      scales.add(
        MusicalScaleModel.fromMap(
          row,
          chordTutorials: await _loadChordTutorials(db, scaleId),
        ),
      );
    }
    return scales;
  }

  @override
  Future<int> saveScale(MusicalScale scale) async {
    final db = await _databaseProvider.database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final effectiveScale = scale.copyWith(
        createdAt: scale.id == null ? now : scale.createdAt,
        updatedAt: now,
      );
      final row = MusicalScaleModel.toMap(effectiveScale)..remove('id');
      final scaleId = scale.id == null
          ? await txn.insert('musical_scales', row)
          : scale.id!;
      if (scale.id != null) {
        await txn.update(
          'musical_scales',
          row,
          where: 'id = ?',
          whereArgs: [scale.id],
        );
      }
      await _replaceChordTutorials(txn, scaleId, effectiveScale.chordTutorials);
      return scaleId;
    });
  }

  @override
  Future<void> deleteScale(int id) async {
    final db = await _databaseProvider.database;
    await db.delete('musical_scales', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ChordTutorial>> _loadChordTutorials(
    DatabaseExecutor db,
    int scaleId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT chord_tutorials.id,
             chord_tutorials.name,
             chord_tutorials.type,
             chord_tutorials.keys,
             chord_tutorials.imagePath,
             chord_tutorials.videoPath,
             chord_tutorials.relativeChordId,
             chord_tutorials.inversions,
             chord_tutorials.notes,
             chord_tutorials.links,
             chord_tutorials.customFields,
             chord_tutorials.createdAt,
             chord_tutorials.updatedAt
      FROM scale_chord_tutorials
      INNER JOIN chord_tutorials
        ON chord_tutorials.id = scale_chord_tutorials.chordTutorialId
      WHERE scale_chord_tutorials.scaleId = ?
      ORDER BY scale_chord_tutorials.position ASC,
               chord_tutorials.name COLLATE NOCASE,
               chord_tutorials.type COLLATE NOCASE
      ''',
      [scaleId],
    );
    return rows.map(ChordTutorialModel.fromMap).toList();
  }

  Future<void> _replaceChordTutorials(
    Transaction txn,
    int scaleId,
    List<ChordTutorial> chords,
  ) async {
    await txn.delete(
      'scale_chord_tutorials',
      where: 'scaleId = ?',
      whereArgs: [scaleId],
    );
    for (var index = 0; index < chords.length; index++) {
      final chordId = chords[index].id;
      if (chordId == null) {
        continue;
      }
      await txn.insert(
        'scale_chord_tutorials',
        {
          'scaleId': scaleId,
          'chordTutorialId': chordId,
          'position': index,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
