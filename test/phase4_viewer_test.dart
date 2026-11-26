import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resaneh_media/core/utils/file_classifier.dart';
import 'package:resaneh_media/data/models/media_item.dart';
import 'package:resaneh_media/features/viewer/image_viewer_page.dart';
import 'package:resaneh_media/features/viewer/viewer_formatters.dart';

ViewerImage picture(String id) => ViewerImage(
  filePath: '/nonexistent/$id.jpg',
  item: MediaItem(
    id: id, title: 'تصویر $id', originalName: '$id.jpg',
    storedName: '$id.jpg', relativePath: 'vault/$id.jpg',
    mimeType: 'image/jpeg', fileType: MediaFileType.image,
    fileSize: 1024, description: '', searchText: '', searchCompact: '',
    isPinned: false, createdAt: DateTime(2026), updatedAt: DateTime(2026),
  ),
);

void main() {
  test('Persian playback time and seek boundaries', () {
    expect(ViewerFormatters.playbackTime(const Duration(seconds: 65)), '۰۱:۰۵');
    expect(ViewerFormatters.playbackTime(const Duration(seconds: 3661)), '۱:۰۱:۰۱');
    expect(ViewerFormatters.speed(1.5), '۱.۵×');
    expect(ViewerFormatters.clampPosition(const Duration(seconds: -2),
      const Duration(seconds: 10)), Duration.zero);
    expect(ViewerFormatters.clampPosition(const Duration(seconds: 25),
      const Duration(seconds: 10)), const Duration(seconds: 10));
  });

  testWidgets('gallery opens selected image and navigates with arrows', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ImageViewerPage(
      images: [picture('a'), picture('b')], initialIndex: 1,
      onShare: (_) async {}, onTogglePin: (_) async => true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('تصویر b'), findsOneWidget);
    await tester.tap(find.byTooltip('تصویر قبلی'));
    await tester.pumpAndSettle();
    expect(find.text('تصویر a'), findsOneWidget);
    await tester.tap(find.text('سنجاق'));
    await tester.pumpAndSettle();
    expect(find.text('رفع سنجاق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
