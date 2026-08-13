import '../entities/rhythm.dart';

abstract class RhythmRepository {
  Future<List<Rhythm>> getRhythms();
  Future<int> saveRhythm(Rhythm rhythm);
  Future<void> deleteRhythm(int id);
}
