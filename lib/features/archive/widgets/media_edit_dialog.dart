import 'package:flutter/material.dart';

import '../../../core/utils/persian_normalizer.dart';
import '../../../data/models/media_item.dart';

class MediaEditData {
  final String title;
  final String description;
  final List<String> tags;
  const MediaEditData({required this.title, required this.description,
    required this.tags});
}

class MediaEditDialog extends StatefulWidget {
  final MediaItem item;
  const MediaEditDialog({super.key, required this.item});
  @override
  State<MediaEditDialog> createState() => _MediaEditDialogState();
}

class _MediaEditDialogState extends State<MediaEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _description = TextEditingController(text: widget.item.description);
    _tags = TextEditingController(text: widget.item.tags.join('، '));
  }

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _tags.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tagMap = <String, String>{};
    for (final raw in _tags.text.split(RegExp(r'[,،\n]+'))) {
      final tag = raw.trim().replaceFirst(RegExp(r'^#+'), '');
      final norm = PersianNormalizer.normalize(tag);
      if (norm.isNotEmpty) tagMap.putIfAbsent(norm, () => tag);
    }
    Navigator.of(context).pop(MediaEditData(
      title: _title.text.trim(),
      description: _description.text.trim(),
      tags: tagMap.values.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ویرایش اطلاعات فایل'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'عنوان اختصاصی *'),
            validator: (s) => s == null || s.trim().isEmpty
                ? 'عنوان الزامی است' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tags,
            decoration: const InputDecoration(labelText: 'برچسب‌ها',
                hintText: 'یارانه، ثبت‌نام'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'توضیحات'),
          ),
        ],
      )),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف')),
      FilledButton(onPressed: _submit, child: const Text('ذخیره تغییرات')),
    ],
  );
}
