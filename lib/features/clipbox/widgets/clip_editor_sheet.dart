import 'package:flutter/material.dart';

import '../../../data/models/clip_entry.dart';

class ClipDraft {
  const ClipDraft({required this.title, required this.body});
  final String title;
  final String body;
}

class ClipEditorSheet extends StatefulWidget {
  const ClipEditorSheet({super.key, this.initial, this.initialBody});
  final ClipEntry? initial;
  final String? initialBody;

  @override
  State<ClipEditorSheet> createState() => _ClipEditorSheetState();
}

class _ClipEditorSheetState extends State<ClipEditorSheet> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _body = TextEditingController(text: widget.initial?.body ?? widget.initialBody ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    if (_key.currentState?.validate() != true) return;
    Navigator.pop(context, ClipDraft(title: _title.text.trim(), body: _body.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Form(
            key: _key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.initial == null ? 'متن جدید' : 'ویرایش متن',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                autofocus: widget.initial == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'عنوان قابل جستجو',
                    prefixIcon: Icon(Icons.title_rounded)),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'عنوان الزامی است.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _body,
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                    labelText: 'متن آماده', alignLabelWithHint: true),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'متن نمی‌تواند خالی باشد.' : null,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('ذخیره در کلیپ‌باکس'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
