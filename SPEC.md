# SisaPedia Full Mobile Application Specification

Status: Ready for implementation  
Target platform: Flutter mobile (Android first, iOS compatible)  
Operational city: Semarang  
Backend: Supabase  

## Problem Statement

SisaPedia currently demonstrates only the Sumber experience and relies on Firebase-oriented repositories plus in-memory preview data. It does not yet deliver the product promised by the proposal and design references: a complete mobile marketplace in which Sumber, Pengolah, DLH, and Admin participate in one auditable organic and inorganic waste flow.

Users need a trustworthy path from waste recording to processor matching, pickup, verified weighing, points, and measurable city impact. The competition build must work predictably without network access, while the normal build must use a secure Supabase backend with role enforcement at the database boundary. The visual implementation must preserve the approved SisaPedia identity while improving consistency, accessibility, offline behavior, and non-happy-path states.

## Solution

Build one polished Flutter mobile application with role-specific navigation and a shared transaction domain. Sumber records waste manually or through Sari, receives three explainable processor candidates, selects one, and follows pickup through completion. Pengolah manages capacity, accepts offers, performs pickup, records actual weight, and uploads weighing evidence. Sumber confirms the final weight or opens a dispute. Admin approves Pengolah accounts, resolves disputes, handles redeem requests, and inspects audit history. DLH sees read-only, aggregated, versioned city-impact metrics.

The normal application uses Supabase Auth, PostgreSQL with Row Level Security, Storage, Realtime, and Edge Functions. The competition APK defaults to a persistent Preview Mode that implements the same repository contracts and full lifecycle locally, includes role switching and deterministic demo controls, and remains usable offline. Sari uses a 9Router-backed OpenAI-compatible API through an Edge Function, with structured output validation and an offline fallback for the demo build.

## User Stories

