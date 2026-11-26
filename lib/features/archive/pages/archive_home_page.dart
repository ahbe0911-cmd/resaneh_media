import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../app/flavor_config.dart';
import '../../../app/resaneh_brand_theme.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/media_tag.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../providers/archive_provider.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/archive_filter_bar.dart';
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
  final bool active;
  final ValueChanged<String> onReceivedText;
  const ArchiveHomePage({super.key, required this.config,
    required this.active, required this.onReceivedText});
  @override
  State<ArchiveHomePage> createState() => _ArchiveHomePageState();
}

class _ArchiveHomePageState extends State<ArchiveHomePage> {
  late final ArchiveProvider _archive;
  late final VaultService _vault;
  late final IncomingFileService _incoming;
  late final MediaActionService _mediaActions;
  late final ShareIntentService _shareIntent;
  late final ScrollController _scroll;
  bool _picking = false;
  bool _batchBusy = false;
  final _selected = <String, MediaItem>{};
  final _search = TextEditingController();
  String? _tagLabel;

  @override
  void initState() {
    super.initState();
    _archive = context.read<ArchiveProvider>();
    _search.text = _archive.query;
    _vault = context.read<VaultService>();
    _incoming = context.read<IncomingFileService>();
    _mediaActions = context.read<MediaActionService>();
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

  @override
  void didUpdateWidget(covariant ArchiveHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active && !_batchBusy) _selected.clear();
  }

  void _onScroll() {
    if (!_scroll.hasClients || !widget.active || _batchBusy) return;
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
    widget.onReceivedText(value);
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
            builder: (_) => ImageViewerPage(filePath: file.path, title: item.title,
              heroTag: 'media_${item.id}'),
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

  void _toggleSelection(MediaItem item) {
    if (_batchBusy || _archive.isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else {
        _selected[item.id] = item;
      }
    });
  }

  void _clearSelection() {
    if (!_batchBusy) setState(_selected.clear);
  }

  void _changeQuery(String value) {
    _clearSelection();
    _archive.setQuery(value);
  }

