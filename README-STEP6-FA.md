# گام ششم (نهایی) — رسانه کتابخانه / رسانه کافی‌نت

> این ZIP پچ مرحله ششم است، نه APK. محتویات آن را روی پروژه `resaneh_media` ساخته‌شده در گام‌های ۱ تا ۵ استخراج کنید. اگر سورس کامل یک‌جا نیاز دارید از فایل `Resaneh-Source-Bundle.zip` استفاده کنید.

## چیزهایی که اضافه یا اصلاح شدند

- ۲ آیکون PNG اختصاصی در `assets/icons/` و دو foreground مخصوص آیکون‌های Adaptive.
- ۲ تصویر Splash مخصوص دو Flavor در `assets/splash/`.
- پیکربندی جداگانه آیکون با `flutter_launcher_icons-{ketabkhaneh,kafinet}.yaml`.
- پیکربندی جداگانه Splash با `flutter_native_splash-{ketabkhaneh,kafinet}.yaml`.
- تنظیم Android SDK 36 / minSdk 24 / Java 17 / Gradle 9.5 / AGP 9.3.1.
- فایل `android/app/build.gradle.kts` با Flavor و Release signing جدا از کد برنامه.
- فایل `.github/workflows/build_apks.yml` برای ساخت دو APK امضاشده و آپلود جداگانه در Artifacts.
- اسکریپت `scripts/ensure_brand_assets.py` که اگر PNG حذف شود، بدون نیاز به Pillow یک تصویر پایه قابل بیلد می‌سازد.
- اسکریپت `scripts/fetch_fonts.sh` برای دریافت مستقیم و محلی دو وزن فونت از مخزن رسمی Vazirmatn؛ **فایل فونت در بسته منتشر نشده است**.

## سازگاری Flutter/AGP

این نسخه برای Flutter 3.50.1 Stable طراحی شده است. برای سازگاری با پلاگین‌های جامعه Flutter که هنوز به AGP 9 Built-in Kotlin مهاجرت نکرده‌اند، تا هنگام آزمایش واقعی، `android.builtInKotlin=false` و `android.newDsl=false` با Kotlin Gradle Plugin 2.4.20 استفاده شده‌اند. حذف این دو گزینه بدون آزمایش ممکن است بیلد را بشکند.

## اجرای محلی

در پوشه اصلی Flutter:

```bash
flutter create --platforms=android --android-language kotlin --org com.resaneh --project-name resaneh_media .
bash scripts/fetch_fonts.sh
python3 scripts/ensure_brand_assets.py
flutter pub get
dart run flutter_launcher_icons -f flutter_launcher_icons-ketabkhaneh.yaml
dart run flutter_launcher_icons -f flutter_launcher_icons-kafinet.yaml
dart run flutter_native_splash:create --all-flavors
flutter analyze
flutter test
flutter build apk --release --flavor ketabkhaneh -t lib/main_ketabkhaneh.dart
flutter build apk --release --flavor kafinet -t lib/main_kafinet.dart
```

فایل‌های Flutter در `build/app/outputs/flutter-apk/` ساخته می‌شوند. **اگر `android/key.properties` وجود نداشته باشد، بیلد محلی Release با Debug key امضا می‌شود و مناسب انتشار تجاری نیست**.

## ساخت پروژه در GitHub

1. یک مخزن **Private** بسازید، مثلاً `resaneh_media`.
2. سورس کامل پروژه را (نه خود فایل ZIP و نه کلیدهای خصوصی) داخل مخزن قرار دهید؛ پوشه `.github/workflows` باید دقیقاً در ریشه باشد.
3. Commit و Push به شاخه `main` را انجام دهید. یا در بخش GitHub Actions روی `Build Resaneh Android APKs` سپس `Run workflow` بزنید.
4. اجرا در Ubuntu با JDK 17 و Flutter 3.50.1 شروع می‌شود؛ فایل‌های فونت از منبع رسمی دریافت و آیکون و Splash هر دو Flavor تولید می‌شوند.
5. بعد از سبز شدن اجرا، در پایین همان Run بخش Artifacts را باز کنید و این دو مورد را دریافت کنید:
   - `Resaneh-Ketabkhaneh` → `Resaneh-Ketabkhaneh.apk`
   - `Resaneh-Kafinet` → `Resaneh-Kafinet.apk`
   - `Resaneh-Checksums` → `SHA256SUMS.txt`

