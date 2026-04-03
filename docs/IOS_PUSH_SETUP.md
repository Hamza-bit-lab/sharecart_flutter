# iOS push notifications (FCM) — required setup

The Flutter app uses **Firebase Cloud Messaging**. Android works after `google-services.json`. **iOS needs extra steps** or pushes will not arrive.

## 1. Add `GoogleService-Info.plist`

1. Open [Firebase Console](https://console.firebase.google.com) → your project → **Project settings**.
2. Under **Your apps**, add an **iOS** app if missing (bundle ID must match Xcode, e.g. `com.example.sharecart` or your real ID).
3. Download **`GoogleService-Info.plist`**.
4. In Xcode: drag the file into **`ios/Runner/`**, enable **Copy items if needed**, and add to **Runner** target.

> This repo may not ship the plist (secrets). Each developer must add their own.

## 2. Xcode capabilities

Open **`ios/Runner.xcworkspace`** in Xcode → select **Runner** target:

- **Signing & Capabilities** → **+ Capability**:
  - **Push Notifications**
  - **Background Modes** → enable **Remote notifications** (if you need data messages in background).

## 3. APNs key in Firebase

1. [Apple Developer](https://developer.apple.com) → **Keys** → create a key with **Apple Push Notifications service (APNs)**.
2. Firebase Console → Project settings → **Cloud Messaging** → **Apple app configuration** → upload the **APNs Authentication Key** (.p8) and enter **Key ID**, **Team ID**, **Bundle ID**.

Without this, FCM cannot deliver to iOS devices.

## 4. Foreground banners

The app uses `firebase_messaging` + `flutter_local_notifications` with **Darwin** settings so foreground alerts can show. System notification permission must be **allowed** when the OS prompts.

## 5. Simulator vs device

**iOS Simulator does not receive real remote push.** Test on a **physical iPhone**.

## Checklist

| Step | Done? |
|------|--------|
| `GoogleService-Info.plist` in `ios/Runner/` | ☐ |
| Push Notifications capability | ☐ |
| APNs key (.p8) uploaded to Firebase | ☐ |
| Physical device test | ☐ |
