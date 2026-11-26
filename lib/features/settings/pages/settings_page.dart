import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../app/flavor_config.dart';
import '../../../app/resaneh_brand_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../providers/app_lock_controller.dart';
import '../../../providers/archive_provider.dart';
import '../../../providers/clipbox_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/backup/backup_documents_channel.dart';
import '../../../services/backup/backup_service.dart';
import '../../../services/storage/factory_reset_service.dart';
import '../../../services/storage/storage_analyzer.dart';
import '../widgets/pin_settings_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.flavor});
  final FlavorConfig flavor;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<StorageReport> _report;
  late Future<PackageInfo> _package;
  bool _working = false;
  final _documents = const BackupDocumentsChannel();

  @override
  void initState() {
    super.initState();
    _refreshReport();
    _package = PackageInfo.fromPlatform();
  }

  void _refreshReport() {
    _report = context.read<StorageAnalyzer>().analyze();
  }

  void _message(String content) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content)),
    );
  }

  Future<T?> _busy<T>(Future<T?> Function() task) async {
    if (_working) return null;
    setState(() => _working = true);
    final settings = context.read<SettingsProvider>();
    settings.beginMaintenance();
    try {
      return await task();
    } finally {
      settings.endMaintenance();
      if (mounted) setState(() {
        _working = false;
        _refreshReport();
      });
    }
  }

  Future<void> _export() async {
    await _busy(() async {
      File? zip;
      try {
        zip = await context.read<BackupService>().createBackup(
          applicationId: widget.flavor.applicationId,
        );
        final date = DateTime.now().toIso8601String().substring(0, 10);
        final exported = await _documents.exportZip(
          sourcePath: zip.path,
          suggestedName: 'Resaneh-${widget.flavor.flavorName}-$date.zip',
        );
        if (exported) _message('نسخه پشتیبان در محل انتخاب‌شده ذخیره شد.');
      } catch (error) {
        _message('پشتیبان‌گیری ناموفق بود: $error');
      } finally {
        if (zip != null) await context.read<BackupService>().deleteExportTemp(zip);
      }
    });
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('بازیابی کامل اطلاعات'),
      content: const Text('با بازیابی، تمام فایل‌ها، کلیپ‌باکس و تنظیمات این برنامه با اطلاعات ZIP جایگزین می‌شوند. ابتدا از اطلاعات فعلی بکاپ بگیرید. رمز PIN دستگاه داخل ZIP نیست.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انتخاب فایل بکاپ')),
      ],
    ));
    if (confirm != true || !mounted) return;
    await _busy(() async {
      final source = await _documents.importZip();
      if (source == null) return;
      final file = File(source);
      try {
        await context.read<BackupService>().restoreBackup(
          zip: file,
          applicationId: widget.flavor.applicationId,
        );
        if (!mounted) return;
        await context.read<SettingsProvider>().reload();
        await context.read<ArchiveProvider>().refresh();
        await context.read<ClipboxProvider>().refresh();
        _message('بازیابی با موفقیت انجام شد.');
      } catch (error) {
        _message('بازیابی ناموفق بود؛ قبل از ادامه وضعیت داده‌ها را بررسی کنید: $error');
      } finally {
        if (await file.exists()) await file.delete();
      }
    });
  }

  Future<void> _configurePin(PinAction action) async {
    final result = await showDialog<PinFormResult>(context: context,
      builder: (_) => PinSettingsDialog(action: action));
    if (result == null || !mounted) return;
    try {
      final lock = context.read<AppLockController>();
      switch (action) {
        case PinAction.enable:
          await lock.enable(result.newPin);
        case PinAction.change:
          await lock.change(result.currentPin, result.newPin);
        case PinAction.disable:
          await lock.disable(result.currentPin);
      }
      _message('تنظیمات قفل برنامه ذخیره شد.');
    } catch (error) {
      _message('تغییر رمز انجام نشد: $error');
    }
  }

  Future<void> _reset() async {
    final warning = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('منطقه خطر: حذف همه اطلاعات'),
      content: const Text('تمام فایل‌های آرشیو، تصاویر پیش‌نمایش، کلیپ‌باکس، دیتابیس، تنظیمات و قفل برنامه برای همیشه حذف خواهند شد. این عمل قابل بازگشت نیست.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('مرحله تأیید دوم')),
      ],
    ));
    if (warning != true || !mounted) return;
    final field = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('تأیید نهایی ریست'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('برای حذف دائمی، کلمه «حذف» را دقیقاً وارد کنید.'),
            const SizedBox(height: 10),
            TextField(controller: field, onChanged: (_) => update(() {}),
              decoration: const InputDecoration(labelText: 'عبارت تأیید')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(
              onPressed: field.text.trim() == 'حذف'
                  ? () => Navigator.pop(ctx, true) : null,
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('پاک کردن همه اطلاعات'),
            ),
          ],
        ),
      ));
      if (confirmed != true || !mounted) return;
      await _busy(() async {
        try {
          await context.read<FactoryResetService>().reset();
          if (!mounted) return;
          context.read<SettingsProvider>().resetToDefaults();
          context.read<AppLockController>().afterFactoryReset();
          await context.read<ArchiveProvider>().refresh();
          await context.read<ClipboxProvider>().refresh();
          if (!mounted) return;
          Navigator.of(context).pop();
          _message('برنامه به حالت روز اول برگشت.');
        } catch (error) {
          _message('ریست کامل نشد: $error');
        }
      });
    } finally {
      field.dispose();
    }
  }


  Widget _storagePanel(StorageReport r) {
    final total = r.total <= 0 ? 1 : r.total;
    final scheme = Theme.of(context).colorScheme;
    final brand = ResanehBrandTheme.of(context);
    final values = <(String, int, Color)>[
      ('عکس‌ها', r.photoBytes, brand.imageColor),
      ('ویدیوها', r.videoBytes, brand.videoColor),
      ('PDF', r.pdfBytes, brand.pdfColor),
      ('سایر فایل‌ها', r.otherBytes, brand.otherColor),
      ('پیش‌نمایش‌ها', r.thumbnailBytes, const Color(0xFFD97706)),
      ('دیتابیس', r.databaseBytes, scheme.primary),
      ('فایل‌های بدون رکورد', r.orphanBytes, const Color(0xFF6B7280)),
    ];
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('حجم داده‌های برنامه: ${Formatters.fileSize(r.total)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(JalaliFormatter.toPersianDigits(
               '${r.mediaCount} فایل آرشیو · ${r.clipCount} متن کلیپ‌باکس'),
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final entry in values) ...[
            Row(children: [
              Expanded(child: Text(entry.$1, style: Theme.of(context).textTheme.bodySmall)),
              Text(Formatters.fileSize(entry.$2), style: Theme.of(context).textTheme.labelSmall),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: entry.$2 / total,
                minHeight: 9,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(entry.$3),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('درصدها سهم هر دسته از داده‌های آرشیو هستند، نه درصد فضای کل گوشی.',
            style: Theme.of(context).textTheme.labelSmall),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final lock = context.watch<AppLockController>();
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_working,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنظیمات')),
        body: Stack(children: [
          ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 45), children: [
            Text('مدیریت فضای ذخیره‌سازی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<StorageReport>(
              future: _report,
              builder: (_, snapshot) {
                if (snapshot.hasError) {
                  return Card(child: ListTile(title: const Text('خواندن اطلاعات حافظه ناموفق بود'),
                    subtitle: Text('${snapshot.error}'),
                    trailing: IconButton(onPressed: () => setState(_refreshReport),
                      icon: const Icon(Icons.refresh_rounded))));
                }
                if (!snapshot.hasData) {
                  return const Card(child: Padding(padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())));
                }
                return _storagePanel(snapshot.data!);
              },
            ),
            const SizedBox(height: 18),
            Text('پشتیبان‌گیری و بازیابی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('ساخت بکاپ ZIP'),
                subtitle: const Text('آرشیو فایل‌ها، دیتابیس، کلیپ‌باکس و تنظیمات'),
                enabled: !_working,
                onTap: _export,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('بازیابی بکاپ در این برنامه'),
                subtitle: const Text('جایگزین کردن کامل داده‌ها از ZIP معتبر'),
                enabled: !_working,
                onTap: _restore,
              ),
            ])),
            const SizedBox(height: 18),
            Text('قفل و امنیت', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Card(child: Column(children: [
              ListTile(
                leading: Icon(lock.enabled ? Icons.lock_rounded : Icons.lock_open_rounded),
                title: Text(lock.enabled ? 'قفل PIN فعال است' : 'قفل PIN غیرفعال است'),
                subtitle: const Text('محافظت چهاررقمی از ورود به برنامه'),
                trailing: IconButton(
                  tooltip: lock.enabled ? 'غیرفعال‌سازی' : 'فعال‌سازی',
                  onPressed: _working ? null : () => _configurePin(
                    lock.enabled ? PinAction.disable : PinAction.enable),
                  icon: Icon(lock.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_outlined),
                ),
              ),
              if (lock.enabled) ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('تغییر رمز چهاررقمی'),
                enabled: !_working,
                onTap: () => _configurePin(PinAction.change),
              ),
            ])),
            const SizedBox(height: 18),
            Text('ظاهر برنامه', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('تم نمایش'),
                const SizedBox(height: 9),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('سیستم')),
                    ButtonSegment(value: ThemeMode.light, label: Text('روشن')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('تاریک')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: _working ? null : (value) async {
                    await settings.setTheme(value.first);
                  },
                ),
                const SizedBox(height: 18),
                const Text('نمایش آرشیو'),
                const SizedBox(height: 9),
                SegmentedButton<ArchiveLayout>(
                  segments: const [
                    ButtonSegment(value: ArchiveLayout.list,
                        label: Text('کارت افقی'), icon: Icon(Icons.view_list_rounded)),
                    ButtonSegment(value: ArchiveLayout.grid,
                        label: Text('شبکه‌ای'), icon: Icon(Icons.grid_view_rounded)),
                  ],
                  selected: {settings.layout},
                  onSelectionChanged: _working ? null : (value) async {
                    await settings.setLayout(value.first);
                  },
                ),
              ],
            ))),
            const SizedBox(height: 18),
            Text('درباره برنامه', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            FutureBuilder<PackageInfo>(future: _package,
              builder: (context, snapshot) => Card(child: ListTile(
                leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                title: Text(widget.flavor.appName),
                subtitle: Text('${widget.flavor.description}\n'
                  'شناسه: ${widget.flavor.applicationId}\n'
                  'نسخه: ${snapshot.hasData ? snapshot.data!.version : '...'} '
                  '(${snapshot.hasData ? snapshot.data!.buildNumber : '...'})'),
                isThreeLine: true,
              )),
            ),
            const SizedBox(height: 18),
            Text('منطقه خطر', style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            Card(child: ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
              title: Text('حذف کامل و بازنشانی برنامه',
                style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('پاک‌سازی دائمی همه داده‌ها با تأیید دومرحله‌ای'),
              enabled: !_working,
              onTap: _reset,
            )),
          ]),
          if (_working) Positioned.fill(child: Container(
            color: Colors.black38,
            child: const Center(child: Card(child: Padding(
              padding: EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('در حال پردازش اطلاعات...'),
              ]),
            ))),
          )),
        ]),
      ),
    );
  }
}