1. As a guest, I want to explore public SisaPedia content, so that I can understand the product before registering.
2. As a guest, I want protected actions to explain why registration is required, so that I am not silently blocked.
3. As a user, I want to register with email and password, so that I can access my role securely.
4. As a user, I want to sign in with phone OTP, so that I can authenticate without remembering a password.
5. As a user, I want to link email and phone credentials explicitly, so that both credentials open the same account.
6. As a user, I want one immutable primary role, so that my navigation and permissions are predictable.
7. As a Sumber, I want to enter my identity and pickup location, so that a processor can collect my waste.
8. As a Sumber, I want my precise address hidden before an offer is accepted, so that my privacy is protected.
9. As a Sumber, I want to correct my pickup pin manually, so that inconsistent address data does not prevent collection.
10. As a Sumber, I want to record organic waste manually, so that I can request a pickup without AI.
11. As a Sumber, I want to record plastic, paper, or metal manually, so that high-value inorganic waste enters the correct branch.
12. As a Sumber, I want to specify subtype, estimated weight, pickup window, and optional photo, so that matching has useful inputs.
13. As a Sumber, I want to speak a natural Indonesian description, so that recording takes little effort.
14. As a Sumber, I want Sari to return structured category, subtype, weight, and confidence, so that the app can validate the result.
15. As a Sumber, I want Sari to ask for clarification when confidence is low, so that it does not invent transaction data.
16. As a Sumber, I want to confirm every AI-extracted field, so that no transaction is submitted automatically.
17. As a Sumber, I want three ranked compatible processors, so that the algorithm helps without removing my choice.
18. As a Sumber, I want to see a score explanation, approximate distance, capacity, material compatibility, and pickup constraints, so that I can make an informed choice.
19. As a Sumber, I want to select one candidate, so that only the selected Pengolah receives the first offer.
20. As a Sumber, I want an expired or rejected offer to continue to the next candidate, so that I do not restart the submission.
21. As a Sumber, I want to cancel before acceptance freely, so that I retain control over uncommitted submissions.
22. As a Sumber, I want cancellation after acceptance to require a reason, so that the other party receives an auditable explanation.
23. As a Sumber, I want in-app notifications for every material status change, so that I can follow the pickup without push notifications.
24. As a Sumber, I want to see pickup progression, so that I know whether the Pengolah is on the way.
25. As a Sumber, I want to review actual weight and weighing evidence, so that points use verified facts.
26. As a Sumber, I want to confirm the actual weight, so that the transaction can be completed.
27. As a Sumber, I want to dispute an incorrect weight, so that Admin can resolve it.
28. As a Sumber, I want ten points per verified kilogram, so that the reward is simple and understandable.
29. As a Sumber, I want every points change in a ledger, so that my balance is explainable.
30. As a Sumber, I want to see level progress calculated from my balance, so that repeat participation feels meaningful.
31. As a Sumber, I want to request a voucher or demo e-wallet redeem, so that points have visible utility.
32. As a Sumber, I want redeem status history, so that I know whether Admin approved, rejected, or fulfilled it.
33. As a Sumber, I want to read approved articles and join approved events, so that I can participate in local circular activity.
34. As a Pengolah applicant, I want to choose a processor type, so that my operational profile reflects my facility.
35. As a Pengolah applicant, I want to submit materials, capacity, radius, minimum pickup, facility address, and verification evidence, so that Admin can assess me.
36. As a Pengolah applicant, I want a pending-verification screen, so that I understand why matching is unavailable.
37. As a verified Pengolah, I want to update materials, capacity, availability, radius, and minimum pickup, so that offers respect current operations.
38. As a verified Pengolah, I want to receive one time-limited offer, so that I can accept work that is operationally feasible.
39. As a verified Pengolah, I want precise source location only after acceptance, so that private data is disclosed only when needed.
40. As a verified Pengolah, I want to reject an offer with a reason, so that matching can continue and the outcome is audited.
41. As a verified Pengolah, I want to mark myself en route, so that the Sumber receives progress.
42. As a verified Pengolah, I want to record actual weight and upload weighing evidence, so that completion is verifiable.
43. As a verified Pengolah, I want accepted volume to reserve capacity, so that simultaneous offers cannot overbook me.
44. As a verified Pengolah, I want completion or cancellation to update capacity consistently, so that future scores are correct.
45. As a verified Pengolah, I want an operational dashboard, so that I can see waiting offers, pickups, throughput, and capacity.
46. As a verified Pengolah, I want to create event and content drafts, so that Admin can approve community material before publication.
47. As DLH, I want read-only aggregate metrics, so that I can monitor verified diversion without accessing personal details.
48. As DLH, I want organic and inorganic totals separately, so that the two-branch impact is visible.
49. As DLH, I want completed transaction count and active actor count, so that adoption and activity are measurable.
50. As DLH, I want progress against a monthly target, so that performance has context.
51. As DLH, I want each dashboard calculation tied to a baseline and formula version, so that historical numbers are reproducible.
52. As DLH, I want emissions and economic values clearly labeled as estimates, so that projections are not presented as measured facts.
53. As Admin, I want to approve or reject Pengolah applications, so that unverified facilities cannot receive offers.
54. As Admin, I want to resolve weight disputes with evidence and a reason, so that points and impact remain trustworthy.
55. As Admin, I want to approve or reject redeem requests, so that no real-money integration is required.
56. As Admin, I want point deduction to occur only upon redeem approval, so that rejected requests do not reduce balance.
57. As Admin, I want immutable audit events for sensitive operations, so that decisions can be reviewed.
58. As Admin, I want to moderate event and content drafts, so that only approved community content is public.
59. As an owner, I want Admin and DLH accounts provisioned server-side, so that public registration cannot obtain privileged roles.
60. As a judge, I want to switch roles in Preview Mode, so that the entire lifecycle can be demonstrated on one device.
61. As a judge, I want Preview Mode changes to persist across restarts, so that an accidental restart does not erase the demo.
62. As a judge, I want to reset seeded demo data, so that a clean presentation can be restored.
63. As a judge, I want to simulate offer expiry and status progression, so that the demo does not wait for real time.
64. As a judge, I want both organic and inorganic scenarios, so that SisaPedia's central differentiation is proven.
65. As a user, I want matching to remain available through the wilayah list when map tiles fail, so that connectivity does not block the core flow.
66. As a user, I want clear loading, empty, error, offline, and success states, so that the application never appears stuck.
67. As a user, I want Indonesian localization, accessible semantics, scalable text, sufficient contrast, and large touch targets, so that the application is usable by people with varied literacy and ability.
68. As a maintainer, I want Preview and Supabase repositories to honor one domain contract, so that the demo does not drift from production behavior.
69. As a maintainer, I want versioned migrations, seed data, policies, and functions in source control, so that the backend is reproducible.
70. As a maintainer, I want credentials supplied only through environment configuration or backend secrets, so that service credentials never enter the APK or repository.

