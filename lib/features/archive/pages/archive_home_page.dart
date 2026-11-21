import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../app/flavor_config.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../data/models/media_item.dart';
import '../../../providers/archive_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../clipbox/pages/clipbox_page.dart';
import '../../settings/pages/settings_page.dart';
import '../widgets/media_grid_card.dart';
import '../../../services/import/incoming_file.dart';
import '../../../services/import/incoming_file_service.dart';
import '../../../services/sharing/media_action_service.dart';
import '../../../services/sharing/share_intent_service.dart';
import '../../../services/vault/vault_service.dart';
import '../../viewer/image_viewer_page.dart';
import '../../viewer/video_viewer_page.dart';
import '../widgets/media_details_sheet.dart';
import '../widgets/media_edit_dialog.dart';
import '../widgets/media_item_card.dart';
import 'import_files_page.dart';

class ArchiveHomePage extends StatefulWidget {
  final FlavorConfig config;
  const ArchiveHomePage({super.key, required this.config});
  @override
  State<ArchiveHomePage> createState() => _ArchiveHomePageState();
}

class _ArchiveHomePageState extends State<ArchiveHomePage> {
  late final ArchiveProvider _archive;
  late final VaultService _vault;
  late final IncomingFileService _incoming;
  late final MediaActionService _mediaActions;
  late final ShareIntentService _shareIntent;
  late final TextEditingController _search;
  late final ScrollController _scroll;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _archive = context.read<ArchiveProvider>();
    _vault = context.read<VaultService>();
    _incoming = context.read<IncomingFileService>();
    _mediaActions = context.read<MediaActionService>();
    _search = TextEditingController();
    _scroll = ScrollController()..addListener(_onScroll);
    _shareIntent = ShareIntentService(
      files: _incoming,
      onFiles: _receiveFiles,
      onText: _receiveText,
      onError: _showMessage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_archive.initialize());
      unawaited(_shareIntent.start());
    });
  }

  @override
  void dispose() {
    unawaited(_shareIntent.dispose());
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      unawaited(_archive.loadMore());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _receiveText(String value) {
    if (!mounted) return;
    unawaited(Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ClipboxPage(initialText: value),
    )));
  }

  Future<void> _receiveFiles(List<IncomingFile> files) async {
    await _openImport(files);
  }

  Future<void> _openImport(List<IncomingFile> files) async {
    if (!mounted) {
      await _incoming.cleanup(files);
      return;
    }
    if (files.isEmpty) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ImportFilesPage(files: files),
    ));
    if (mounted) await _archive.refresh();
  }

  Future<void> _pickFiles() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await _incoming.pickFiles();
      if (!mounted) {
        await _incoming.cleanup(files);
        return;
      }
      if (files.isNotEmpty) await _openImport(files);
    } catch (error) {
      _showMessage('انتخاب فایل ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _openMedia(MediaItem item) async {
    try {
      await _vault.initialize();
      final file = _vault.resolveStoredFile(item.relativePath);
      if (!await file.exists()) throw const FileSystemException('فایل موجود نیست');
      if (!mounted) return;
      switch (item.fileType) {
        case MediaFileType.image:
          await Navigator.push<void>(context, MaterialPageRoute(
            builder: (_) => ImageViewerPage(filePath: file.path, title: item.title),
          ));
          break;
        case MediaFileType.video:
          await Navigator.push<void>(context, MaterialPageRoute(
            builder: (_) => VideoViewerPage(filePath: file.path, title: item.title),
          ));
          break;
        case MediaFileType.pdf:
        case MediaFileType.other:
          final response = await _mediaActions.openExternal(item, _vault);
          if (response.type != ResultType.done) _showMessage(response.message);
          break;
      }
    } catch (error) {
      _showMessage('باز کردن فایل ناموفق بود: $error');
    }
  }

  Future<void> _share(MediaItem item) async {
    try {
      await _mediaActions.shareFile(item, _vault);
    } catch (error) {
      _showMessage('اشتراک‌گذاری ناموفق بود: $error');
    }
  }

  Future<void> _edit(MediaItem item) async {
    final result = await showDialog<MediaEditData>(context: context,
      builder: (_) => MediaEditDialog(item: item));
    if (!mounted || result == null) return;
    final updated = await _archive.updateMetadata(
      id: item.id,
      title: result.title,
      description: result.description,
      tags: result.tags,
    );
    _showMessage(updated ? 'اطلاعات فایل به‌روزرسانی شد.' :
      'ویرایش انجام نشد: ${_archive.error ?? 'خطای نامشخص'}');
  }

  Future<void> _delete(MediaItem item) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف دائمی فایل'),
        content: Text('«${item.title}» از دیتابیس و حافظه خصوصی حذف شود؟ این عملیات بازگشت ندارد.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف دائمی')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final removed = await _archive.deleteItem(item.id);
    _showMessage(removed ? 'فایل از آرشیو حذف شد.' :
      'حذف انجام نشد: ${_archive.error ?? 'خطای نامشخص'}');
  }

  void _details(MediaItem item) => showModalBottomSheet<void>(
    context: context, useSafeArea: true, showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MediaDetailsSheet(item: item),
  );

  Future<void> _openClipbox() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const ClipboxPage()),
  );

  Future<void> _openSettings() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SettingsPage(flavor: widget.config)),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ArchiveProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.appName),
        actions: [
          TextButton.icon(
            onPressed: _openClipbox,
            icon: const Icon(Icons.content_paste_rounded, size: 19),
            label: const Text('کلیپ‌باکس',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          IconButton(tooltip: 'تنظیمات', onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('آرشیو رسانه', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(widget.config.isKetabkhaneh
                  ? 'مدیریت هوشمند اسناد و رسانه‌های کتابخانه'
                  : 'تمام فایل‌های کاری شما در یک مکان امن',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 15),
              TextField(
                controller: _search,
                onChanged: (v) { state.setQuery(v); setState(() {}); },
                decoration: InputDecoration(
                  hintText: 'جستجوی عنوان، توضیح یا برچسب...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isNotEmpty
                    ? IconButton(tooltip: 'پاک‌کردن', onPressed: () {
                        _search.clear(); state.setQuery(''); setState(() {});
                      }, icon: const Icon(Icons.close_rounded))
                    : null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 43, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _filter('همه', null, state),
            _filter('عکس', MediaFileType.image, state),
            _filter('ویدیو', MediaFileType.video, state),
            _filter('PDF', MediaFileType.pdf, state),
            _filter('سایر فایل‌ها', MediaFileType.other, state),
          ],
        )),
        const SizedBox(height: 8),
        if (state.isLoading && state.items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: RefreshIndicator(
          onRefresh: state.refresh,
          child: _buildList(state),
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _picking ? null : _pickFiles,
        icon: _picking
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_rounded),
        label: const Text('افزودن فایل'),
      ),
    );
  }

  Widget _filter(String label, MediaFileType? type, ArchiveProvider state) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: state.selectedType == type,
        showCheckmark: false,
        onSelected: (_) => state.setType(type),
      ),
    );
  }

  Widget _buildList(ArchiveProvider state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 95),
        const Icon(Icons.error_outline_rounded, size: 54),
        const SizedBox(height: 15),
        const Center(child: Text('بارگذاری آرشیو ناموفق بود')),
        const SizedBox(height: 15),
        Center(child: FilledButton.icon(onPressed: state.refresh,
          icon: const Icon(Icons.refresh_rounded), label: const Text('تلاش مجدد'))),
      ]);
    }
    if (state.items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 96),
        Icon(state.query.isNotEmpty || state.selectedType != null
          ? Icons.search_off_rounded : Icons.inventory_2_outlined,
          size: 62, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Center(child: Text(state.query.isNotEmpty || state.selectedType != null
            ? 'فایلی با این جستجو پیدا نشد' : 'آرشیو شما هنوز خالی است')),
        const SizedBox(height: 6),
        const Center(child: Text('از دکمه افزودن فایل استفاده کنید.')),
      ]);
    }
    if (context.watch<SettingsProvider>().layout == ArchiveLayout.grid) {
      return GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 5, 14, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          mainAxisExtent: 268,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Center(child: TextButton(
              onPressed: state.loadMore,
              child: const Text('بیشتر'),
            ));
          }
          final item = state.items[index];
          return MediaGridCard(
            item: item,
            thumbnail: item.thumbnailPath == null
                ? null : _vault.resolveThumbnailFile(item),
            onOpen: () => _openMedia(item),
            onShare: () => _share(item),
            onEdit: () => _edit(item),
            onPin: () => state.setPinned(item),
            onDelete: () => _delete(item),
          );
        },
      );
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(15),
            child: state.isLoadingMore
                ? const CircularProgressIndicator()
                : TextButton(onPressed: state.loadMore,
                    child: const Text('نمایش فایل‌های بیشتر')),
          ));
        }
        final item = state.items[index];
        return MediaItemCard(
          item: item,
          thumbnailFile: item.thumbnailPath == null
              ? null : _vault.resolveThumbnailFile(item),
          onTap: () => _openMedia(item),
          onShare: () => _share(item),
          onPin: () => state.setPinned(item),
          onEdit: () => _edit(item),
          onDelete: () => _delete(item),
          onDetails: () => _details(item),
        );
      },
    );
  }
}
