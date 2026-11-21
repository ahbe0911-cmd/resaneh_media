# Resaneh Media — رسانه کتابخانه و رسانه کافی‌نت

Flutter Android project for two independent application flavors:

- `ketabkhaneh`: `com.resaneh.ketabkhaneh`
- `kafinet`: `com.resaneh.kafinet`

## وضعیت مخزن

مخزن ایجاد شده است. **سورس پروژه هنوز به آن بارگذاری نشده است.** پیش از اجرای GitHub Actions باید محتوای فایل `Resaneh-Source-Bundle.zip` در ریشه مخزن استخراج و Commit شود. پوشه `.github` باید همراه سایر فایل‌ها حفظ شود.

پس از آپلود، این فایل‌ها را بررسی کنید:
- `pubspec.yaml`
- `lib/main_ketabkhaneh.dart`
- `lib/main_kafinet.dart`
- `.github/workflows/build_apks.yml`

سپس از بخش Actions گردش‌کار **Build Resaneh Android APKs** را اجرا کنید.

> برای انتشار و نصب آپدیت‌ها از کلید امضای ثابت و GitHub Secrets استفاده کنید. کلیدهای خصوصی یا فایل `key.properties` را به مخزن ارسال نکنید.

## هدف خروجی

- `Resaneh-Ketabkhaneh.apk`
- `Resaneh-Kafinet.apk`

این پروژه هنوز بیلد و تست نصب تأییدشده ندارد.
