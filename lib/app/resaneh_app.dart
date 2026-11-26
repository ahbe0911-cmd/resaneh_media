import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/clip_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../features/shell/app_shell_page.dart';
import '../features/security/app_lock_gate.dart';
import '../providers/app_lock_controller.dart';
import '../providers/archive_provider.dart';
import '../providers/clipbox_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup/backup_service.dart';
import '../services/import/incoming_file_service.dart';
import '../services/security/app_lock_service.dart';
import '../services/sharing/media_action_service.dart';
import '../services/storage/factory_reset_service.dart';
import '../services/storage/storage_analyzer.dart';
import '../services/storage/vault_maintenance_service.dart';
import '../services/vault/vault_service.dart';
import 'app_theme.dart';
import 'flavor_config.dart';

class ResanehApp extends StatelessWidget {
  const ResanehApp({super.key, required this.config});
  final FlavorConfig config;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<VaultService>(create: (_) => VaultService()),
      Provider<IncomingFileService>(create: (_) => IncomingFileService()),
      Provider<MediaActionService>(create: (_) => MediaActionService()),
      Provider<TagRepository>(create: (_) => TagRepository()),
      Provider<ClipRepository>(create: (_) => ClipRepository()),
      Provider<AppSettingsRepository>(create: (_) => AppSettingsRepository()),
      Provider<AppLockService>(create: (_) => AppLockService()),
      Provider<BackupService>(create: (_) => BackupService()),
      Provider<StorageAnalyzer>(create: (_) => StorageAnalyzer()),
      Provider<VaultMaintenanceService>(create: (_) => VaultMaintenanceService()),
      Provider<FactoryResetService>(create: (ctx) => FactoryResetService(
        lockService: ctx.read<AppLockService>(),
        incomingFileService: ctx.read<IncomingFileService>(),
      )),
      ChangeNotifierProvider<ArchiveProvider>(
        create: (ctx) => ArchiveProvider(vault: ctx.read<VaultService>()),
      ),
      ChangeNotifierProvider<ClipboxProvider>(
        create: (ctx) => ClipboxProvider(repository: ctx.read<ClipRepository>()),
      ),
      ChangeNotifierProvider<SettingsProvider>(
        create: (ctx) => SettingsProvider(
          repository: ctx.read<AppSettingsRepository>(),
        )..initialize(),
      ),
      ChangeNotifierProvider<AppLockController>(
        create: (ctx) => AppLockController(service: ctx.read<AppLockService>()),
      ),
    ],
    child: Selector<SettingsProvider, ThemeMode>(
      selector: (_, settings) => settings.themeMode,
      builder: (ctx, themeMode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: config.appName,
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(config),
        darkTheme: AppTheme.dark(config),
        themeMode: themeMode,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: AppLockGate(child: child ?? const SizedBox.shrink()),
        ),
        home: AppShellPage(config: config),
      ),
    ),
  );
}
