# Resaneh Media — Two independent Flutter Android apps

Two flavors with a shared Flutter codebase:

- **رسانه کتابخانه** — `com.resaneh.ketabkhaneh` — emerald and gold.
- **رسانه کافی‌نت** — `com.resaneh.kafinet` — indigo and cyan.

The repository contains the merged Dart source from the earlier implementation steps, Android configuration, both visual asset sets, and GitHub Actions CI for two independent APKs. Full instructions are in [README-STEP6-FA.md](README-STEP6-FA.md).

## Quick start

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
```

Build both APKs:

```bash
flutter build apk --release --flavor ketabkhaneh -t lib/main_ketabkhaneh.dart
flutter build apk --release --flavor kafinet -t lib/main_kafinet.dart
```

**Status:** Source assembled; Flutter and Android Gradle build execution not yet verified. Configure four signing secrets for stable upgrade keys before real distribution. Fonts are fetched from official upstream and are not included in this archive.
