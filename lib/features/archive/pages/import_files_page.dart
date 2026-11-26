import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/persian_normalizer.dart';
import '../../../data/models/media_tag.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../providers/archive_provider.dart';
import '../../../services/import/incoming_file.dart';
import '../../../services/import/incoming_file_service.dart';
import '../../../services/vault/vault_service.dart';

class ImportFilesPage extends StatefulWidget {
  final List<IncomingFile> files;
  const ImportFilesPage({super.key, required this.files});

  @override
  State<ImportFilesPage> createState() => _ImportFilesPageState();
}

class _ImportEntry {
  final IncomingFile file;
  final TextEditingController title;
  bool saved = false;
  String? error;

  _ImportEntry(this.file)
      : title = TextEditingController(text: _initialTitle(file.originalName));

  static String _initialTitle(String name) {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return stem.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }
}

class _ImportFilesPageState extends State<ImportFilesPage> {
  final _formKey = GlobalKey<FormState>();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedTags = <String>{};
  late final List<_ImportEntry> _entries;
  late final Future<List<MediaTag>> _knownTags;
  late final IncomingFileService _incoming;
  late final VaultService _vault;
  late final ArchiveProvider _archive;
  bool _saving = false;
  int _processed = 0;
  int _saveTotal = 0;

  @override
  void initState() {
    super.initState();
    _entries = widget.files.map(_ImportEntry.new).toList();
    _incoming = context.read<IncomingFileService>();
    _vault = context.read<VaultService>();
    _archive = context.read<ArchiveProvider>();
    _knownTags = context.read<TagRepository>().getAll();
  }

  List<_ImportEntry> get _pending => _entries.where((e) => !e.saved).toList();

  List<String> _effectiveTags() {
    final unique = <String, String>{};
    for (final candidate in <String>[
      ..._selectedTags,
      ..._tagsController.text.split(RegExp(r'[,،\n]+')),
    ]) {
      final trimmed = candidate.trim().replaceFirst(RegExp(r'^#+'), '');
      final key = PersianNormalizer.normalize(trimmed);
      if (key.isNotEmpty) unique.putIfAbsent(key, () => trimmed);
    }
    return unique.values.toList();
  }

  Future<void> _save() async {
    if (_saving || _pending.isEmpty) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final pending = _pending;
    final tags = _effectiveTags();
    final description = _descriptionController.text.trim();
    setState(() { _saving = true; _processed = 0; _saveTotal = pending.length; });

    final titles = {for (final entry in pending) entry: entry.title.text.trim()};
    Future<void> saveEntry(_ImportEntry entry) async {
      try {
        entry.error = null;
        await _vault.importFile(
          sourceFile: entry.file.stagedFile,
          title: titles[entry]!,
          description: description,
          tags: tags,
          originalName: entry.file.originalName,
          mimeType: entry.file.mimeType,
        );
        entry.saved = true;
        try {
          await _incoming.deleteStaged(entry.file);
        } on FileSystemException {
          // The independently copied Vault version is already durable.
        }
      } catch (error) {
        entry.error = error.toString();
      }
      if (!mounted) return;
      setState(() { _processed++; });
    }

    // Bound concurrency to two files so large imports do not exhaust memory.
    for (var i = 0; i < pending.length; i += 2) {
      await Future.wait(pending.skip(i).take(2).map(saveEntry));
      if (!mounted) return;
    }

    await _archive.refresh();
    if (!mounted) return;
    setState(() => _saving = false);
    if (_pending.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_pending.length} فایل ذخیره نشد؛ دوباره تلاش کنید.'),
      ));
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    await _incoming.cleanup(_pending.map((e) => e.file));
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    // This also covers gesture/system-back navigation and cancelled imports.
    unawaited(_incoming.cleanup(_pending.map((e) => e.file)));
    for (final entry in _entries) { entry.title.dispose(); }
    _tagsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _pending;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت فایل‌ها در آرشیو'),
          leading: IconButton(
            tooltip: 'لغو ورود',
            onPressed: _saving ? null : _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.lock_outline_rounded,
                        color: theme.colorScheme.primary, size: 30),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pending.length} فایل آماده ذخیره',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                        const Text('نسخه جداگانه‌ای در حافظه خصوصی ساخته می‌شود.'),
                      ],
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Text('عنوان اختصاصی هر فایل', style: theme.textTheme.titleMedium),
              const SizedBox(height: 9),
              ...pending.map((entry) => Card(
                key: ValueKey(entry.file.stagedFile.path),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.file.originalName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: entry.title,
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'عنوان قابل جستجو *',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (s) => s?.trim().isEmpty == true
                            ? 'برای هر فایل عنوان وارد کنید' : null,
                      ),
                      if (entry.error != null) Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(entry.error!, maxLines: 3,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 14),
              Text('برچسب‌ها (مشترک)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _tagsController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  hintText: 'یارانه، کالابرگ، اطلاعیه',
                  helperText: 'برای ساخت چند برچسب از ویرگول استفاده کنید.',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 9),
              FutureBuilder<List<MediaTag>>(
                future: _knownTags,
                builder: (context, snapshot) {
                  final tags = snapshot.data ?? const <MediaTag>[];
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return Wrap(spacing: 7, runSpacing: 5,
                    children: tags.map((tag) => FilterChip(
                      label: Text(tag.name),
                      selected: _selectedTags.contains(tag.name),
                      onSelected: _saving ? null : (value) => setState(() {
                        if (value) { _selectedTags.add(tag.name); }
                        else { _selectedTags.remove(tag.name); }
                      }),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text('توضیحات اختیاری (مشترک)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'توضیح کوتاه درباره فایل‌ها'),
              ),
              const SizedBox(height: 22),
              if (_saving) ...[
                LinearProgressIndicator(
                    value: _saveTotal == 0 ? 1 : _processed / _saveTotal),
                const SizedBox(height: 10),
                Text('در حال ذخیره $_processed از $_saveTotal فایل'),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _saving || pending.isEmpty ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'در حال ذخیره‌سازی...' : 'ذخیره در آرشیو خصوصی'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
