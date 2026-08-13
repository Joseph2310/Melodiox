class Tag {
  const Tag({this.id, required this.name, this.color});

  final int? id;
  final String name;
  final int? color;

  Tag copyWith({int? id, String? name, int? color, bool clearColor = false}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: clearColor ? null : color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Tag &&
        (id != null && other.id != null
            ? id == other.id
            : name.toLowerCase() == other.name.toLowerCase());
  }

  @override
  int get hashCode => id ?? name.toLowerCase().hashCode;
}