  Future<void> _chooseTag() async {
    try {
      final tags = await context.read<TagRepository>().getAll();
      if (!mounted) return;
      final selected = await showModalBottomSheet<MediaTag>(
        context: context, showDragHandle: true, useSafeArea: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .55,
          child: tags.isEmpty
            ? const Center(child: Text('هنوز برچسبی ثبت نشده است.'))
            : ListView.builder(
                itemCount: tags.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(tags[i].name),
                  selected: tags[i].id == _archive.tagFilter,
                  onTap: () => Navigator.pop(ctx, tags[i]),
                ),
              ),
        ),
      );
      if (!mounted || selected == null) return;
      setState(() => _tagLabel = selected.name);
      await _archive.setTagFilter(selected.id);
    } catch (error) {
      _showMessage('خواندن برچسب‌ها ناموفق بود: $error');
    }
  }

  Future<void> _toggleLayout(SettingsProvider settings) async {
    try {
      await settings.setLayout(settings.layout == ArchiveLayout.list
        ? ArchiveLayout.grid : ArchiveLayout.list);
    } catch (error) {
      _showMessage('تغییر حالت نمایش ناموفق بود: $error');
    }
  }

  Future<void> _batch(String action) async {
    if (_batchBusy || _selected.isEmpty) return;
    final settings = context.read<SettingsProvider>();
    if (settings.isBusy) return;
    final items = _selected.values.toList(growable: false);
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف دائمی فایل‌های انتخابی'),
          content: Text('آیا از حذف دائمی ${JalaliFormatter.toPersianDigits(
            items.length.toString())} فایل مطمئن هستید؟ این عملیات بازگشت ندارد.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
              child: const Text('حذف دائمی')),
          ],
        ));
      if (confirmed != true || !mounted || settings.isBusy) return;
    }
    setState(() => _batchBusy = true);
    settings.beginMaintenance();
    try {
      if (action == 'share') {
        await _mediaActions.shareFiles(items, _vault);
        return;
      }
      final completed = action == 'delete'
        ? await _archive.deleteBatch(items.map((item) => item.id))
        : await _archive.setPinnedBatch(items, action == 'pin');
      if (!mounted) return;
      setState(() {
        for (final id in completed) {
          _selected.remove(id);
        }
      });
      final done = JalaliFormatter.toPersianDigits(completed.length.toString());
      final failed = JalaliFormatter.toPersianDigits(
        (items.length - completed.length).toString());
      _showMessage(completed.length == items.length
        ? 'عملیات برای $done فایل انجام شد.'
        : '$done موفق، $failed ناموفق؛ فایل‌های ناموفق در انتخاب باقی ماندند.');
    } catch (error) {
      _showMessage('عملیات گروهی انجام نشد: $error');
    } finally {
      settings.endMaintenance();
      if (mounted) setState(() => _batchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ArchiveProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final brand = ResanehBrandTheme.of(context);
    final selection = _selected.isNotEmpty;
    final enabled = !settings.isBusy && !_batchBusy;
    final items = state.items;
    return PopScope(
      canPop: !widget.active || (!selection && !_batchBusy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active && selection && !_batchBusy) _clearSelection();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              if (enabled && !selection) await state.refresh();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true, snap: true, pinned: selection, toolbarHeight: 62,
                  automaticallyImplyLeading: false,
                  title: selection
                    ? Text('${JalaliFormatter.toPersianDigits(_selected.length.toString())} انتخاب‌شده')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, children: [
                        Text(widget.config.appName, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800)),
                        Text(JalaliFormatter.formatShortDate(DateTime.now()),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                  leading: selection ? IconButton(tooltip: 'لغو انتخاب',
                    onPressed: enabled ? _clearSelection : null,
                    icon: const Icon(Icons.close_rounded)) : null,
                  actions: [
                    if (selection) ...[
                      IconButton(tooltip: 'اشتراک‌گذاری انتخاب‌ها',
                        onPressed: enabled ? () => _batch('share') : null,
                        icon: const Icon(Icons.ios_share_rounded)),
                      PopupMenuButton<String>(
                        enabled: enabled, tooltip: 'عملیات گروهی',
                        onSelected: (value) => _batch(value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'pin', child: Text('سنجاق کردن همه')),
                          PopupMenuItem(value: 'unpin', child: Text('برداشتن سنجاق همه')),
                          PopupMenuItem(value: 'delete', child: Text('حذف انتخاب‌ها')),
                        ]),
                      IconButton(tooltip: 'انتخاب همه فایل‌های بارگذاری‌شده',
                        onPressed: enabled && !state.isLoading ? () => setState(() {
                          for (final item in items) {
                            _selected[item.id] = item;
                          }
                        }) : null,
                        icon: const Icon(Icons.select_all_rounded)),
                    ] else
                      Padding(padding: const EdgeInsetsDirectional.only(end: 16),
                        child: Center(child: Container(
                          width: 37, height: 37,
                          decoration: BoxDecoration(gradient: brand.headerGradient,
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.folder_copy_rounded,
                            color: Colors.white, size: 20),
                        ))),
                  ],
                ),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 6),
                  child: TextField(
                    controller: _search,
                    enabled: enabled && !selection,
                    textInputAction: TextInputAction.search,
                    onChanged: _changeQuery,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'جستجو در فایل‌ها و برچسب‌ها...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty ? null : IconButton(
                        tooltip: 'پاک کردن جستجو',
                        onPressed: enabled && !selection ? () {
                          _search.clear();
                          _changeQuery('');
                        } : null,
                        icon: const Icon(Icons.close_rounded)),
                    ),
                  ),
                )),
                SliverToBoxAdapter(child: ArchiveFilterBar(
                  type: state.selectedType, sort: state.sort, layout: settings.layout,
                  enabled: enabled && !selection,
                  tagLabel: state.tagFilter == null ? null : (_tagLabel ?? 'برچسب انتخابی'),
                  onTag: () => unawaited(_chooseTag()),
                  onClearTag: () {
                    setState(() => _tagLabel = null);
                    unawaited(state.setTagFilter(null));
                  },
                  onType: (value) => unawaited(state.setType(value)),
                  onSort: (value) => unawaited(state.setSort(value)),
                  onToggleLayout: () => unawaited(_toggleLayout(settings)),
                )),
                if (_batchBusy || (state.isLoading && items.isNotEmpty))
                  const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
                if (items.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: _emptyState(state))
                else if (settings.layout == ArchiveLayout.grid)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.sizeOf(context).width < 340 ? 340 : 240,
                        mainAxisExtent: 250.0 + (MediaQuery.textScalerOf(context)
                          .scale(14) - 14).clamp(0.0, 70.0).toDouble(),
                        crossAxisSpacing: 10, mainAxisSpacing: 10),
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _card(items[index], state, true, enabled),
                        childCount: items.length),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (_, index) => _card(items[index], state, false, enabled),
                      childCount: items.length)),
                  ),
                if (state.hasMore && items.isNotEmpty)
                  SliverToBoxAdapter(child: Center(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: state.isLoadingMore ? const CircularProgressIndicator()
                      : TextButton(onPressed: enabled ? state.loadMore : null,
                          child: const Text('نمایش فایل‌های بیشتر')),
                  ))),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
        floatingActionButton: selection ? null : FloatingActionButton.extended(
          onPressed: _picking || !enabled ? null : _pickFiles,
          icon: _picking ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_rounded),
          label: const Text('افزودن فایل'),
        ),
      ),
    );
  }

  Widget _emptyState(ArchiveProvider state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;
    final filtered = state.query.isNotEmpty || state.selectedType != null || state.tagFilter != null;
    return Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 40, backgroundColor: scheme.primaryContainer,
          child: Icon(state.error != null ? Icons.error_outline_rounded
            : filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 38, color: scheme.onPrimaryContainer)),
        const SizedBox(height: 18),
        Text(state.error != null ? 'بارگذاری آرشیو ناموفق بود'
          : filtered ? 'فایلی پیدا نشد' : 'آرشیو شما آماده است',
          style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(filtered ? 'عبارت جستجو یا نوع فایل را تغییر دهید.'
          : 'با افزودن فایل، آرشیو خصوصی خود را بسازید.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
        if (state.error != null)
          TextButton(onPressed: state.refresh, child: const Text('تلاش مجدد')),
      ]),
    ));
  }

  Widget _card(MediaItem item, ArchiveProvider state, bool grid, bool enabled) {
    final selection = _selected.isNotEmpty;
    void open() {
      if (!enabled) return;
      if (selection) {
        _toggleSelection(item);
      } else {
        unawaited(_openMedia(item));
      }
    }
    final thumbnail = item.thumbnailPath == null ? null : _vault.resolveThumbnailFile(item);
    return AbsorbPointer(
      key: ValueKey(item.id),
      absorbing: !enabled || (selection && state.isLoading),
      child: grid ? MediaGridCard(
        item: item, thumbnail: thumbnail, onOpen: open,
        selectionMode: selection, selected: _selected.containsKey(item.id),
        onLongPress: () => _toggleSelection(item),
        onShare: () => _share(item), onEdit: () => _edit(item),
        onPin: () => state.setPinned(item), onDelete: () => _delete(item),
        onDetails: () => _details(item),
      ) : MediaItemCard(
        item: item, thumbnailFile: thumbnail, onTap: open,
        selectionMode: selection, selected: _selected.containsKey(item.id),
        onLongPress: () => _toggleSelection(item),
        onShare: () => _share(item), onEdit: () => _edit(item),
        onPin: () => state.setPinned(item), onDelete: () => _delete(item),
        onDetails: () => _details(item),
      ),
    );
  }
}
