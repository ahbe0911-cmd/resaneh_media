import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';

class MediaGridCard extends StatelessWidget {
  const MediaGridCard({
    super.key,
    required this.item,
    required this.thumbnail,
    required this.onOpen,
    required this.onShare,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
  });
  final MediaItem item;
  final File? thumbnail;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  IconData get icon => switch (item.fileType) {
    MediaFileType.image => Icons.image_rounded,
    MediaFileType.video => Icons.movie_rounded,
    MediaFileType.pdf => Icons.picture_as_pdf_rounded,
    MediaFileType.other => Icons.description_rounded,
  };

  Color get iconColor => switch (item.fileType) {
    MediaFileType.image => const Color(0xFF16A34A),
    MediaFileType.video => const Color(0xFF7C3AED),
    MediaFileType.pdf => const Color(0xFFDC2626),
    MediaFileType.other => const Color(0xFF0891B2),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: iconColor.withValues(alpha: 0.10),
                child: thumbnail == null
                    ? Center(child: Icon(icon, color: iconColor, size: 44))
                    : Image.file(thumbnail!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(child:
                          Icon(icon, size: 44, color: iconColor))),
              ),
              if (item.isPinned) Positioned(
                top: 8, right: 8,
                child: CircleAvatar(radius: 15,
                  backgroundColor: scheme.surface.withValues(alpha: .9),
                  child: Icon(Icons.push_pin_rounded, size: 16,
                    color: scheme.primary)),
              ),
              if (item.fileType == MediaFileType.video)
                const Center(child: Icon(Icons.play_circle_fill_rounded,
                  size: 48, color: Colors.white)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 3, 10, 2),
          child: Text('ثبت: ' + JalaliFormatter.formatShortDate(item.createdAt) + ' · ' + JalaliFormatter.formatTime(item.createdAt),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(tooltip: 'اشتراک‌گذاری', onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 20)),
          IconButton(tooltip: 'سنجاق', onPressed: onPin,
            icon: Icon(item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: item.isPinned ? scheme.primary : scheme.onSurfaceVariant, size: 20)),
          PopupMenuButton<String>(
            tooltip: 'مدیریت',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ]),
      ]),
    );
  }
}
