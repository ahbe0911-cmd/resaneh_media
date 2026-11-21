import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/utils/file_classifier.dart';
import '../data/models/media_item.dart';
import '../services/vault/vault_service.dart';

class ArchiveProvider extends ChangeNotifier {
  ArchiveProvider({required VaultService vault}) : _vault = vault;
  final VaultService _vault;
  static const int _pageSize = 100;

  final List<MediaItem> _items = [];
  String _query = '';
  MediaFileType? _type;
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;
  int _generation = 0;
  Timer? _debounce;

  List<MediaItem> get items => List.unmodifiable(_items);
  String get query => _query;
  MediaFileType? get selectedType => _type;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  Future<void> initialize() => refresh();

  void setQuery(String value) {
    _query = value;
    _generation++; // Discard responses to the previous query.
    _debounce?.cancel();
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh());
    });
  }

  Future<void> setType(MediaFileType? value) async {
    if (value == _type) return;
    _type = value;
    _debounce?.cancel();
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _loadingMore = false;
    _error = null;
    notifyListeners();
    try {
      final results = await _vault.search(
        query: _query, type: _type, limit: _pageSize, offset: 0,
      );
      if (_disposed || generation != _generation) return;
      _items..clear()..addAll(results);
      _hasMore = results.length == _pageSize;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    final offset = _items.length;
    _loadingMore = true;
    notifyListeners();
    try {
      final results = await _vault.search(
        query: _query, type: _type, limit: _pageSize, offset: offset,
      );
      if (_disposed || generation != _generation) return;
      _items.addAll(results);
      _hasMore = results.length == _pageSize;
      _error = null;
    } catch (error) {
      if (!_disposed && generation == _generation) _error = error.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> setPinned(MediaItem item) async {
    try {
      final result = await _vault.setPinned(item.id, !item.isPinned);
      if (result) await refresh();
      return result;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<bool> updateMetadata({
    required String id,
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    try {
      final changed = await _vault.updateMetadata(
        id: id, title: title, description: description, tags: tags,
      );
      if (changed) await refresh();
      return changed;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      final removed = await _vault.deleteItem(id);
      if (removed) await refresh();
      return removed;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  void _report(Object error) {
    if (_disposed) return;
    _error = error.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }
}
