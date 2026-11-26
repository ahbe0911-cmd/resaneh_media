import 'package:flutter/material.dart';

import 'file_classifier.dart';
import 'jalali_formatter.dart';

class Formatters {
  Formatters._();

  static String fileSize(int bytes) {
    final size = bytes < 0 ? 0 : bytes;
    final String formatted;
    if (size < 1024) {
      formatted = '$size B';
    } else if (size < 1024 * 1024) {
      formatted = '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      formatted = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      formatted = '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return JalaliFormatter.toPersianDigits(formatted);
  }

  static String typeLabel(MediaFileType? type, {bool plural = false}) =>
      switch (type) {
        null => 'همه فایل‌ها',
        MediaFileType.image => plural ? 'تصاویر' : 'عکس',
        MediaFileType.video => plural ? 'ویدیوها' : 'ویدیو',
        MediaFileType.pdf => plural ? 'اسناد PDF' : 'PDF',
        MediaFileType.other => plural ? 'سایر فایل‌ها' : 'سند',
      };

  static IconData typeIcon(MediaFileType? type) => switch (type) {
        null => Icons.dashboard_customize_outlined,
        MediaFileType.image => Icons.image_outlined,
        MediaFileType.video => Icons.movie_outlined,
        MediaFileType.pdf => Icons.picture_as_pdf_outlined,
        MediaFileType.other => Icons.description_outlined,
      };
}
