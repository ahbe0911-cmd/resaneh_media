import 'package:flutter/material.dart';
import '../../../core/utils/jalali_formatter.dart';
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
            _row('نام اصلی', item.originalName),
            _row('نوع', item.fileType.name),
            _row('حجم', '${item.fileSize} بایت'),
            _row('تاریخ ثبت', JalaliFormatter.formatDateTime(item.createdAt)),
            if (item.description.isNotEmpty) _row('توضیحات', item.description),
            if (item.tags.isNotEmpty) _row('برچسب‌ها', item.tags.join('، ')),
          ],
        ),
      ),
    );
  }

  Widget _row(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 94, child: Text(key)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
