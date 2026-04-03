# Backend (Laravel): FCM Push Notifications – Updated Prompt

Use this prompt to implement ya update FCM push notifications in the Laravel backend (OneSignal ki jagah Firebase). Isme heads-up (banner) notifications ka requirement bhi included hai.

---

## 1. Context

- Flutter app **Firebase Cloud Messaging (FCM)** use karti hai.
- Login/register ke baad app device ka **FCM token** backend ko bhejti hai.
- Backend: (1) FCM tokens store kare, (2) in cases mein notification bheje:
  - **User added to list** → us user ko: "{inviter_name} added you to list {list_name}"
  - **Someone added me to their list** → list owner ko: "{user_name} added you to their list {list_name}"
  - **Nudge** → us list ke saare members ko: "{user_name} nudged the list {list_name}"
  - **General announcement** → saare users ko (e.g. "Use the app / create lists")

---

## 2. Database & API

- **Table:** `fcm_tokens` (e.g. `user_id`, `token`, optional `device_id`). Ek user ke multiple tokens ho sakte hain.
- **Endpoint:** `POST /api/fcm-token`
  - Auth: Bearer token required
  - Body: `{ "token": "fcm_device_token_string" }`
  - Action: is user ke liye token upsert karo
  - Response: 200/201, e.g. `{ "message": "Token saved" }`

---

## 3. Firebase Setup

- **Firebase Console:** Project → Project settings → Service accounts → **Generate new private key** → JSON download karo.
- **Laravel:** JSON file safe jagah rakho (e.g. `storage/app/firebase-credentials.json`). Git mein commit mat karo.
- **.env:**  
  `FIREBASE_CREDENTIALS=/full/path/to/that-file.json`
- **config/services.php:** Is path ko Firebase SDK ke liye use karo (e.g. `firebase.credentials`).

---

## 4. Notification Service (FcmService) – Kya bhejna hai

- Package: **kreait/firebase-php** (Firebase Admin SDK).
- Service: FCM tokens, title, body, optional `data` payload le; FCM ko message bheje. Invalid/expired tokens FCM response se hata do.

### 4.1 Heads-up (banner) ke liye zaroori

Notification **banner/heads-up** (Facebook/X jaisa) dikhane ke liye FCM payload mein ye set karo:

| Platform | Key / Setting | Value |
|----------|----------------|--------|
| Android | `android.notification.channel_id` | `high_importance_channel` |
| Android | `android.priority` | `high` |
| General | `notification` block | Hamesha bhejo (title + body), taake system banner dikhaye |

Flutter app pe channel `high_importance_channel` high importance ke sath already create hai; backend ko sirf same id use karni hai.

**kreait/firebase-php example (single token):**

```php
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\AndroidNotification;

$message = CloudMessage::withTarget('token', $deviceToken)
    ->withNotification(Notification::create('Title', 'Body'))
    ->withAndroidConfig(
        AndroidConfig::new()
            ->withPriority('high')
            ->withNotification(
                AndroidNotification::new()->withChannelId('high_importance_channel')
            )
    );
$messaging->send($message);
```

Multicast / batch mein bhejte waqt bhi har message ke liye same `withAndroidConfig(...)` use karo.

---

## 5. Kab notification bhejni hai

- **User A, User B ko list mein add karta hai** → B ke FCM token(s) ko bhejo: "A added you to list …"
- **User B, A ki list mein join karta hai** → A (list owner) ke token(s) ko bhejo: "B added you to their list …"
- **Nudge** → us list ke baaki members ke token(s) ko bhejo: "{name} nudged the list …"
- **General announcement** → artisan command ya admin se saare stored tokens ko bhejo, e.g.  
  `php artisan app:send-general-announcement "Title" "Body"`

---

## 6. Ab kya karna hai (checklist)

Agar FCM pehle se implement hai:

1. **FcmService update karo:** Har FCM message ke saath:
   - `notification` (title, body) bhejo
   - Android: `channel_id` = `high_importance_channel`, `priority` = `high`
2. **.env** mein `FIREBASE_CREDENTIALS` sahi path pe set hai confirm karo
3. **Test:**  
   `php artisan app:send-general-announcement "Test" "Hello"`  
   Device pe notification **heads-up/banner** mein aani chahiye (na ke sirf status bar icon)

Agar abhi implement nahi kiya:

1. `fcm_tokens` table + model + `POST /api/fcm-token` banao
2. kreait/firebase-php install karo, credentials configure karo
3. FcmService banao (send + invalid token cleanup)
4. Upar wale triggers (share, join, nudge, announcement) se FcmService call karo
5. FCM payload hamesha upar wale heads-up settings ke sath bhejo

---

## 7. Summary

- FCM tokens store karo, `POST /api/fcm-token` se app register karegi.
- Notifications Firebase Admin SDK se bhejo; invalid tokens DB se hatao.
- **Heads-up ke liye:** Android payload mein `channel_id` = `high_importance_channel` aur `priority` = `high`, aur `notification` block zaroor bhejo.
