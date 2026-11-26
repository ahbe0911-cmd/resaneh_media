import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resaneh_media/app/app_theme.dart';
import 'package:resaneh_media/app/flavor_config.dart';
import 'package:resaneh_media/core/utils/archive_sort.dart';
import 'package:resaneh_media/core/utils/file_classifier.dart';
import 'package:resaneh_media/data/models/media_item.dart';
import 'package:resaneh_media/features/archive/widgets/media_item_card.dart';
import 'package:resaneh_media/providers/archive_provider.dart';
import 'package:resaneh_media/services/vault/vault_service.dart';

MediaItem sample(String id) => MediaItem(
  id: id, title: 'فایل آزمایشی', originalName: 'test.jpg',
  storedName: 'test.jpg', relativePath: 'test.jpg', mimeType: 'image/jpeg',
  fileType: MediaFileType.image, fileSize: 2048, description: '',
  searchText: '', searchCompact: '', isPinned: false,
  createdAt: DateTime(2026), updatedAt: DateTime(2026),
);

class FakeVault extends VaultService {
  ArchiveSort lastSort = ArchiveSort.newest;
  int searches = 0;
  @override
  Future<List<MediaItem>> search({String query = '', MediaFileType? type,
    ArchiveSort sort = ArchiveSort.newest, int limit = 100, int offset = 0}) async {
    searches++;
    lastSort = sort;
    return [sample('a'), sample('b')];
  }

  @override
  Future<bool> setPinned(String id, bool pinned) async => id == 'a';

  @override
  Future<bool> deleteItem(String id) async => id == 'a';
}

void main() {
  test('sort is forwarded to the vault and group pin refreshes once', () async {
    final vault = FakeVault();
    final archive = ArchiveProvider(vault: vault);
    await archive.initialize();
    await archive.setSort(ArchiveSort.largest);
    expect(vault.lastSort, ArchiveSort.largest);
    final before = vault.searches;
    final done = await archive.setPinnedBatch(archive.items, true);
    expect(done, {'a'});
    expect(vault.searches, before + 1);
    archive.dispose();
  });

  testWidgets('list card supports long press and selected tap', (tester) async {
    var longPresses = 0;
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(FlavorConfig.ketabkhaneh),
      home: Scaffold(body: MediaItemCard(
        item: sample('a'), thumbnailFile: null, selected: true, selectionMode: true,
        onTap: () => taps++, onLongPress: () => longPresses++,
        onPin: () {}, onShare: () {}, onEdit: () {}, onDelete: () {},
        onDetails: () {},
      )),
    ));
    await tester.longPress(find.text('فایل آزمایشی'));
    await tester.tap(find.text('فایل آزمایشی'));
    expect(longPresses, 1);
    expect(taps, 1);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
