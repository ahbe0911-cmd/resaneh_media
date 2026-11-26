import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/resaneh_brand_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';
import 'media_thumbnail.dart';

class MediaItemCard extends StatelessWidget {
  const MediaItemCard({
    super.key, required this.item, required this.thumbnailFile,
    required this.onTap, required this.onPin, required this.onShare,
    required this.onEdit, required this.onDelete, required this.onDetails,
    this.onLongPress, this.selectionMode = false, this.selected = false,
  });

  final MediaItem item;
  final File? thumbnailFile;
  final VoidCallback onTap, onPin, onShare, onEdit, onDelete, onDetails;
  final VoidCallback? onLongPress;
  final bool selectionMode, selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = ResanehBrandTheme.of(context);
    final accent = brand.mediaColor(item.fileType);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: selected ? scheme.primaryContainer : brand.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(brand.cardRadius),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 9, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 86, height: 100, child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MediaThumbnail(item: item, file: thumbnailFile),
            )),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (item.isPinned) ...[
                    Icon(Icons.push_pin_rounded, color: scheme.primary, size: 15),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(item.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, height: 1.5))),
                ]),
                const SizedBox(height: 5),
                Text(item.originalName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 5),
                Text('${JalaliFormatter.formatShortDate(item.createdAt)} · '
                    '${JalaliFormatter.formatTime(item.createdAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(spacing: 7, runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(7)),
                      child: Text(Formatters.typeLabel(item.fileType),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent, fontWeight: FontWeight.w700))),
                    Text(Formatters.fileSize(item.fileSize),
                      style: theme.textTheme.labelSmall),
                    for (final tag in item.tags.take(2))
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 100),
                        child: Text('#$tag', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary))),
                  ]),
                if (!selectionMode) Row(mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(tooltip: 'اشتراک‌گذاری', onPressed: onShare,
                      icon: const Icon(Icons.ios_share_rounded, size: 19)),
                    IconButton(tooltip: item.isPinned ? 'برداشتن سنجاق' : 'سنجاق',
                      onPressed: onPin, icon: Icon(item.isPinned ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined, size: 19)),
                    PopupMenuButton<String>(tooltip: 'عملیات فایل',
                      onSelected: (value) {
                        if (value == 'details') onDetails();
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'details', child: Text('مشخصات فایل')),
                        PopupMenuItem(value: 'edit', child: Text('ویرایش اطلاعات')),
                        PopupMenuItem(value: 'delete', child: Text('حذف فایل')),
                      ]),
                  ]),
              ],
            )),
            if (selectionMode) Padding(padding: const EdgeInsets.only(top: 4),
              child: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? scheme.primary : scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
