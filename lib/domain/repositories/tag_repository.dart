import '../entities/tag.dart';

abstract class TagRepository {
  Future<List<Tag>> getTags();
  Future<int> saveTag(Tag tag);
  Future<void> deleteTag(int id);
}
