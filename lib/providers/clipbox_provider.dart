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
    _query = query;
    ++_generation;
    _debounce?.cancel();
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repo.search(query: _query, limit: _pageSize);
      if (generation != _generation || _disposed) return;
      _items..clear()..addAll(result);
      _hasMore = result.length == _pageSize;
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
    await refresh();
  }

  Future<void> update(ClipEntry entry, String title, String body) async {
    await _repo.update(id: entry.id, title: title, body: body);
    await refresh();
  }

  Future<void> togglePin(ClipEntry entry) async {
    await _repo.setPinned(entry.id, !entry.isPinned);
    await refresh();
  }

  Future<void> remove(ClipEntry entry) async {
    await _repo.delete(entry.id);
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    ++_generation;
    super.dispose();
  }
}