## Implementation Decisions

- Build one Flutter mobile codebase. Android is the primary submission artifact; iOS compatibility is preserved. No separate web admin application is part of this specification.
- Use the Standalone revision 3 artifact as the canonical screen flow, the interactive App artifact as visual-quality guidance, and the UX Foundation as the arbiter when references conflict.
- Use Red Hat Display for headings and Red Hat Text for body/UI. Bundle fonts locally. Use green for the core brand and organic material, blue for inorganic, amber for pending/matching, and red only for error, dispute, or administrative boundaries.
- Preserve and improve existing Sumber screens; add complete mobile shells for Pengolah, DLH, and Admin.
- Sumber navigation: Beranda, Riwayat, Sari, Poin, Profil. Peta/Wilayah remains reachable from Beranda.
- Pengolah navigation: Dashboard, Permintaan, Pickup, Kapasitas, Profil.
- DLH navigation: Dashboard, Wilayah, Laporan, Profil.
- Admin navigation: Antrean, Transaksi, Redeem, Audit, Profil.
- Replace Firebase completely with Supabase. Do not dual-write or retain a second runtime backend.
- Use Supabase Auth for email/password and phone OTP. Development/demo uses test phone numbers until an SMS provider is supplied.
- One account has one primary role. Sumber and Pengolah register publicly. DLH and Admin are provisioned server-side. Pengolah remains pending until approved.
- Keep guest mode local and read-only. Guest actions requiring identity route to registration.
- Use PostgreSQL tables for cities, profiles, processor profiles, processor materials, submissions, candidates, offers, pickups/transactions, point ledger, redeem requests, notifications, content, events, participation, baselines, formula versions, and audit events.
- Include `city_id` throughout operational and baseline data. Only Semarang is enabled initially.
- Enforce least-privilege Row Level Security for every exposed table and Storage bucket. The publishable key may be used by Flutter; secret/service-role keys never enter Flutter.
- Use Supabase Storage private buckets for processor verification evidence, source photos, and weighing evidence. Signed access follows transaction membership and Admin authority.
- Use Realtime for in-app status and notification refresh in normal mode. Push notifications are out of scope.
- Use Edge Functions or transactional database functions for privileged role provisioning, matching, offer acceptance, capacity reservation, completion, dispute resolution, point awards, redeem approval, retention jobs, and AI proxying.
- Use one explicit transaction state machine: `submitted -> matching -> offered -> accepted -> enRoute -> weighed -> completed`, with `expired`, `rejected`, `cancelled`, and `disputed` branches. Reject invalid transitions.
- Hard matching filters: approved/active processor, accepted material, service radius, available pickup window, sufficient capacity, and minimum pickup compatibility.
- Organic score: material compatibility 0.50, inverse normalized distance 0.30, remaining capacity 0.20.
- Inorganic score: material compatibility 0.40, reference value 0.30, minimum-volume fulfillment 0.30.
- Store normalized component scores and total score. Return the top three candidates.
- Sumber chooses one candidate. The offer lasts 20 minutes. Rejection or expiry advances to the next candidate.
- Before acceptance, Pengolah sees only administrative area and approximate distance. Precise address/coordinates are disclosed after acceptance. DLH never sees individual locations.
- Pickup is performed by Pengolah; no driver role is introduced.
- Sumber may cancel freely before acceptance. Post-acceptance cancellation requires a reason and creates audit and notification records. Rescheduling is out of scope; users create a new pickup.
- Pengolah records actual weight and weighing evidence. Sumber confirms or disputes. Only completed transactions affect points and DLH metrics.
- Award ten points per verified kilogram, rounded to an integer, using an immutable point-ledger entry. Treat the rate as configuration.
- Redeem is administrative only. Requests progress through submitted, approved/rejected, and fulfilled. No real e-wallet or payment integration is included.
- Material payment remains outside SisaPedia. Inorganic reference/final values may be recorded for matching and impact reporting.
- Store baseline and formula versions on completion. Historical calculations remain reproducible even when formulas change.
- Retain precise location and evidence photos for 90 days after completion or dispute resolution, then delete or anonymize them while retaining non-personal transaction/audit facts.
- Preview Mode implements the same domain contracts with local persistence, seeded Semarang actors, role switching, reset controls, and time/status simulation. It defaults on for the competition APK.
- The wilayah list is the offline-safe matching view. The map provides a graceful no-tile fallback and must never block matching.
- Sari is available only to Sumber. Device speech-to-text produces a transcript; a 9Router-backed OpenAI-compatible endpoint returns strict structured JSON for recording. Validate the schema and require user confirmation. Local deterministic behavior remains available for the offline demo.
- Call 9Router only through a Supabase Edge Function. Make base URL and model configurable so OmniRoute remains compatible. Store router credentials as backend secrets.
- Articles, events, and community content remain in scope after the core lifecycle; Pengolah authors drafts and Admin moderates them.
- Improve the application beyond the reference where useful, including micro-interactions and all non-happy-path states, without breaking the canonical flow or brand.
- Use Indonesian UI with centralized strings, `id_ID` formatting, semantic labels, scalable text, minimum 48dp touch targets, AA contrast, and status indicators that do not depend on color alone.

