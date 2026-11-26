import 'package:flutter/material.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/media_item.dart';

class MediaDetailsSheet extends StatelessWidget {
  const MediaDetailsSheet({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مشخصات فایل', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Text(item.title, style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            )),
            const SizedBox(height: 12),
            _row(context, 'نام اصلی', item.originalName),
            _row(context, 'نوع', Formatters.typeLabel(item.fileType)),
            _row(context, 'حجم', Formatters.fileSize(item.fileSize)),
            _row(context, 'تاریخ ثبت', JalaliFormatter.formatDateTime(item.createdAt)),
            if (item.description.isNotEmpty) _row(context, 'توضیحات', item.description),
            if (item.tags.isNotEmpty) _row(context, 'برچسب‌ها', item.tags.join('، ')),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 94, child: Text(key)),
        Expanded(child: Text(value,
          style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}
