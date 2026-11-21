import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';

class MediaItemCard extends StatelessWidget {
  final MediaItem item;
  final File? thumbnailFile;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  const MediaItemCard({super.key, required this.item, required this.thumbnailFile,
    required this.onTap, required this.onPin, required this.onShare,
    required this.onEdit, required this.onDelete, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon, type) = switch (item.fileType) {
      MediaFileType.image => (const Color(0xFF16A34A), Icons.image_rounded, 'عکس'),
      MediaFileType.video => (const Color(0xFF7C3AED), Icons.play_circle_rounded, 'ویدیو'),
      MediaFileType.pdf => (const Color(0xFFDC2626), Icons.picture_as_pdf_rounded, 'PDF'),
      MediaFileType.other => (const Color(0xFF64748B), Icons.insert_drive_file_rounded, 'سایر'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 84, height: 90,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13)),
              clipBehavior: Clip.antiAlias,
              child: thumbnailFile == null
                  ? Icon(icon, color: color, size: 34)
                  : Image.file(thumbnailFile!, fit: BoxFit.cover,
                      cacheWidth: 320,
                      errorBuilder: (_, error, stack) => Icon(icon,
                          color: color, size: 34)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(item.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'اشتراک‌گذاری', onPressed: onShare,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.share_outlined, size: 19)),
                  IconButton(tooltip: item.isPinned ? 'برداشتن سنجاق' : 'سنجاق',
                    onPressed: onPin, visualDensity: VisualDensity.compact,
                    icon: Icon(item.isPinned ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined, size: 19,
                      color: item.isPinned ? theme.colorScheme.primary : null)),
                  PopupMenuButton<String>(
                    tooltip: 'عملیات فایل',
                    onSelected: (v) { if (v == 'details') onDetails(); if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'details', child: Text('مشخصات فایل')),
                      PopupMenuItem(value: 'edit', child: Text('ویرایش اطلاعات')),
                      PopupMenuItem(value: 'delete', child: Text('حذف فایل')),
                    ],
                    child: const Padding(padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert_rounded, size: 19)),
                  ),
                ]),
                Text(item.originalName, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 5, runSpacing: 4,
                    children: item.tags.take(3).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(7)),
                      child: Text(tag, style: theme.textTheme.labelSmall),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 4, children: [
                  _Fact(icon: icon, value: type, color: color),
                  _Fact(icon: Icons.storage_rounded, value: _size(item.fileSize)),
                  _Fact(icon: Icons.calendar_month_rounded,
                    value: JalaliFormatter.formatShortDate(item.createdAt)),
                ]),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;
  const _Fact({required this.icon, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 3),
      Text(JalaliFormatter.toPersianDigits(value),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    ],
  );
}
