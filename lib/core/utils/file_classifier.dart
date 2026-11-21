enum MediaFileType {
  image,
  video,
  pdf,
  other;

  static MediaFileType fromValue(String value) => MediaFileType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => MediaFileType.other,
      );
}

class FileClassifier {
  FileClassifier._();
  static const imageExtensions = <String>{
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif', '.tiff',
  };
  static const videoExtensions = <String>{
    '.mp4', '.mkv', '.mov', '.avi', '.webm', '.3gp', '.m4v',
  };

  static MediaFileType classify({
    required String mimeType,
    required String extension,
  }) {
    final mime = mimeType.toLowerCase();
    final ext = extension.toLowerCase();
    if (mime.startsWith('image/') || imageExtensions.contains(ext)) {
      return MediaFileType.image;
    }
    if (mime.startsWith('video/') || videoExtensions.contains(ext)) {
      return MediaFileType.video;
    }
    if (mime == 'application/pdf' || ext == '.pdf') return MediaFileType.pdf;
    return MediaFileType.other;
  }
}
