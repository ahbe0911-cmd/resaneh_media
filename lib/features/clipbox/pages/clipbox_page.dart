import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/jalali_formatter.dart';
import '../../../data/models/clip_entry.dart';
import '../../../providers/clipbox_provider.dart';
import '../widgets/clip_editor_sheet.dart';

class ClipboxPage extends StatefulWidget {
  const ClipboxPage({super.key, this.initialText});
  final String? initialText;

  @override
  State<ClipboxPage> createState() => _ClipboxPageState();
}

class _ClipboxPageState extends State<ClipboxPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final ClipboxProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ClipboxProvider>();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_provider.refresh());
      final received = widget.initialText;
      if (received != null && received.isNotEmpty) unawaited(_edit(initialBody: received));
    });
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 350) {
      unawaited(_provider.loadMore());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),
        duration: const Duration(seconds: 2)));
  }

  Future<void> _edit({ClipEntry? item, String? initialBody}) async {
    final draft = await showModalBottomSheet<ClipDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ClipEditorSheet(initial: item, initialBody: initialBody),
    );
    if (draft == null || !mounted) return;
    try {
      if (item == null) {
        await _provider.add(draft.title, draft.body);
      } else {
        await _provider.update(item, draft.title, draft.body);
      }
      _message('متن با موفقیت ذخیره شد.');
    } catch (error) {
      _message('ذخیره انجام نشد: $error');
    }
  }

  Future<void> _delete(ClipEntry entry) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف متن'),
      content: Text('متن «${entry.title}» برای همیشه حذف شود؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (confirm != true || !mounted) return;
    try {
      await _provider.remove(entry);
      _message('متن حذف شد.');
    } catch (error) {
      _message('حذف انجام نشد: $error');
    }
  }

  Future<void> _copy(ClipEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.body));
    _message('متن «${entry.title}» کپی شد.');
  }

  Future<void> _share(ClipEntry entry) async {
    try {
      await SharePlus.instance.share(ShareParams(text: entry.body, title: entry.title));
    } catch (error) {
      _message('اشتراک‌گذاری ناموفق بود: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ClipboxProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('کلیپ‌باکس')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('متن جدید'),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: (v) { state.setQuery(v); setState(() {}); },
              decoration: InputDecoration(
                hintText: 'جستجوی عنوان یا متن...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty ? null : IconButton(
                  onPressed: () { _search.clear(); state.setQuery(''); setState(() {}); },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            )),
        const SizedBox(height: 8),
        if (state.isLoading && state.items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: RefreshIndicator(
          onRefresh: state.refresh,
          child: state.isLoading && state.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.error != null && state.items.isEmpty
                ? ListView(children: [const SizedBox(height: 90),
                    const Center(child: Text('خطا در بارگذاری کلیپ‌باکس')),
                    Center(child: TextButton(onPressed: state.refresh,
                        child: const Text('تلاش مجدد')))])
                : state.items.isEmpty
                    ? ListView(children: [const SizedBox(height: 95),
                        Icon(Icons.content_paste_off_rounded, size: 60,
                            color: theme.colorScheme.primary),
                        const SizedBox(height: 14),
                        Center(child: Text(state.query.isEmpty
                            ? 'هنوز متنی ذخیره نکرده‌اید.' : 'متنی با این جستجو پیدا نشد.'))])
                    : ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
                        itemCount: state.items.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.items.length) {
                            return Center(child: TextButton(
                              onPressed: state.loadMore, child: const Text('نمایش بیشتر')));
                          }
                          final item = state.items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: theme.dividerColor),
                            ),
                            child: Padding(padding: const EdgeInsets.all(13),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  if (item.isPinned) Icon(Icons.push_pin_rounded,
                                    color: theme.colorScheme.primary, size: 18),
                                  if (item.isPinned) const SizedBox(width: 6),
                                  Expanded(child: Text(item.title,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                                  PopupMenuButton<String>(
                                    tooltip: 'مدیریت متن',
                                    onSelected: (action) async {
                                      try {
                                        if (action == 'edit') await _edit(item: item);
                                        if (action == 'pin') await _provider.togglePin(item);
                                        if (action == 'delete') await _delete(item);
                                      } catch (error) { _message('عملیات انجام نشد: $error'); }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                                      PopupMenuItem(value: 'pin', child: Text(item.isPinned
                                        ? 'برداشتن سنجاق' : 'سنجاق کردن')),
                                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                    ],
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(item.body, maxLines: 4, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 10),
                                Text(JalaliFormatter.formatDateTime(item.createdAt),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 9),
                                Row(children: [
                                  Expanded(child: FilledButton.tonalIcon(
                                    onPressed: () => _copy(item),
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    label: const Text('کپی سریع'),
                                  )),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    tooltip: 'اشتراک‌گذاری متن',
                                    onPressed: () => _share(item),
                                    icon: const Icon(Icons.share_outlined),
                                  ),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
        )),
      ]),
    );
  }
}