## Testing Decisions

- Test external behavior at the highest stable seam. The principal seam is a complete role-switched lifecycle exercised through the shared repository/domain contract; run it against persistent Preview Mode and the Supabase implementation where credentials are available.
- The second required seam is PostgreSQL authorization. Test RLS with authenticated tokens for Sumber, pending and approved Pengolah, DLH, Admin, unrelated users, and unauthenticated access. A UI-only authorization test is insufficient.
- Unit-test score normalization, hard filters, top-three ordering, point rounding, level derivation, impact formulas, offer expiry, and every valid/invalid transaction transition.
- Test idempotency and concurrency for offer acceptance, capacity reservation, transaction completion, point awarding, dispute resolution, and redeem approval.
- Repository contract tests must run the same behavior cases against Preview and Supabase repositories.
- Widget tests cover email login, OTP screens, role-aware routing, guest gates, submission confirmation, candidate selection, offer handling, weighing, disputes, redeem, dashboard states, accessibility labels, and offline/error states.
- Integration tests cover one full organic scenario and one concise inorganic scenario.
- Preview persistence tests verify restart survival and deterministic reset.
- Storage policy tests verify that precise evidence is restricted to transaction participants and Admin.
- Edge Function tests verify JWT enforcement, structured AI response validation, rate/error handling, and secret non-disclosure.
- Run Flutter formatting, analyzer, unit/widget/integration tests, migration validation, SQL/RLS tests, and Android release build. Treat warnings affecting correctness or release security as failures.
- Perform Android-device UAT for overflow, keyboard behavior, back navigation, large text, offline mode, map fallback, restart persistence, and all role flows.
- Existing login smoke-test style is insufficient; preserve useful assertions but expand coverage around user-observable workflows rather than widget internals.

## Out of Scope

- Figma authoring or maintenance; another contributor owns the mandatory Figma deliverable.
- A separate web or desktop administration frontend.
- Real DANA/OVO or other payment integration.
- In-app settlement for material purchases.
- Marketplace checkout for compost, maggot, or recycled products.
- A separate driver/courier role.
- Push notifications through FCM/APNs.
- Drop-off lifecycle and rescheduling; the first complete lifecycle is pickup.
- Operational activation outside Semarang.
- Live SMS delivery until an SMS provider is supplied.
- Automatic merging of independently created accounts.
- Sari assistance for Pengolah, DLH, or Admin decisions.

## Further Notes

- The competition APK must be demonstrable on one device without Firebase, Supabase availability, map tiles, 9Router, or SMS delivery.
- The normal build must use Supabase and enforce authorization in RLS and privileged server-side operations, not only in Flutter navigation.
- Supabase credentials provided for development must never be committed. The exposed service-role/secret credentials should be rotated after development.
- Documentation deliverables include environment setup, backend migrations, seed/reset procedures, Edge Function deployment, role provisioning, test commands, release build steps, and an updated progress ledger.
- The feature is complete only when the current repository and runtime evidence prove all in-scope user stories; a screen mock or Preview-only behavior cannot prove the normal backend path.
