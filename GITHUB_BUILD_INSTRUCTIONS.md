# GitHub APK Build (OleksandrMedia)

## 1) Що вже налаштовано
- Flutter мобільний застосунок: `oleksandr_media_mobile`
- Google OAuth Client ID: `1034187669203-7ssee2rn0ldvhv1c6q7pmrkckj9evvd6.apps.googleusercontent.com`
- Локальне зашифроване сховище: Hive + AES ключ у `flutter_secure_storage`
- CI збірка APK на GitHub Actions: `.github/workflows/android-apk.yml`

## 2) Як запустити збірку одразу на GitHub
Виконай у папці проєкту:

```powershell
git init
git add .
git commit -m "Init Flutter app with Google OAuth + encrypted local storage + APK workflow"
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO>.git
git push -u origin main
```

Після `git push` workflow стартує автоматично.

## 3) Де взяти APK і SHA-1
GitHub -> твій репозиторій -> `Actions` -> workflow `Android APK Build` -> останній run -> `Artifacts`:
- `app-release.apk`
- `sha1.txt`

## 4) Налаштування Google OAuth для Android
У Google Cloud Console (`APIs & Services -> Credentials`) створи **OAuth client ID** типу **Android**:
- Package name: `com.oleksandrmedia.oleksandr_media_mobile`
- SHA-1: значення з `sha1.txt`

Після цього Google login у APK буде валідний для цього підпису.

## 5) Важливо
- Поточний `release` APK підписується debug-ключем (стандарт Flutter шаблону).
- Для production треба окремий release keystore і його SHA-1, а потім оновити Android OAuth credential.
