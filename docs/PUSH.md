# Push notifications (FCM)

ProTourney sends push via **Firebase Cloud Messaging (HTTP v1)**. It's fully
optional: with no Firebase configured the app still runs and shows **in-app**
notifications (the bell + Notifications screen) and dispute **emails** — push
just stays off until you enable it.

## How it works

- The app stores each device's FCM token in `device_tokens` (per user) via
  `PushService.registerToken` (`app/lib/core/push_service.dart`). That DB half
  is ready today; the FCM token that feeds it comes from `firebase_messaging`
  once you configure Firebase (below).
- Every server-created notification (result ready, champion, payout, …) is a
  row in `notifications`. The `resolve-matches` cron picks up rows with
  `pushed_at IS NULL`, sends them via `_shared/push.ts` → FCM, and stamps
  `pushed_at` so each is pushed exactly once.
- `_shared/push.ts` is a **no-op** unless `FIREBASE_SERVICE_ACCOUNT` is set, so
  everything is safe before you configure Firebase.

## Enable it

### 1. Create a Firebase project & wire the client

```bash
cd app
dart pub global activate flutterfire_cli
flutterfire configure         # creates firebase_options.dart + native config
```

`flutterfire configure` adds `android/app/google-services.json`, the web config,
and `lib/firebase_options.dart`, and prompts you to add `firebase_core` +
`firebase_messaging`. Then, after login, initialize messaging and feed the token
to the ready-made hook:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final fm = FirebaseMessaging.instance;
await fm.requestPermission();
final token = await fm.getToken();               // (+ VAPID key on web)
if (token != null) ref.read(pushServiceProvider).registerToken(token);
fm.onTokenRefresh.listen(ref.read(pushServiceProvider).registerToken);
```

> Until you run this, `PushService.registerToken` is simply never called — the
> app builds and runs without Firebase, using in-app notifications + email.

### 2. Give the backend a service account

Firebase Console → Project settings → Service accounts → **Generate new private
key**, then:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
supabase functions deploy resolve-matches --no-verify-jwt
supabase db push        # applies migration 0011 (device_tokens + pushed_at)
```

### 3. Schedule the cron

Ensure `resolve-matches` runs about every minute (Supabase Dashboard → Edge
Functions → Cron, or `pg_cron` + `pg_net`). It already handles auto-resolve and
dispute emails; push fan-out is step 3 of the same pass.

## Notes

- Dead/expired tokens are ignored per-send; a token refresh re-registers via
  `push_service.dart`.
- Web push needs a VAPID key in the Firebase web config (part of
  `flutterfire configure`).
- In-app notifications and dispute emails work regardless of push.
