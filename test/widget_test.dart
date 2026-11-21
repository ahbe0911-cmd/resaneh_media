import 'package:flutter_test/flutter_test.dart';
import 'package:resaneh_media/core/utils/persian_normalizer.dart';
import 'package:resaneh_media/core/utils/file_classifier.dart';

void main() {
  test('Persian normalizer normalizes Arabic Yeh, Kaf and digits', () {
    expect(PersianNormalizer.normalize('يارانه كالا ۱۴۰۵'), 'یارانه کالا 1405');
    expect(PersianNormalizer.compact('ثبت‌نام'), PersianNormalizer.compact('ثبت نام'));
  });
  test('classifies files without reading file bodies', () {
    expect(
      FileClassifier.classify(mimeType: 'application/pdf', extension: '.pdf'),
      MediaFileType.pdf,
    );
  });
}
