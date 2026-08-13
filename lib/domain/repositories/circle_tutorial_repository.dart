import '../entities/circle_tutorial.dart';

abstract class CircleTutorialRepository {
  Future<List<CircleTutorial>> getCircleTutorials();
  Future<int> saveCircleTutorial(CircleTutorial tutorial);
  Future<void> deleteCircleTutorial(int id);
}
