# Baby App UI/UX implementation — 2026-09-20

Implements the final Baby design decisions recorded in `design-assets/baby-interaction-map-20260919/full-page-review.md` in the parent workspace. Newer decisions supersede the historical states in that document.

## Delivered behavior

- Baby uses the same app-shell bottom navigation as Me. Selected controls use light lavender `#F7EFF7`, border `#CBB0C7`, text `#865C80`.
- Record forms use the bundled variable Noto Sans SC font: titles 20/28 semibold, field labels 15/22 semibold, choices 15/22 medium, input values 16/24 regular, buttons 16/24 semibold, units 14/20, secondary text 13/20.
- Baby profile is a full page. Empty name uses the placeholder “给宝宝起一个称呼吧”. Birth date comes from the mother's delivery date and is read-only. Name and sex are required. Save is enabled only for valid changes. Saving locks editing; success stays on the page with “已保存” disabled. New edits enable saving again.
- Feeding: 亲喂 / 瓶喂; bottle milk type is 母乳 / 配方奶; nursing side is left or right. Required choices gate save. Time defaults to now. Volume and duration remain optional. No notes, redundant help, history links or retry-specific button label.
- Daily status: 精神状态 / 尿湿 / 便便 retain independent drafts across tabs. At least one filled, valid tab enables “保存”, including when the visible tab is empty. Saving submits all filled tabs once. Mental choices are 平静满足 / 活跃 / 烦躁哭闹 / 困倦. Counts are positive integers, 1–100. Stool color and consistency remain optional; if filled, stool count is required. No event-time input.
- Growth retains measurements across tabs and saves all filled values as one batch. Tabs have plain labels with no checkmarks or completion badges. No saved banner or undo action.
- All Baby sheets close with the top-right control, drag, or a tap outside. Closing during a save does not cancel the submitted snapshot; the home refresh waits for it to settle.
- Save failures preserve inputs, show “保存失败，请重试” and keep the “保存” label. Unchanged retries reuse the idempotency key.
- Knowledge sheets use plain text, no source links, and an avatar with “问问 Cozymate”. Removed historical recording prompts from current topic selection.
- Removed sleep/development recording UI, all history routes/pages/entry points, saved feedback and undo controllers. Existing stored records and legacy API codecs remain readable for compatibility. No stored user data was deleted.

## API and rollout

New `daily_status` observations use the existing `/v1/babies/{baby_id}/records` API. A single observation contains `recorded_on`, `timezone`, and any supplied `mental_state`, `wet_count`, `stool_count`, `color`, `consistency`. It has no `occurred_at`. The date is supplied internally from the current app timezone. Daily counts are total values, not increments; the home summary uses the most recently saved value for each field and preserves previously supplied other fields.

Backend migration `20260920_0020` adds this observation kind to existing check constraints. Deploy the backend and migration before releasing this App version. App and backend OpenAPI snapshots are updated. No deployment or installable App package was produced in this task.

## Verification

- `flutter analyze`: no issues.
- `flutter test test/modules/baby test/domain/health_records_test.dart`: 73 passed.
- Golden checks cover 320 / 393 / 430 logical-pixel widths. Additional widget checks cover 2× text scaling, keyboard visibility, modal dismissal, save failures, in-flight saves and multi-tab draft persistence.
- Backend: 31 schema/service tests passed against an isolated local PostgreSQL test database, including atomic daily status persistence, idempotent retries, day filtering and baby isolation.
- Full migration chain through `20260920_0020` successfully applied to the isolated test database. Changed Python files pass Ruff.
- Old inventory suites asserting deleted history/sleep/development/undo UI and superseded form structures were replaced by the current-flow and final-design suites. Domain compatibility, repository scope/idempotency, profile controller and growth reference coverage remains.

No physical-device or emulator acceptance run was performed; golden images and widget tests verify the Flutter rendering and interactions.


## Motion polish — 2026-09-20

- Primary, choice, icon and switcher buttons use a 0.98 press scale over 100 ms. Pointer release/cancellation or scrolling restores the control. Original tap callbacks, focus and semantics remain owned by the Flutter control; actions never wait for the animation.
- Selection/button colors transition over 160 ms. Save labels cross-fade over 160 ms with a stable full-width button; outgoing labels are excluded from semantics.
- Bottom sheets enter over 280 ms with ease-out and exit over 220 ms with ease-in; the native route animates its barrier in sync. Outside taps and drag dismissal are preserved.
- Record tab content fades in over 180 ms and resizes over 240 ms. Only the current form is mounted, so outgoing inputs cannot submit against another tab. Controller drafts remain intact during rapid switching.
- Keyboard inset and available sheet height use the same animated value over 180 ms, keeping fields and footer together.
- Profile navigation continues using native page transitions and the existing platform back gestures. System reduced-motion mode bypasses sheet/press/fade/resize movement. Toggling the preference mid-transition settles the active form without losing its input subtree.

