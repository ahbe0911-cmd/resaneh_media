import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';

class MediaItemCard extends StatelessWidget {
  const MediaItemCard({
    super.key, required this.item, required this.thumbnailFile,
    required this.onTap, required this.onPin, required this.onShare,
    required this.onEdit, required this.onDelete, required this.onDetails,
  });

  final MediaItem item;
  final File? thumbnailFile;
  final VoidCallback onTap, onPin, onShare, onEdit, onDelete, onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (accent, symbol, typeName) = switch (item.fileType) {
      MediaFileType.image => (
        const Color(0xFF0C9974), Icons.image_outlined, 'عکس'),
      MediaFileType.video => (
        const Color(0xFF7F5AC7), Icons.smart_display_outlined, 'ویدیو'),
      MediaFileType.pdf => (
        const Color(0xFFD85855), Icons.picture_as_pdf_outlined, 'PDF'),
      MediaFileType.other => (
        const Color(0xFF51788B), Icons.description_outlined, 'سند'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .60)),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: .045),
            blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 7),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96, height: 104,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(fit: StackFit.expand, children: [
                          ColoredBox(
                            color: accent.withValues(alpha: .10),
                            child: thumbnailFile == null
                              ? Icon(symbol, color: accent, size: 36)
                              : Image.file(thumbnailFile!, fit: BoxFit.cover,
                                  cacheWidth: 360,
                                  errorBuilder: (_, _, _) =>
                                    Icon(symbol, color: accent, size: 36)),
                          ),
                          if (item.fileType == MediaFileType.video)
                            Center(
                              child: CircleAvatar(
                                radius: 19, backgroundColor: Colors.black54,
                                child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 24)),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800, height: 1.5)),
                        const SizedBox(height: 7),
                        Row(children: [
                          Icon(Icons.event_available_outlined, size: 14,
                            color: scheme.primary),
                          const SizedBox(width: 5),
                          Expanded(child: Text(
                            'ثبت: ' +
                              JalaliFormatter.formatShortDate(item.createdAt)
                              + ' · ' +
                              JalaliFormatter.formatTime(item.createdAt),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 5),
                        Text(item.originalName, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Wrap(spacing: 5, runSpacing: 3,
                            children: item.tags.take(2).map((tag) => Container(
                              constraints: const BoxConstraints(maxWidth: 126),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                  .withValues(alpha: .56),
                                borderRadius: BorderRadius.circular(7)),
                              child: Text(tag, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600)),
                            )).toList()),
                        ],
                      ],
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(symbol, size: 13, color: accent),
                      const SizedBox(width: 4),
                      Text(typeName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    JalaliFormatter.toPersianDigits(_size(item.fileSize)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant))),
                  const Spacer(),
                  IconButton(
                    tooltip: 'اشتراک‌گذاری',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36, height: 36),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 19)),
                  IconButton(
                    tooltip: item.isPinned ? 'برداشتن سنجاق' : 'سنجاق',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36, height: 36),
                    onPressed: onPin,
                    icon: Icon(item.isPinned
                        ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: item.isPinned
                          ? scheme.primary : scheme.onSurfaceVariant,
                      size: 19)),
                  PopupMenuButton<String>(
                    tooltip: 'عملیات فایل',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert_rounded, size: 20,
                      color: scheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'details') onDetails();
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'details',
                        child: Text('مشخصات فایل')),
                      PopupMenuItem(value: 'edit',
                        child: Text('ویرایش اطلاعات')),
                      PopupMenuItem(value: 'delete',
                        child: Text('حذف فایل')),
                    ]),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return bytes.toString() + ' B';
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toStringAsFixed(1) + ' KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    }
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
  }
}
