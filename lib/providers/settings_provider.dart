import 'package:flutter/material.dart';

import '../data/repositories/app_settings_repository.dart';

enum ArchiveLayout { list, grid }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required AppSettingsRepository repository}) : _repo = repository;
  final AppSettingsRepository _repo;
  ThemeMode _themeMode = ThemeMode.system;
  ArchiveLayout _layout = ArchiveLayout.list;
  bool _loaded = false;
  bool _busy = false;
  bool _disposed = false;

  ThemeMode get themeMode => _themeMode;
  ArchiveLayout get layout => _layout;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;

  Future<void> initialize() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    final theme = await _repo.get('theme_mode');
    final layout = await _repo.get('archive_layout');
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _layout = layout == 'grid' ? ArchiveLayout.grid : ArchiveLayout.list;
    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    await _repo.put('theme_mode', value.name);
    _themeMode = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> setLayout(ArchiveLayout value) async {
    await _repo.put('archive_layout', value.name);
    _layout = value;
    if (!_disposed) notifyListeners();
  }

  void beginMaintenance() {
    if (_busy) throw StateError('عملیات دیگری در حال اجراست.');
    _busy = true;
    if (!_disposed) notifyListeners();
  }

  void endMaintenance() {
    _busy = false;
    if (!_disposed) notifyListeners();
  }

  void resetToDefaults() {
    _themeMode = ThemeMode.system;
    _layout = ArchiveLayout.list;
    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
