import '../entities/musical_scale.dart';

abstract class MusicalScaleRepository {
  Future<List<MusicalScale>> getScales();
  Future<int> saveScale(MusicalScale scale);
  Future<void> deleteScale(int id);
}
