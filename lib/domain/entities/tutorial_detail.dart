class TutorialNote {
  const TutorialNote({
    this.title = '',
    required this.body,
  });

  final String title;
  final String body;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;
  String get displayTitle => title.trim().isEmpty ? 'Note' : title.trim();
}

class TutorialLink {
  const TutorialLink({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  bool get isEmpty => label.trim().isEmpty && url.trim().isEmpty;
  String get displayLabel => label.trim().isEmpty ? url.trim() : label.trim();
}

class TutorialCustomField {
  const TutorialCustomField({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  bool get isEmpty => name.trim().isEmpty && value.trim().isEmpty;
}
