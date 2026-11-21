class MediaTag {
  final String id;
  final String name;
  final String normalizedName;
  final String compactName;
  final DateTime createdAt;

  const MediaTag({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.compactName,
    required this.createdAt,
  });

  factory MediaTag.fromMap(Map<String, Object?> map) => MediaTag(
        id: map['id'] as String,
        name: map['name'] as String,
        normalizedName: map['normalized_name'] as String,
        compactName: map['compact_name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num).toInt(),
          isUtc: true,
        ),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'normalized_name': normalizedName,
        'compact_name': compactName,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      };
}