## امضای قابل ارتقا (بسیار مهم)

در نخستین اجرا اگر هیچ Secret امضا تنظیم نشده باشد، Workflow یک keystore تصادفی JKS می‌سازد و دو APK قابل نصب می‌دهد. **این کلید موقت حفظ نمی‌شود؛ APK حاصل را نمی‌توان با APK اجرای بعدی روی همان برنامه به‌روزرسانی کرد.**

برای نصب به‌روزرسانی بدون حذف داده‌ها، باید **پیش از نخستین انتشار واقعی** یک keystore پایدار بسازید و آن را خارج از GitHub در محل امن نسخه‌پشتیبان نگه دارید:

```bash
keytool -genkeypair -v \
  -keystore resaneh-release.jks \
  -storetype JKS \
  -keyalg RSA -keysize 3072 -validity 10000 \
  -alias resaneh \
  -dname "CN=Resaneh, OU=Android, O=Resaneh, L=Baku, ST=Baku, C=AZ"
```

در اجرای دستور بالا، Java رمز مخزن و رمز کلید را می‌پرسد. رمزها را امن نگه دارید. سپس در GitHub: **Settings → Secrets and variables → Actions → New repository secret** چهار Secret زیر را تعریف کنید:

- `RESANEH_KEYSTORE_BASE64`: محتوای base64 فایل `resaneh-release.jks` (فقط رشته خام base64).
- `RESANEH_STORE_PASSWORD`: رمز keystore.
- `RESANEH_KEY_PASSWORD`: رمز کلید.
- `RESANEH_KEY_ALIAS`: در این مثال `resaneh`.

محاسبه Base64:

Linux: `base64 -w0 resaneh-release.jks`

macOS: `base64 < resaneh-release.jks | tr -d '\n'`

PowerShell در Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('resaneh-release.jks'))
```

**هرگز فایل JKS، Base64 یا password را در Git، issue، چت یا log عمومی منتشر نکنید.** داشتن یک کلید امضای مشترک برای دو شناسه اپ متفاوت، به‌خودی‌خود دیتابیس‌ها یا Sandbox آن‌ها را مشترک نمی‌کند.

## نام بسته‌ها و خروجی‌ها

| Flavor | Application ID | APK |
|---|---|---|
| ketabkhaneh | `com.resaneh.ketabkhaneh` | `Resaneh-Ketabkhaneh.apk` |
| kafinet | `com.resaneh.kafinet` | `Resaneh-Kafinet.apk` |

## تشخیص ایرادهای احتمالی

- `No matching variant`: از اجرای `flutter create ... .` و درست بودن `productFlavors` مطمئن شوید.
- `Font asset not found`: اسکریپت `scripts/fetch_fonts.sh` باید اجرا شود. فایل TTF را داخل ZIP نگذارید.
- `Kotlin plugin already applied`: روی AGP 9 فقط یکی از حالت‌های Built-in Kotlin یا KGP قدیمی را انتخاب کنید؛ فایل‌های این بسته حالت دوم را برای سازگاری اعمال می‌کنند.
- `App not installed` در نصب به‌روزرسانی: بررسی کنید `applicationId` و امضای Release با نسخه نصب‌شده یکسان باشند؛ اگر کلید نخستین نصب موقت بوده، برای تغییر امضا معمولاً حذف نسخه قبلی لازم است و **داده‌ها از دست می‌روند**؛ ابتدا ZIP بکاپ بسازید.
- `Artifact not found`: مطمئن شوید هر دو Build و Verify APK موفق بوده‌اند. خروجی‌ها باید در بخش Artifacts همان Run باشند.
- `flutter analyze` یا `flutter test` خطا داشت: فایل‌های خطا را اصلاح کنید. **این سورس در این محیط Flutter SDK/Android SDK واقعی نداشته و بیلد قطعی آن تأیید نشده است**.

## نکات پیش از انتشار

- بکاپ، بازیابی و ریست را با اطلاعات آزمایشی روی دستگاه واقعی بررسی کنید.
- ZIP بکاپ رمزگذاری نشده است؛ PIN صرفاً قفل ورود به برنامه است، نه رمزگذاری Vault.
- برای Google Play معمولاً از فایل AAB استفاده می‌شود؛ این Workflow طبق درخواست فقط APK ایجاد می‌کند.
- قبل از انتشار عمومی، سیاست حریم خصوصی، فرآیند مدیریت داده و تست امنیتی انجام دهید.
