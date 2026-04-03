# Share Cart

Flutter app for shared grocery / shopping lists: join by code, collaborate, payments, and **Firebase Cloud Messaging** push notifications.

## Project layout

```
lib/
  main.dart                 # App entry, deep links, FCM listeners
  screens/                  # UI screens (lists, detail, auth, settings, …)
  components/               # Reusable widgets (nav, language switcher)
  controllers/              # GetX (e.g. language)
  services/
    auth_service.dart       # API + auth + lists + FCM token registration
    push_notification_service.dart  # Local notifications (Android + iOS) + background handler
    fcm_service.dart        # Thin helper: FCM device token
    api_config.dart         # Base API URL (change per environment)
  translations/             # GetX strings (en + locales)
  theme/                    # AppTheme
  utils/                    # Helpers
```

## Configuration

- **API base URL:** `lib/services/api_config.dart`  
  Use your machine’s LAN IP when testing on a device, e.g. `http://192.168.x.x:8000`, and run Laravel with:
  `php artisan serve --host=0.0.0.0 --port=8000`

## Push notifications

- **Android:** `google-services.json` is under `android/app/`. Channels are configured in code + manifest.
- **iOS:** See **[docs/IOS_PUSH_SETUP.md](docs/IOS_PUSH_SETUP.md)** (`GoogleService-Info.plist`, Push capability, APNs in Firebase).

## Backend prompts (Laravel)

See **`docs/`** — e.g. `BACKEND_FCM_UPDATED_PROMPT.md`, `BACKEND_JOIN_BY_CODE_LOGGED_IN_PROMPT.md`, payments, settlement, claim item, etc.

## Getting started

```bash
flutter pub get
flutter run
```

For platform-specific setup, see [Flutter documentation](https://docs.flutter.dev/).
