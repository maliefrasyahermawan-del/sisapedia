# SisaPedia

Flutter mobile app for an auditable waste pickup lifecycle in Semarang. Android is the competition target; iOS remains supported by the shared Flutter codebase.

## Run the offline competition build

Preview Mode is the default and stores submissions, points, selected role, and reset state on-device. No network, map tiles, SMS, or backend account is required.

```bash
flutter pub get
flutter run
# Explicit preview APK build (Sari tries OmniRoute, then uses local demo data):
flutter build apk --release --dart-define=PREVIEW_MODE=true \
  --dart-define=OMNIROUTE_APP_SECRET=YOUR_APP_SECRET
# Optional endpoint/model overrides (the defaults are the current ephemeral
# trycloudflare URL and antigravity/gemini-3.6-flash-high):
# --dart-define=OMNIROUTE_BASE_URL=https://your-router.example/v1/chat/completions
# --dart-define=OMNIROUTE_MODEL=your-model
```

Use **Masuk sebagai Akun Testing**, then the in-app role switcher to demonstrate Sumber, Pengolah, DLH, and Admin. Preview OTP is `246810`. Reset restores deterministic Semarang identities (Bu Siti/Pasar Sampangan, Pak Bambang/Bank Sampahku Berkahmu, DLH, Admin), organic/inorganic submissions, offers, evidence, ledger, redeem, notifications, and audit state. Matching remains available through the wilayah list when maps cannot load.

## Supabase normal mode

Credentials are runtime-only dart-defines; never commit them or service-role keys.
For a preview build, `OMNIROUTE_APP_SECRET` is optional and compile-time only. If it
is missing, expired, or the endpoint cannot be reached, Sari remains usable via
the deterministic local fallback. `OMNIROUTE_BASE_URL` and `OMNIROUTE_MODEL`
override the documented preview defaults. The Gatekeeper request uses the
`X-App-Secret` header; the trycloudflare URL is ephemeral.

```bash
flutter run --dart-define=PREVIEW_MODE=false \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=publishable-key
```

Apply the versioned migrations in order (`202608230001_initial.sql` through `202608230011_batch_d_acceptance.sql`) and `supabase/seed.sql`. Provision DLH/Admin profiles server-side with the service-role bootstrap procedure; public metadata can only create Sumber/Pengolah. A trusted operator runs `select public.provision_privileged_profile('USER_UUID'::uuid, 'admin'::public.app_role, 'Admin Name', 'admin@example.invalid');` from a service-role SQL session (or a `postgres` migration session); the function is not executable by `anon` or `authenticated`. Processor applications require a facility latitude/longitude and evidence object, and operational availability uses narrow RPCs; direct authenticated processor table writes are revoked. Deploy `supabase/functions/sari-proxy` with backend-only `NINJA_API_KEY`, `ROUTER_BASE_URL`, and `ROUTER_MODEL` secrets. Sari responses are schema-validated, require an authenticated Sumber role and a per-user rate limit, and require user confirmation; Preview uses a deterministic local fallback.

The security migrations separate precise locations, protect processor review and role fields, expose only aggregate `dlh_city_metrics`, and install participant-based Storage policies. Use `supabase/storage_policies.sql` only when bootstrapping an older project. Deploy `supabase/functions/retention-cleanup` as a scheduled job with `RETENTION_CRON_SECRET`, then POST its endpoint daily; the database RPC claims a durable deletion outbox item and the Edge Function acknowledges success or leaves failures retryable before relational paths are cleared. DLH requests an explicit completion month (defaulting to the current month). `supabase/tests/rls_assertions.sql` is an executable pgTAP checklist for a disposable local database. `upsert_processor_application` is the only normal-mode processor profile write and phone linking uses Supabase `updateUser` plus `phoneChange` OTP.

Supabase reserves ownership of `storage.objects` for `supabase_storage_admin`. The
forward migration contains an owner-session ACL block; when a deployment runner
cannot assume that reserved role, run the equivalent revoke/grant statements in
an owner session before the RLS checklist (the local CLI database uses this
reserved-role boundary):

```sql
revoke truncate, references, trigger on table storage.objects from anon, authenticated;
revoke all on table storage.objects from anon, authenticated;
grant select, insert, update, delete on table storage.objects to authenticated;
```

## Architecture

`lib/data/models` defines the shared transaction/points contracts. `Supabase` repositories use RLS, Realtime streams, and privileged SQL transitions. `core/preview` uses the same repository interfaces backed by `SharedPreferences`, making restart persistence and offline behavior testable. `features/roles` provides role-specific mobile navigation; existing Sumber flows remain reachable through the canonical routes.

The state machine is `submitted → matching → offered → accepted → en_route → weighed → completed`, with audited expiry, rejection, cancellation, and dispute branches. Matching weights and point rate are stored/versioned in the database. Precise source location is not exposed until offer acceptance.

The mobile bundle includes the OFL-licensed Red Hat Display and Red Hat Text
variable fonts in `assets/fonts/`, so the competition APK does not fetch fonts
at runtime.

Pengolah can create and submit article/event drafts; Admin moderation changes
their status to approved or rejected with an audited reason. Sari extraction is
editable and hands off category, subtype, and weight into the location-complete
manual submission form; pickup window and precise location remain explicit user
confirmation steps.

## Verification

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --release --dart-define=PREVIEW_MODE=true
```

Android release builds require JDK 17 and the Android SDK. Release signing never falls back to the debug key: create ignored `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword) or set `ANDROID_KEYSTORE_FILE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` before `flutter build apk --release`. Run `flutter doctor --verbose` to confirm the selected JDK before building. If Supabase CLI is unavailable, validate SQL using PostgreSQL CI; never point tests at production. `.env.example` contains placeholders only.
