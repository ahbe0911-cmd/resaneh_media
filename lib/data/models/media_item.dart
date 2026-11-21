import '../../core/utils/file_classifier.dart';

class MediaItem {
  final String id;
  final String title;
  final String originalName;
  final String storedName;
  final String relativePath;
  final String? thumbnailPath;
  final String mimeType;
  final MediaFileType fileType;
  final int fileSize;
  final String description;
  final String searchText;
  final String searchCompact;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  const MediaItem({
    required this.id,
    required this.title,
    required this.originalName,
    required this.storedName,
    required this.relativePath,
    this.thumbnailPath,
    required this.mimeType,
    required this.fileType,
    required this.fileSize,
    required this.description,
    required this.searchText,
    required this.searchCompact,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  factory MediaItem.fromMap(
    Map<String, Object?> map, {
    List<String> tags = const [],
  }) => MediaItem(
        id: map['id'] as String,
        title: map['title'] as String,
        originalName: map['original_name'] as String,
        storedName: map['stored_name'] as String,
        relativePath: map['relative_path'] as String,
        thumbnailPath: map['thumbnail_path'] as String?,
        mimeType: map['mime_type'] as String,
        fileType: MediaFileType.fromValue(map['file_type'] as String),
        fileSize: (map['file_size'] as num).toInt(),
        description: map['description'] as String,
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
        tags: List.unmodifiable(tags),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'original_name': originalName,
        'stored_name': storedName,
        'relative_path': relativePath,
        'thumbnail_path': thumbnailPath,
        'mime_type': mimeType,
        'file_type': fileType.name,
        'file_size': fileSize,
        'description': description,
        'search_text': searchText,
        'search_compact': searchCompact,
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      };

  MediaItem copyWith({
    String? title,
    String? description,
    String? thumbnailPath,
    bool? isPinned,
    DateTime? updatedAt,
    List<String>? tags,
  }) => MediaItem(
        id: id,
        title: title ?? this.title,
        originalName: originalName,
        storedName: storedName,
        relativePath: relativePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        mimeType: mimeType,
        fileType: fileType,
        fileSize: fileSize,
        description: description ?? this.description,
        searchText: searchText,
        searchCompact: searchCompact,
        isPinned: isPinned ?? this.isPinned,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        tags: tags ?? this.tags,
      );
}
