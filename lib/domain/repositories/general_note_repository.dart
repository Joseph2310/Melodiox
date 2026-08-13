import '../entities/general_note.dart';

abstract class GeneralNoteRepository {
  Future<List<GeneralNote>> getNotes();
  Future<int> saveNote(GeneralNote note);
  Future<void> deleteNote(int id);
}
