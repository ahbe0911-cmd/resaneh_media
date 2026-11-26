import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resaneh_media/app/app_theme.dart';
import 'package:resaneh_media/app/flavor_config.dart';
import 'package:resaneh_media/app/resaneh_brand_theme.dart';
import 'package:resaneh_media/core/utils/file_classifier.dart';
import 'package:resaneh_media/core/utils/formatters.dart';
import 'package:resaneh_media/data/repositories/app_settings_repository.dart';
import 'package:resaneh_media/providers/settings_provider.dart';

class MemorySettingsRepository extends AppSettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('each flavor has its own light and dark brand tokens', () {
    final library = AppTheme.light(FlavorConfig.ketabkhaneh);
    final cafe = AppTheme.light(FlavorConfig.kafinet);
    final libraryDark = AppTheme.dark(FlavorConfig.ketabkhaneh);
    final cafeDark = AppTheme.dark(FlavorConfig.kafinet);
    expect(library.scaffoldBackgroundColor, const Color(0xFFF8F7F4));
    expect(cafe.scaffoldBackgroundColor, const Color(0xFFF3F6FA));
    expect(libraryDark.scaffoldBackgroundColor, const Color(0xFF0B1412));
    expect(cafeDark.scaffoldBackgroundColor, const Color(0xFF0A101F));
    final a = library.extension<ResanehBrandTheme>()!;
    final b = cafe.extension<ResanehBrandTheme>()!;
    expect(a.cardRadius, 18);
    expect(b.cardRadius, 14);
    expect(a.lerp(b, .5).cardRadius, 16);
    expect(a.mediaColor(MediaFileType.pdf), a.pdfColor);
    expect(FlavorConfig.ketabkhaneh.applicationId, 'com.resaneh.ketabkhaneh');
    expect(FlavorConfig.kafinet.applicationId, 'com.resaneh.kafinet');
  });

  test('file sizes and type labels are consistent and Persian', () {
    expect(Formatters.fileSize(0), '۰ B');
    expect(Formatters.fileSize(1024), '۱.۰ KB');
    expect(Formatters.fileSize(1048576), '۱.۰ MB');
    expect(Formatters.fileSize(1073741824), '۱.۰۰ GB');
    expect(Formatters.typeLabel(MediaFileType.image), 'عکس');
    expect(Formatters.typeLabel(MediaFileType.image, plural: true), 'تصاویر');
  });

  testWidgets('theme selector ignores layout and maintenance notifications',
      (tester) async {
    final settings = SettingsProvider(repository: MemorySettingsRepository());
    var builds = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: Selector<SettingsProvider, ThemeMode>(
          selector: (_, state) => state.themeMode,
          builder: (_, mode, _) {
            builds++;
            return MaterialApp(themeMode: mode, home: const SizedBox());
          },
        ),
      ),
    );
    expect(builds, 1);
    await settings.setLayout(ArchiveLayout.grid);
    await tester.pump();
    settings.beginMaintenance();
    await tester.pump();
    settings.endMaintenance();
    await tester.pump();
    expect(builds, 1);
    await settings.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(builds, 2);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
