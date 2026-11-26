import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/utils/file_classifier.dart';
import '../core/utils/archive_sort.dart';
import '../data/models/media_item.dart';
import '../services/vault/vault_service.dart';

class ArchiveProvider extends ChangeNotifier {
  ArchiveProvider({required VaultService vault}) : _vault = vault;
  final VaultService _vault;
  static const int _pageSize = 100;

  final List<MediaItem> _items = [];
  String _query = '';
  MediaFileType? _type;
  ArchiveSort _sort = ArchiveSort.newest;
  String? _tagFilter;
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
  ArchiveSort get sort => _sort;
  String? get tagFilter => _tagFilter;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  Future<void> initialize() => refresh();

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _generation++; // Discard responses to the previous query.
    _debounce?.cancel();
    _clearForNewCriteria();
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh());
    });
  }

  Future<void> setType(MediaFileType? value) async {
    if (value == _type) return;
    _type = value;
    _clearForNewCriteria();
    await refresh();
  }

  Future<void> setSort(ArchiveSort value) async {
    if (value == _sort) return;
    _sort = value;
    _clearForNewCriteria();
    await refresh();
  }

  Future<void> setTagFilter(String? value) async {
    if (_tagFilter == value) return;
    _tagFilter = value;
    _clearForNewCriteria();
    await refresh();
  }

  void _clearForNewCriteria() {
    _items.clear();
    _loading = true;
    _loadingMore = false;
    _hasMore = false;
    _error = null;
  }

  Future<void> refresh({bool preserveWindow = false}) async {
    if (_disposed) return;
    _debounce?.cancel();
    final generation = ++_generation;
    final target = preserveWindow && _items.length > _pageSize ? _items.length : _pageSize;
    _loading = true;
    _loadingMore = false;
    _error = null;
    notifyListeners();
    try {
      final results = <MediaItem>[];
      var more = true;
      while (results.length < target && more) {
        final limit = (target - results.length).clamp(1, 500);
        final page = await _vault.search(query: _query, type: _type,
          sort: _sort, tagFilter: _tagFilter, limit: limit, offset: results.length);
        if (_disposed || generation != _generation) return;
        results.addAll(page);
        more = page.length == limit;
      }
      _items..clear()..addAll(results);
      _hasMore = more;
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
        query: _query, type: _type, sort: _sort, tagFilter: _tagFilter,
        limit: _pageSize, offset: offset,
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
      final generation = _generation;
      final result = await _vault.setPinned(item.id, !item.isPinned);
      if (result) await _afterChange(item.id, generation);
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
      final generation = _generation;
      final changed = await _vault.updateMetadata(
        id: id, title: title, description: description, tags: tags,
      );
      if (changed) await _afterChange(id, generation);
      return changed;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      final generation = _generation;
      final removed = await _vault.deleteItem(id);
      if (removed && !_disposed) {
        if (generation == _generation && !_loading && !_loadingMore &&
            _items.any((item) => item.id == id)) {
          _items.removeWhere((item) => item.id == id);
          _error = null;
          notifyListeners();
        } else {
          await refresh(preserveWindow: true);
        }
      }
      return removed;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<void> _afterChange(String id, int generation) async {
    if (_disposed) return;
    // With pagination or a text/tag query, requery the existing window:
    // a mutation can change membership or move a pinned item across a page boundary.
    if (generation != _generation || _loading || _loadingMore || _hasMore ||
        _query.isNotEmpty || _tagFilter != null || _sort == ArchiveSort.title) {
      await refresh(preserveWindow: true);
      return;
    }
    final updated = await _vault.getById(id);
    if (_disposed) return;
    if (generation != _generation || _loading || _loadingMore) {
      await refresh(preserveWindow: true);
      return;
    }
    final index = _items.indexWhere((item) => item.id == id);
    if (updated == null || index < 0) {
      await refresh(preserveWindow: true);
      return;
    }
    _items[index] = updated;
    _items.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (_sort == ArchiveSort.largest) {
        final size = b.fileSize.compareTo(a.fileSize);
        if (size != 0) return size;
      }
      final ascending = _sort == ArchiveSort.oldest;
      final time = ascending ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt);
      return time != 0 ? time : (ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
    });
    _error = null;
    notifyListeners();
  }

  // Reuse the established vault operations and refresh just once per batch.
  Future<Set<String>> setPinnedBatch(
    Iterable<MediaItem> items, bool pinned,
  ) => _performBatch(items.map((item) => item.id),
      (id) => _vault.setPinned(id, pinned));

  Future<Set<String>> deleteBatch(Iterable<String> ids) =>
      _performBatch(ids, _vault.deleteItem);

  Future<Set<String>> _performBatch(
    Iterable<String> ids, Future<bool> Function(String) operation,
  ) async {
    final completed = <String>{};
    for (final id in ids.toSet()) {
      try {
        if (await operation(id)) completed.add(id);
      } catch (_) {
        // Continue with other files; the UI reports the failed count.
      }
    }
    await refresh(preserveWindow: true);
    return completed;
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
