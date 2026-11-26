import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../app/flavor_config.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/formatters.dart';
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
  late final ScrollController _scroll;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _archive = context.read<ArchiveProvider>();
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
        toolbarHeight: 62,
        titleSpacing: 15,
        title: Text(widget.config.appName,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: _openClipbox,
            icon: const Icon(Icons.content_paste_rounded, size: 19),
            label: const Text('کلیپ‌باکس',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(17, 12, 17, 11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
              )),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_mosaic_outlined,
                  size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('آرشیو فایل‌ها',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'جستجو',
                  onPressed: _openSearch,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 42, height: 40),
                  icon: const Icon(Icons.search_rounded, size: 22),
                ),
                IconButton(
                  tooltip: 'فیلتر فایل‌ها',
                  onPressed: _openFilters,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 42, height: 40),
                  icon: Badge(
                    isLabelVisible: state.selectedType != null,
                    smallSize: 7,
                    child: const Icon(Icons.tune_rounded, size: 21),
                  ),
                ),
                Icon(Icons.calendar_month_outlined, size: 15,
                  color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(JalaliFormatter.formatShortDate(DateTime.now()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (state.query.trim().isNotEmpty || state.selectedType != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 14, 3),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 7, runSpacing: 4, children: [
                  if (state.query.trim().isNotEmpty)
                    InputChip(
                      avatar: const Icon(Icons.search_rounded, size: 16),
                      label: Text(state.query, overflow: TextOverflow.ellipsis),
                      onPressed: _openSearch,
                      onDeleted: () => state.setQuery(''),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (state.selectedType != null)
                    InputChip(
                      avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                      label: Text(Formatters.typeLabel(state.selectedType, plural: true)),
                      onPressed: _openFilters,
                      onDeleted: () => unawaited(state.setType(null)),
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ),
            ),
          if (state.isLoading && state.items.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refresh,
              child: _buildList(state),
            ),
          ),
        ],
      ),
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


  Future<void> _openFilters() async {
    final current = _archive.selectedType;
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نمایش فایل‌ها',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('نوع فایل موردنظر را انتخاب کنید.',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            for (final type in <MediaFileType?>[
              null, MediaFileType.image, MediaFileType.video,
              MediaFileType.pdf, MediaFileType.other,
            ])
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
                tileColor: type == current
                  ? scheme.primaryContainer.withValues(alpha: .55) : null,
                leading: Icon(Formatters.typeIcon(type),
                  color: type == current ? scheme.primary : scheme.onSurfaceVariant),
                title: Text(Formatters.typeLabel(type, plural: true),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: type == current
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : const Icon(Icons.chevron_left_rounded, size: 18),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_archive.setType(type));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _archive.query);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final keyboardHeight = MediaQuery.viewInsetsOf(sheetContext).bottom;
            final availableHeight = MediaQuery.sizeOf(sheetContext).height - keyboardHeight;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: SizedBox(
                height: availableHeight * .80,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('جستجو در آرشیو',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: (value) {
                              _archive.setQuery(value);
                              setSheetState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: 'عنوان، توضیحات یا برچسب...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    tooltip: 'پاک‌کردن',
                                    onPressed: () {
                                      controller.clear();
                                      _archive.setQuery('');
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Consumer<ArchiveProvider>(
                        builder: (context, state, _) {
                          if (state.query.trim().isEmpty) {
                            return Center(child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.manage_search_rounded, size: 49,
                                    color: theme.colorScheme.primary.withValues(alpha: .65)),
                                  const SizedBox(height: 14),
                                  const Text('برای یافتن فایل، عنوان یا برچسب آن را بنویسید.',
                                    textAlign: TextAlign.center),
                                ],
                              ),
                            ));
                          }
                          if (state.isLoading && state.items.isEmpty) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state.items.isEmpty) {
                            return const Center(child: Text('فایلی پیدا نشد.'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsetsDirectional.fromSTEB(15, 3, 15, 6),
                            itemCount: state.items.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(Formatters.typeIcon(item.fileType),
                                    color: theme.colorScheme.primary)),
                                title: Text(item.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  'ثبت: ' + JalaliFormatter.formatShortDate(item.createdAt)
                                  + ' · ' + JalaliFormatter.formatTime(item.createdAt),
                                  style: theme.textTheme.labelSmall),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  unawaited(_openMedia(item));
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(18, 7, 18, 15),
                      child: SizedBox(width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.view_list_rounded),
                          label: const Text('نمایش نتایج در آرشیو'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
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
