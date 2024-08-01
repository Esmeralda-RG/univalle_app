import 'package:univalle_app/features/search_subject/domain/entities/subject_result.dart';
import 'package:univalle_app/features/search_subject/domain/entities/subject_suggestion.dart';

abstract class SearchSubjectRepository {
  Future<List<SubjectResult>> searchSubjects(String query);
  Future<List<SubjectSuggestion>> getSuggestions(String query, int limit);
}