Verification: 86 tests passed with `flutter test test/modules/baby test/shared/route_motion_test.dart test/domain/health_records_test.dart`. Existing Baby settled-state goldens passed unchanged. Coverage includes intermediate animation frames, immediate tap callbacks, gesture cancellation, keyboard motion, rapid tab changes, disabled controls, reduced motion and system back navigation. Static analysis passes. Device frame-time/performance measurements have not been run.

A broader check of `test/shared/momcozy_motion_test.dart` also ran: six unrelated golden scenarios in the avatar task / language selection / agent conversation history surfaces have existing screenshot-baseline mismatches. This suite does not use Baby widgets; its baselines were not regenerated as part of the Baby motion work.


## Local deployment — 2026-09-20

Deployed the current working trees using `scripts/local-dev-stack.mjs up`, refreshed the Product notification/auth-email workers, and installed the local debug App (`1.0.0+57`) on Android emulator `emulator-5554` without clearing app data. Product Backend uses host port 8769 and Agent Runtime port 8010. Database revisions are Product `20260920_0020` and Agent `20260916_0002`. Both databases were backed up before migration.

Authenticated local-stack checks passed. A transaction against the deployed Product service verified the daily-status payload, read-back and idempotent replay, then rolled back all verification rows. The emulator restored its existing login and loaded the Baby home with live local data. Sheet opening, tab switching, draft text entry and outside dismissal were checked; no user record was saved by UI verification.

Native verification exposed the shell navigation beneath sheets. Baby sheets and the profile page now use the root navigator so the sheet barrier covers the entire app and profile navigation covers the shell. Added a nested-navigator regression test. The 80 Baby/navigation checks and 8 motion checks passed; static analysis is clean. This is a local debug installation, not a cloud or public APK release. Detailed metadata, backups and screenshots are under the ignored `build/local-deploy/20260920-110819/` directory.

## Figma fidelity calibration — 2026-09-20

Read the final Figma nodes and exported 30 original assets, including vector outlines for the small close/time/date glyphs. Calibrated card/field geometry, typography, selected/disabled styles, sheet safe areas, profile title updates and original home artwork. The existing Me app-shell navigation is reused. All current draft/save/close behavior remains covered.

Independent Figma vs Flutter captures cover 21 views/states at matching logical dimensions, with explicit foreground/system-area crops. References, app renders, overlays, differences, asset provenance and remaining differences are in [the visual review](../../design-contract/baby/README.md). This is separate from Flutter's own golden baselines; neither goldens nor difference averages are treated as proof of pixel identity. Real age/count formatting and data-driven WHO curves intentionally remain driven by current product rules.

Final static analysis is clean; 109 targeted Baby, navigation, domain and accessibility tests pass, including 320/393/430px and keyboard/large-text interactions. A reusable skill is installed at `/Users/lute/.codex/skills/figma-to-app/`; its comparison utility passed identical-image, size-rejection, DPR, crop and bounds checks.

Rebuilt and installed the final vector-asset implementation on `emulator-5554` as `1.0.0+57 local/debug`, preserving login/data. Native verification passed for required fields, bottle subchoices, outside dismissal, knowledge CTA/avatar, switcher, profile return and home scroll end; no test records were saved. Screenshots and build checksum are in the visual review's `native/` folder. Existing plugin KGP migration warnings did not block the build. No cloud publication occurred.

## Shared navigation correction — 2026-09-20

The prior calibration reused the App's existing Me navigation but omitted the final Figma navigation styling. This omission is now corrected in the shared `MomCozyBottomNavigation`: original dimensional artwork, rose selected state, DM Sans labels, 82px chrome and raised 58px Cozymate avatar. Me and Baby navigation have independent same-size Figma comparisons, including the protrusion; see [navigation evidence](../../design-contract/baby/evidence-assets/navigation/README.md). Static analysis is clean and 133 relevant tests pass, including navigation routes, large text and the raised avatar's hit area. The reusable skill now explicitly requires checking the entire App shell rather than assuming an existing shared component matches the design.

## Non-disruptive Baby refresh — 2026-09-20

