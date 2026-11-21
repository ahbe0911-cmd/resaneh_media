class ClipEntry {
  final String id;
  final String title;
  final String body;
  final String searchText;
  final String searchCompact;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClipEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.searchText,
    required this.searchCompact,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClipEntry.fromMap(Map<String, Object?> map) => ClipEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        searchText: map['search_text'] as String,
        searchCompact: map['search_compact'] as String,
        isPinned: (map['is_pinned'] as num).toInt() == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num).toInt(),
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num).toInt(),
          isUtc: true,
        ),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'search_text': searchText,
        'search_compact': searchCompact,
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      };
}
