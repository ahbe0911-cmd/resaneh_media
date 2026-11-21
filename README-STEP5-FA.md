# رسانه کتابخانه / رسانه کافی‌نت — گام ۵ از ۶

این فایل ZIP **پچ کامل کدهای گام پنجم** است. این ZIP پروژه مستقل Flutter یا APK نیست؛ باید با حفظ مسیرها روی پروژه `resaneh_media` ساخته‌شده در گام‌های ۱ تا ۴ استخراج شود. فایل‌های هم‌نام را جایگزین کنید. کدهای ورودی فایل گام چهارم نیز در پچ حفظ شده‌اند.

## نصب

1. قبل از هر تغییر، از کدهای قبلی و **آرشیو موجود روی گوشی** بکاپ تهیه کنید. در این نسخه هنوز بیلد واقعی و سناریوی بازیابی روی گوشی تأیید نشده است.
2. پوشه‌های `lib`، `android` و فایل `pubspec.yaml` را از ZIP در ریشه پروژه استخراج کنید. فایل‌های `MainActivity.kt` و `lib/app/resaneh_app.dart` و `lib/features/archive/pages/archive_home_page.dart` باید جایگزین شوند.
3. فایل‌های رسمی فونت `assets/fonts/Vazirmatn-Regular.ttf` و `assets/fonts/Vazirmatn-Bold.ttf` باید مطابق گام سوم در پروژه موجود باشند؛ **فایل فونت داخل ZIP قرار نگرفته است**.
4. فایل‌های گام‌های قبلی شامل `AppDatabase`، `DatabaseSchema`، مدل‌های `MediaItem` و `ClipEntry`، `MediaRepository`، `TagRepository`، `ThumbnailService`، `PersianNormalizer`، `FileClassifier`، `JalaliFormatter`، دو `main_*.dart` و `AppTheme` باید باقی بمانند. پچ فقط فایل‌های تغییرکرده و اضافه‌شده را تحویل می‌دهد.
5. دستورها:

```bash
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run --flavor ketabkhaneh -t lib/main_ketabkhaneh.dart
flutter run --flavor kafinet -t lib/main_kafinet.dart
```

در صورت وجود `test/widget_test.dart` پیش‌فرض پروژه Counter باید آن تست را با تست واقعی برنامه جایگزین کنید.

## قابلیت‌ها

- **کلیپ‌باکس**: افزودن/ویرایش/حذف/پین متن، جستجوی عنوان و بدنه با نرمال‌سازی فارسی، ترتیب پین سپس تاریخ جدید به قدیم، کپی یک‌لمسی و Share متنی. دریافت Share متنی از برنامه‌های دیگر به صفحه کلیپ‌باکس متصل است.
- **تنظیمات**: تحلیل حجم آرشیو شامل عکس، ویدیو، PDF، سایر، Thumbnail، دیتابیس و تعداد متن‌های کلیپ‌باکس، همراه با نوار مقایسه حجم.
- **ظاهر**: تم روشن/تاریک/سیستم و لیست/گرید، ذخیره‌شده در جدول `app_settings` SQLite و داخل بکاپ.
- **PIN**: رمز چهاررقمی با SHA-256 PBKDF2، نمک تصادفی و نگهداری verifier در `flutter_secure_storage`؛ محدودیت تلاش ناموفق و قفل هنگام خروج از برنامه. PIN **رمزگذاری فایل‌های Vault نیست**.
- **Backup**: ZIP با `manifest.json` و SHA-256 همه فایل‌ها؛ شامل دیتابیس و کلیپ‌باکس و پوشه‌های `vault` و `thumbnails`. ذخیره ZIP به محل انتخابی Android SAF؛ اطلاعات حجیم کامل در RAM بارگذاری نمی‌شوند.
- **Restore**: انتخاب ZIP از Android SAF، بررسی نسخه و Application ID و Checksum و سلامت SQLite و تطابق فایل‌های ارجاع‌شده؛ سپس جایگزینی داده‌ها با ژورنال بازگشت در صورت قطع عملیات. اجرا شدن Recovery پیش از باز شدن دیتابیس در `app_bootstrap.dart`.
- **Factory Reset**: هشدار اول و تایپ «حذف» در تأیید دوم، حذف داده‌ها، SQLite، Thumbnail، PIN، تنظیمات و فایل‌های موقت.
- **About**: نام واقعی flavor، نسخه و build number از `package_info_plus`.

## نکات امنیتی و عملیاتی

- هر Flavor با Application ID مستقل نصب می‌شود؛ یک فایل بکاپ از `com.resaneh.ketabkhaneh` در `com.resaneh.kafinet` عمداً قابل بازیابی نیست.
- ZIP خروجی **رمزگذاری نشده** است؛ در صورت داشتن اطلاعات حساس، آن را در محل امن نگه دارید. PIN داخل ZIP قرار نمی‌گیرد؛ پس از نصب مجدد روی گوشی جدید PIN را دوباره فعال کنید.
- برای ساخت بکاپ و بازیابی، فضای آزاد کافی لازم است: فایل‌های موقت، کپی پایگاه داده و نسخه استخراج‌شده ممکن است چند برابر حجم فایل ZIP فضا اشغال کنند.
- قبل از استفاده عملیاتی، حتماً سناریوی ساخت بکاپ و بازیابی را ابتدا با اطلاعات آزمایشی روی Android واقعی آزمایش کنید. **ساخت فایل ZIP پچ به معنی تأیید کامپایل Flutter/Gradle نیست**؛ SDK Flutter/Android در محیط آماده‌سازی حاضر وجود نداشت.
- فضای داخلی اپ ایزوله است ولی به‌صورت مستقل رمزگذاری فایل‌به‌فایل نشده است. Android ممکن است هنگام uninstall/clear data آن را از بین ببرد.
- ZIP نامعتبر یا متعلق به Flavor دیگر رد می‌شود؛ شرط «بازیابی موفق» فقط پس از باز شدن دیتابیس و تأیید فایل‌ها اعلام می‌شود.

## فایل‌های مهم مرحله ۵

```text
lib/data/repositories/clip_repository.dart
lib/data/repositories/app_settings_repository.dart
lib/providers/clipbox_provider.dart
lib/providers/settings_provider.dart
lib/providers/app_lock_controller.dart
lib/services/security/app_lock_service.dart
lib/services/backup/backup_service.dart
lib/services/backup/backup_documents_channel.dart
lib/services/storage/storage_analyzer.dart
lib/services/storage/factory_reset_service.dart
lib/features/clipbox/pages/clipbox_page.dart
lib/features/clipbox/widgets/clip_editor_sheet.dart
lib/features/security/app_lock_gate.dart
lib/features/settings/pages/settings_page.dart
lib/features/settings/widgets/pin_settings_dialog.dart
lib/features/archive/widgets/media_grid_card.dart
android/app/src/main/kotlin/com/resaneh/mediahub/BackupDocumentsChannel.kt
android/app/src/main/kotlin/com/resaneh/mediahub/MainActivity.kt
```

## گام بعدی

گام ۶ مربوط به آیکون و Splash مستقل برای دو Flavor، امضای Release پایدار، Workflow دو بیلد APK در GitHub Actions و راهنمای آپلود و دریافت فایل‌های خروجی است.