- Initial reads without data still show loading. Same-baby background reads retain displayed profiles, summaries and growth curves. Transient read failures retain available data with the existing retry affordance; authorization failures discard protected values.
- A stateful route owns one controller through parent rebuilds. A runtime-scoped snapshot restores previously displayed Baby data immediately on tab return, followed by a background refresh. Snapshots contain view data only, not controllers, timers or live listeners; a different account/runtime starts without the previous cache.
- Canceling a record sheet or returning from an unchanged profile performs no new reads. The profile editor now distinguishes a successful save from its initial profile. Successful profile saves apply the authoritative returned profile directly; adding a different baby loads that baby's records.
- Feeding/daily-status saves refresh recent records only. Growth saves refresh latest measurements and curve data only. Existing content remains visible until replacements arrive. A sheet dismissed during an in-flight save still returns the successful result after settlement, so its saved data is not missed.
- Duplicate profile loads are coalesced. Per-resource request ordering prevents late same-baby responses from overwriting newer data. Baby selection/account boundaries clear incompatible data; day changes clear daily totals before reading the new day. Profile save invalidates older background profile responses.

Validation: static analysis clean; 119 targeted Baby, route-cache, navigation-motion, domain and accessibility tests passed. New delayed-request tests verify warm refresh, offline retention, authorization clearing, cancellation request counts, targeted save reads, account separation, day rollover and out-of-order responses. No artificial minimum loading duration was added. This changes Baby's refresh behavior; it does not claim that all independent App modules now share this cache or that network latency has been benchmarked.

Updated `1.0.0+57 local/debug` on `emulator-5554` without clearing data. Native checks verified that canceling a record sheet and switching Me → Baby returned to populated content; snapshots were taken shortly after the transition. Existing login was preserved and no real records were saved. Logs, screenshots and verification metadata are in `build/baby-refresh-review/`. Slow-request and request-count guarantees come from the controlled regression tests, not inference from device screenshots.

## Figma-first Baby calibration — 2026-09-20

Re-ran the Baby surface against the stored Figma node exports using the final implementation and updated the 320/393/430 home baselines after the user-confirmed Luna title reduction. The exported comparison set covers 21 states across the home, profile, feeding, post-feeding state, wet diaper, stool, growth, switcher and knowledge sheets. Interaction regression also covers the remaining manifest states: no-profile/loading/empty/missing/error home branches, keyboard layouts, draft preservation, save locking, outside dismissal, route return and account separation.

The final run passed 115 targeted tests and Flutter static analysis. The local debug build `1.0.0+57` was installed on `emulator-5554` without clearing app data. Screenshots, comparison captures, logs and verification metadata are in `build/baby-figma-calibration-review/`. The Luna title follows the latest user confirmation rather than the older 26px value in the stored Figma export; this is recorded as an intentional product override.

## Baby design contract — 2026-09-20

The Baby module is now organized under [the versioned Figma-to-App contract](../../design-contract/baby/README.md). `contract.json` freezes 32 Figma states, 32 local same-size references, 30 local assets, tokens, Flutter widget mappings, modal interactions and targeted refresh rules. All reference images are now present; 30 states are visually verified, while the no-profile navigation first frame and long-name truncation remain implemented with explicit limitations rather than being reported as visual passes.

The first contract-driven calibration changed empty summaries and growth cards from “未记录” to the Figma-aligned “待记录”, using the secondary text color. The next pass corrected the home wet-diaper summary unit from “片” to “次”, matching the Figma card and the product requirement. The regression suite asserts both changes and current Baby tests remain green. The rebuilt APK installed successfully; the recapture screen reached the existing “加载失败，请重试” branch because the backend fixture was unavailable, which is recorded in `design-contract/baby/evidence.json` rather than treated as a visual pass.


## Figma home-state export and round 3 calibration — 2026-09-21

The 11 previously unexported home and growth references were captured from the official Figma file through MCP and stored under `design-contract/baby/references/`. A new same-size Flutter fixture test captures no-profile, loading, empty, incomplete-profile, long-name, error, recent mental state and all three growth metric selections at the dimensions declared by their Figma frames.

This round aligned empty growth metric card height, error/retry spacing, the dotted growth loading indicator, the missing-profile completion panel and the no-profile add-card geometry. The fixture date is pinned to the Figma reference date so the knowledge card and age label are data-consistent; production age text remains runtime-derived.

The 11 actual captures are indexed in `design-contract/baby/comparisons/home-state-captures.json`. Nine states have been visually reviewed against same-size Figma captures; the no-profile navigation image first-frame behavior and the final long-name truncation fixture remain explicitly tracked in the contract. Device recapture remains blocked by the unavailable backend fixture, so this round does not claim a live-device visual pass.
