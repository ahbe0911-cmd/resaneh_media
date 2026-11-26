import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/resaneh_brand_theme.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/media_item.dart';

class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.item, required this.file});
  final MediaItem item;
  final File? file;

  @override
  Widget build(BuildContext context) {
    final color = ResanehBrandTheme.of(context).mediaColor(item.fileType);
    final icon = Formatters.typeIcon(item.fileType);
    return Hero(
      tag: 'media_${item.id}',
      child: Material(
        color: color.withValues(alpha: .10),
        child: Stack(fit: StackFit.expand, children: [
          if (file == null)
            Center(child: Icon(icon, color: color, size: 36))
          else
            Image.file(file!, fit: BoxFit.cover, cacheWidth: 360,
              errorBuilder: (_, _, _) =>
                Center(child: Icon(icon, color: color, size: 36))),
          if (item.fileType == MediaFileType.video)
            const Center(child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white),
            )),
        ]),
      ),
    );
  }
}
