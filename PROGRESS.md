# SisaPedia implementation status

The current implementation is Supabase-ready and Preview-first. Preview Mode
is the competition path: it persists a versioned local domain snapshot,
reacts through repository streams, and seeds deterministic Semarang identities
(Bu Siti, Pak Bambang, DLH, and Admin) with organic and inorganic examples.

## Delivered

- Four role shells with role-specific navigation and modular screens:
  Sumber, Pengolah, DLH, and Admin.
- Submission lifecycle, deterministic matching, timed offers with fallback,
  pickup/en-route/weighing evidence, confirmation/dispute, capacity, points,
  redeem review, notifications, and audit records in Preview repositories.
- Supabase migrations for role immutability, narrow RPC workflows, RLS,
  aggregate-only DLH metrics, protected precise locations, Storage policies,
  retention cleanup, server-provisioned privileged roles, explicit client read
  grants, processor facility coordinates/evidence, candidate provenance, and
  versioned DLH aggregate components and completion-month filtering.
- Sari chat, insight, and typed/voice waste extraction are OmniRoute
  live-first in Preview Mode, with editable confirmation and deterministic
  local fallback. The client accepts both OpenAI JSON completions and streamed
  SSE delta responses, including fenced/wrapped JSON.
- Android debug and release APKs are verified in the final gate when release
  signing environment variables are present; no keystore is tracked.
- Upstream UI patch `585e746` is included: points-card overlap fix, distinct
  category-card colors, SisaPedia display name, and refreshed Android/iOS icon.

## Verification

From the repository root:

```powershell
& C:\Ez\Tools\flutter\bin\dart.bat format lib test
& C:\Ez\Tools\flutter\bin\flutter.bat analyze
& C:\Ez\Tools\flutter\bin\flutter.bat test
& C:\Ez\Tools\flutter\bin\flutter.bat build apk --debug --dart-define=PREVIEW_MODE=true
```

The current Flutter test suite contains 44 passing tests covering matching,
lifecycle, organic/inorganic end-to-end Preview flows, role authorization,
persistence, reactivity, per-submission candidate IDs/fallback, content
moderation, Sari-to-manual prefill, OmniRoute JSON/SSE parsing and fallback,
migration/DTO contracts, and role navigation widgets.

The disposable local Supabase pgTAP suite contains 54 passing actor/RLS and
schema assertions, including destructive-privilege denial, scoped source
evidence upload/read, and retention outbox contracts. Release signing setup is
documented in README.md; no keystore is tracked.

The jury Preview release was rebuilt after the upstream icon/UI merge at
57.3 MB, passed `flutter analyze`, and passed all 44 Flutter tests. The Kotlin
Gradle Plugin warning from `speech_to_text` is non-fatal for the current demo
build.

## Configuration and operations

Normal mode uses Supabase dart-defines (`SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`). Backend-only router secrets belong in the Sari
Edge Function environment. Apply `supabase/migrations` and the versioned
Storage policies before normal-mode use; provision DLH/Admin accounts
server-side. Deploy the `retention-cleanup` Edge Function daily; it calls
`public.retention_cleanup()` for the 90-day precise-location/evidence policy
and removes returned objects using the Storage API.

Storage ACLs are owner-managed by Supabase's reserved
`supabase_storage_admin`; hosted deployment and the local disposable DB test
must execute the owner-session revoke block before asserting inherited storage
privileges. The deterministic Preview OTP is `246810`; no external credentials
are needed for Preview.

For a jury-only Preview APK, OmniRoute is supplied at build time with
`OMNIROUTE_APP_SECRET`, `OMNIROUTE_BASE_URL`, and `OMNIROUTE_MODEL`. The
Gatekeeper endpoint currently defaults to
`counting-christine-geometry-tricks.trycloudflare.com`. A `trycloudflare.com`
quick-tunnel hostname is ephemeral and must be kept alive or replaced before
the demo; when unreachable, Sari falls back locally.

Generated `android/build`, `supabase/.temp`, and local Supabase branch metadata
are ignored and are not part of the deliverable. Marketplace checkout remains
intentionally out of scope; product and event content is informational/core-flow
only.

Red Hat Display/Text variable fonts are bundled under `assets/fonts/` from the
official Google Fonts repository under the included OFL license. Display
headings use Red Hat Display and body/UI text uses Red Hat Text; both are
packaged offline with the APK.
