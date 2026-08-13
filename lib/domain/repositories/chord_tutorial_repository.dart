import '../entities/chord_tutorial.dart';

abstract class ChordTutorialRepository {
  Future<List<ChordTutorial>> getChordTutorials();
  Future<int> saveChordTutorial(ChordTutorial tutorial);
  Future<void> deleteChordTutorial(int id);
}
