# Push notifications (FCM)

ProTourney sends push via **Firebase Cloud Messaging (HTTP v1)**. It's fully
optional: with no Firebase configured the app still runs and shows **in-app**
notifications (the bell + Notifications screen) and dispute **emails** — push
just stays off until you enable it.

## How it works

- The app registers each device's FCM token in `device_tokens` (per user) once
  push is available on the device (`app/lib/core/push_service.dart`).
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
and `lib/firebase_options.dart`. Then have `main()` initialize Firebase with
those options (see the guarded hook in `push_service.dart`; swap the bare
`Firebase.initializeApp()` for `Firebase.initializeApp(options:
DefaultFirebaseOptions.currentPlatform)`).

> Until you run this, `PushService` is a safe no-op — the app builds and runs
> without Firebase.

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
