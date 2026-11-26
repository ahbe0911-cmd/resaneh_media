import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/models/clip_entry.dart';
import '../data/repositories/clip_repository.dart';

class ClipboxProvider extends ChangeNotifier {
  ClipboxProvider({required ClipRepository repository}) : _repo = repository;
  final ClipRepository _repo;
  static const _pageSize = 100;
  final List<ClipEntry> _items = [];
  String _query = '';
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;
  int _generation = 0;
  Timer? _debounce;

  List<ClipEntry> get items => List.unmodifiable(_items);
  String? get error => _error;
  String get query => _query;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    ++_generation;
    _items.clear();
    _loading = true;
    _loadingMore = false;
    _hasMore = false;
    _error = null;
    _debounce?.cancel();
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(refresh());
    });
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
      final result = <ClipEntry>[];
      var more = true;
      while (result.length < target && more) {
        final limit = (target - result.length).clamp(1, 500);
        final page = await _repo.search(query: _query, limit: limit, offset: result.length);
        if (generation != _generation || _disposed) return;
        result.addAll(page);
        more = page.length == limit;
      }
      _items..clear()..addAll(result);
      _hasMore = more;
    } catch (error) {
      if (generation == _generation && !_disposed) _error = '$error';
    } finally {
      if (generation == _generation && !_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final rows = await _repo.search(
          query: _query, limit: _pageSize, offset: _items.length);
      if (_disposed || generation != _generation) return;
      _items.addAll(rows);
      _hasMore = rows.length == _pageSize;
    } catch (error) {
      if (!_disposed && generation == _generation) _error = '$error';
    } finally {
      if (!_disposed && generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> add(String title, String body) async {
    await _repo.add(title: title, body: body);
    await refresh(preserveWindow: true);
  }

  Future<void> update(ClipEntry entry, String title, String body) async {
    final generation = _generation;
    if (!await _repo.update(id: entry.id, title: title, body: body)) {
      throw StateError('متن پیدا نشد');
    }
    await _afterChange(entry.id, generation);
  }

  Future<void> togglePin(ClipEntry entry) async {
    final generation = _generation;
    if (!await _repo.setPinned(entry.id, !entry.isPinned)) {
      throw StateError('متن پیدا نشد');
    }
    await _afterChange(entry.id, generation);
  }

  Future<void> remove(ClipEntry entry) async {
    final generation = _generation;
    if (!await _repo.delete(entry.id)) throw StateError('متن پیدا نشد');
    if (_disposed) return;
    if (generation == _generation && !_loading && !_loadingMore &&
        _items.any((item) => item.id == entry.id)) {
      _items.removeWhere((item) => item.id == entry.id);
      _error = null;
      notifyListeners();
    } else {
      await refresh(preserveWindow: true);
    }
  }

  Future<void> _afterChange(String id, int generation) async {
    if (_disposed) return;
    if (generation != _generation || _loading || _loadingMore ||
        _hasMore || _query.isNotEmpty) {
      await refresh(preserveWindow: true);
      return;
    }
    final updated = await _repo.getById(id);
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
      final time = b.createdAt.compareTo(a.createdAt);
      return time != 0 ? time : b.id.compareTo(a.id);
    });
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    ++_generation;
    super.dispose();
  }
}
