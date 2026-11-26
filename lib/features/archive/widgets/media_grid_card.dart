import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/resaneh_brand_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';
import 'media_thumbnail.dart';

class MediaGridCard extends StatelessWidget {
  const MediaGridCard({
    super.key, required this.item, required this.thumbnail,
    required this.onOpen, required this.onShare, required this.onEdit,
    required this.onPin, required this.onDelete, this.onDetails,
    this.onLongPress, this.selectionMode = false, this.selected = false,
  });
  final MediaItem item;
  final File? thumbnail;
  final VoidCallback onOpen, onShare, onEdit, onPin, onDelete;
  final VoidCallback? onDetails, onLongPress;
  final bool selectionMode, selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = ResanehBrandTheme.of(context);
    final accent = brand.mediaColor(item.fileType);
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? scheme.primaryContainer : brand.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(brand.cardRadius),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            MediaThumbnail(item: item, file: thumbnail),
            PositionedDirectional(top: 8, end: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(color: scheme.surface,
                borderRadius: BorderRadius.circular(8)),
              child: Text(Formatters.typeLabel(item.fileType),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent, fontWeight: FontWeight.w700)))),
            if (selectionMode || item.isPinned)
              PositionedDirectional(top: 8, start: 8, child: CircleAvatar(
                radius: 15, backgroundColor: scheme.surface,
                child: Icon(selectionMode
                  ? (selected ? Icons.check_circle_rounded : Icons.circle_outlined)
                  : Icons.push_pin_rounded, size: 20, color: scheme.primary),
              )),
          ])),
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 2),
            child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(10, 2, 10, 2),
            child: Text(Formatters.fileSize(item.fileSize),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(10, 2, 10, 4),
            child: Text('${JalaliFormatter.formatShortDate(item.createdAt)} · '
                '${JalaliFormatter.formatTime(item.createdAt)}', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
          if (!selectionMode) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(tooltip: 'اشتراک‌گذاری', onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded, size: 19)),
              IconButton(tooltip: item.isPinned ? 'برداشتن سنجاق' : 'سنجاق',
                onPressed: onPin, icon: Icon(item.isPinned ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined, size: 19)),
              PopupMenuButton<String>(tooltip: 'عملیات فایل',
                onSelected: (value) {
                  if (value == 'details') onDetails?.call();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  if (onDetails != null) const PopupMenuItem(value: 'details',
                    child: Text('مشخصات فایل')),
                  const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ]),
            ]),
        ]),
      ),
    );
  }
}
