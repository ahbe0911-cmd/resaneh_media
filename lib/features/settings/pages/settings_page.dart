import 'dart:io';

import 'package:flutter/services.dart';

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
import '../../../services/backup/backup_cipher.dart';
import '../widgets/backup_password_dialog.dart';
import '../../../services/storage/factory_reset_service.dart';
import '../../../services/storage/storage_analyzer.dart';
import '../../../services/storage/vault_maintenance_service.dart';
import '../widgets/pin_settings_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.flavor,
    this.active = true, this.onReset});
  final FlavorConfig flavor;
  final bool active;
  final VoidCallback? onReset;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<StorageReport> _report;
  late Future<PackageInfo> _package;
  bool _working = false;
  bool _securityWorking = false;
  double? _maintenanceProgress;
  String? _maintenanceLabel;
  final _documents = const BackupDocumentsChannel();

  @override
  void initState() {
    super.initState();
    _refreshReport();
    _package = PackageInfo.fromPlatform();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_working) {
      _refreshReport();
    }
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
    final settings = context.read<SettingsProvider>();
    if (_working || settings.isBusy) return null;
    settings.beginMaintenance();
    setState(() => _working = true);
    try {
      return await task();
    } finally {
      settings.endMaintenance();
      if (mounted) setState(() {
        _working = false;
        _maintenanceProgress = null;
        _maintenanceLabel = null;
        _refreshReport();
      });
    }
  }

  void _backupProgress(double? fraction, String stage) {
    if (!mounted) return;
    setState(() {
      _maintenanceProgress = fraction;
      _maintenanceLabel = stage;
    });
  }

  Future<void> _export() async {
    final mode = await showDialog<bool>(context: context, builder: (ctx) =>
      SimpleDialog(title: const Text('نوع نسخه پشتیبان'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, false),
          child: const ListTile(leading: Icon(Icons.archive_outlined),
            title: Text('ZIP معمولی'),
            subtitle: Text('بدون رمز؛ فایل‌ها برای دارنده بکاپ قابل خواندن هستند.'))),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, true),
          child: const ListTile(leading: Icon(Icons.enhanced_encryption_outlined),
            title: Text('بکاپ رمزگذاری‌شده'),
            subtitle: Text('AES-256-GCM؛ نیازمند رمز عبور برای بازیابی'))),
      ]));
    if (!mounted || mode == null) return;
    String? password;
    if (mode) {
      password = await showDialog<String>(context: context,
        builder: (_) => const BackupPasswordDialog(confirmPassword: true));
      if (!mounted || password == null) return;
    }
    await _busy(() async {
      File? zip;
      final service = context.read<BackupService>();
      try {
        zip = await service.createBackup(
          applicationId: widget.flavor.applicationId,
          password: password, onProgress: _backupProgress,
        );
        if (!mounted) return;
        final date = DateTime.now().toIso8601String().substring(0, 10);
        final extension = password == null ? 'zip' : 'rmb';
        _backupProgress(null, 'در انتظار ذخیره و انتقال فایل');
        final exported = await _documents.exportZip(
          sourcePath: zip.path,
          suggestedName: 'Resaneh-${widget.flavor.flavorName}-$date.$extension',
        );
        if (exported) _message('نسخه پشتیبان در محل انتخاب‌شده ذخیره شد.');
      } catch (error) {
        _message('پشتیبان‌گیری ناموفق بود: $error');
      } finally {
        if (zip != null) await service.deleteExportTemp(zip);
      }
    });
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('بازیابی کامل اطلاعات'),
      content: const Text('تمام فایل‌ها، کلیپ‌باکس و تنظیمات آرشیو با داده‌های بکاپ ZIP یا RMB جایگزین می‌شوند. ابتدا از اطلاعات فعلی بکاپ بگیرید. رمز PIN و تنظیمات امنیتی دستگاه در بکاپ نیستند.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انتخاب فایل بکاپ')),
      ],
    ));
    if (confirm != true || !mounted) return;
    await _busy(() async {
      File? file;
      final service = context.read<BackupService>();
      try {
        _backupProgress(null, 'در انتظار انتخاب و انتقال بکاپ');
        final source = await _documents.importZip();
        if (source == null) return;
        file = File(source);
        if (!mounted) return;
        final encrypted = await BackupCipher.isEncrypted(file);
        if (!mounted) return;
        String? password;
        if (encrypted) {
          password = await showDialog<String>(context: context,
            builder: (_) => const BackupPasswordDialog(confirmPassword: false));
          if (!mounted || password == null) return;
        }
        await service.restoreBackup(
          zip: file, applicationId: widget.flavor.applicationId,
          password: password, onProgress: _backupProgress,
        );
        if (!mounted) return;
        await context.read<SettingsProvider>().reload();
        if (!mounted) return;
        await context.read<ArchiveProvider>().refresh();
        if (!mounted) return;
        await context.read<ClipboxProvider>().refresh();
        _message('بازیابی با موفقیت انجام شد.');
      } catch (error) {
        _message('بازیابی ناموفق بود؛ قبل از ادامه وضعیت داده‌ها را بررسی کنید: $error');
      } finally {
        if (file != null && await file.exists()) await file.delete();
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

  Future<String?> _askCurrentPin() async {
    final field = TextEditingController();
    try {
      return await showDialog<String>(context: context, builder: (ctx) =>
        StatefulBuilder(builder: (_, update) => AlertDialog(
          title: const Text('تأیید رمز فعلی'),
          content: TextField(controller: field, obscureText: true,
            keyboardType: TextInputType.number, maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enableSuggestions: false, autocorrect: false,
            decoration: const InputDecoration(labelText: 'PIN چهاررقمی'),
            onChanged: (_) => update(() {})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(onPressed: field.text.length == 4
              ? () => Navigator.pop(ctx, field.text) : null,
              child: const Text('تأیید')),
          ],
        )));
    } finally {
      field.dispose();
    }
  }

  Future<void> _changeBiometrics(bool value) async {
    if (_working || _securityWorking) return;
    final lock = context.read<AppLockController>();
    setState(() => _securityWorking = true);
    try {
      final pin = value ? await _askCurrentPin() : null;
      if (!mounted || (value && pin == null)) return;
      await lock.configureBiometrics(value, pin: pin);
      _message(value ? 'ورود بیومتریک فعال شد.' : 'ورود بیومتریک غیرفعال شد.');
    } catch (error) {
      _message('تغییر ورود بیومتریک انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _securityWorking = false);
    }
  }

  Future<void> _changeSecurity(Future<void> Function() change) async {
    if (_working || _securityWorking) return;
    setState(() => _securityWorking = true);
    try {
      await change();
    } catch (error) {
      _message('ذخیره تنظیمات امنیتی ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _securityWorking = false);
    }
  }

  Future<void> _cleanupVault() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('پاک‌سازی فایل‌های بدون رکورد'),
      content: const Text('فقط فایل‌های شناخته‌شده بدون رکورد که بیش از ۱۰ دقیقه از آخرین تغییرشان گذشته و برچسب‌های بلااستفاده حذف می‌شوند. فایل‌های ثبت‌شده دست‌نخورده می‌مانند. این حذف بازگشت ندارد.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('پاک‌سازی')),
      ],
    ));
    if (!mounted || confirm != true) return;
    await _busy(() async {
      try {
        final result = await context.read<VaultMaintenanceService>().cleanup();
        if (!mounted) return;
        String n(int value) => JalaliFormatter.toPersianDigits('$value');
        _message('${n(result.files)} فایل و ${n(result.tags)} برچسب حذف شد؛ '
          '${Formatters.fileSize(result.bytes)} آزاد شد. '
          '${n(result.skipped)} مورد محفوظ و ${n(result.failed)} خطا.');
      } catch (error) {
        _message('پاک‌سازی ناموفق بود: $error');
      }
    });
  }

  Future<void> _rebuildThumbnails() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('بازسازی پیش‌نمایش‌ها'),
      content: const Text('پیش‌نمایش همه تصاویر، ویدیوها و PDFها دوباره تولید می‌شود. اصل فایل‌ها حذف یا تغییر نمی‌کند. اگر تولید پیش‌نمایش ناموفق باشد، تصویر قبلی حفظ می‌شود.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('شروع بازسازی')),
      ],
    ));
    if (!mounted || confirm != true) return;
    await _busy(() async {
      try {
        final archive = context.read<ArchiveProvider>();
        final result = await context.read<VaultMaintenanceService>().rebuildThumbnails(
          onProgress: (done, total) {
            if (mounted) setState(() {
              _maintenanceProgress = total == 0 ? 1 : done / total;
              _maintenanceLabel = 'بازسازی ${JalaliFormatter.toPersianDigits('$done / $total')}';
            });
          });
        await archive.refresh(preserveWindow: true);
        _message(JalaliFormatter.toPersianDigits(
          '${result.rebuilt} پیش‌نمایش بازسازی شد؛ ${result.failed} مورد ناموفق.'));
      } catch (error) {
        _message('بازسازی ناموفق بود: $error');
      }
    });
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
          if (widget.onReset != null) {
            widget.onReset!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
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
            Text('نگهداری و بهینه‌سازی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Card(child: Column(children: [
              ListTile(leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('پاک‌سازی فایل‌های یتیم'),
                subtitle: const Text('فایل‌های بدون رکورد و برچسب‌های بلااستفاده'),
                enabled: !_working && !settings.isBusy, onTap: _cleanupVault),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.photo_library_outlined),
                title: const Text('بازسازی پیش‌نمایش‌ها'),
                subtitle: const Text('اصلاح تصاویر قدیمی و ساخت تصویر PDF'),
                enabled: !_working && !settings.isBusy, onTap: _rebuildThumbnails),
            ])),
            const SizedBox(height: 18),
            Text('پشتیبان‌گیری و بازیابی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('ساخت نسخه پشتیبان'),
                subtitle: const Text('ZIP معمولی یا بکاپ رمزگذاری‌شده RMB'),
                enabled: !_working,
                onTap: _export,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('بازیابی بکاپ در این برنامه'),
                subtitle: const Text('بازیابی از ZIP قدیمی یا بکاپ رمزگذاری‌شده RMB'),
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
                  onPressed: _working || _securityWorking ? null : () => _configurePin(
                    lock.enabled ? PinAction.disable : PinAction.enable),
                  icon: Icon(lock.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_outlined),
                ),
              ),
              if (lock.enabled) ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('تغییر رمز چهاررقمی'),
                enabled: !_working,
                onTap: _securityWorking ? null : () => _configurePin(PinAction.change),
              ),
              if (lock.enabled) ...[
                const Divider(height: 1),
                SwitchListTile(secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('ورود بیومتریک'),
                  subtitle: Text(lock.biometricAvailable ? 'اثر انگشت یا چهره ثبت‌شده دستگاه'
                    : 'بیومتریک در دستگاه در دسترس نیست؛ PIN همچنان فعال است.'),
                  value: lock.biometricEnabled,
                  onChanged: _working || _securityWorking ||
                    (!lock.biometricAvailable && !lock.biometricEnabled) ? null : _changeBiometrics),
                ListTile(leading: const Icon(Icons.timer_outlined),
                  title: const Text('زمان قفل خودکار'),
                  subtitle: const Text('پس از خروج از برنامه'),
                  trailing: DropdownButton<int>(value: lock.timeoutMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('فوری')),
                      DropdownMenuItem(value: 1, child: Text('۱ دقیقه')),
                      DropdownMenuItem(value: 5, child: Text('۵ دقیقه')),
                    ],
                    onChanged: _working || _securityWorking ? null : (value) {
                      if (value != null) _changeSecurity(() => lock.setTimeout(value));
                    })),
                SwitchListTile(secondary: const Icon(Icons.screenshot_monitor_outlined),
                  title: const Text('جلوگیری از تصویربرداری صفحه'),
                  subtitle: const Text('محافظت از اسکرین‌شات و پیش‌نمایش برنامه‌های اخیر'),
                  value: lock.secureScreen,
                  onChanged: _working || _securityWorking ? null : (value) =>
                    _changeSecurity(() => lock.setSecureScreen(value))),
                ListTile(leading: const Icon(Icons.lock_clock_outlined),
                  title: const Text('همین حالا قفل کن'),
                  enabled: !_working && !_securityWorking,
                  onTap: lock.lock),
              ],
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
            child: Center(child: Card(child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(value: _maintenanceProgress),
                const SizedBox(height: 14),
                Text(_maintenanceLabel ?? 'در حال پردازش اطلاعات...', textAlign: TextAlign.center),
                if (_maintenanceProgress != null) ...[
                  const SizedBox(height: 6),
                  Text(JalaliFormatter.toPersianDigits('${(_maintenanceProgress! * 100).round()}٪')),
                ],
              ]),
            ))),
          )),
        ]),
      ),
    );
  }
}
