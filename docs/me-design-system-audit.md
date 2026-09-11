# Me-based App design system — audit and implementation record

Date: 2026-09-11. Scope: the complete current Flutter App, including the separate
IBCLC entry point and embedded Agent forms/cards, media and assessment surfaces.
Visual authority is the **current Me implementation**, not the older product
proposal or a newly invented palette. Existing routes, APIs, fields, permissions,
state management, business decisions and user journeys must remain intact.

## Audit completed before UI changes

Scanned all `lib/**/*.dart`, the current route registrations, widget classes,
inline colors/type/radius/spacing, dialogs/sheets and the existing golden tests.
The widget-oriented scan identifies 80 source files / 33,821 lines (including
route/telemetry support). Full inventories, including nested/private widgets:
[UI inventory](design-system/ui-audit-baseline.json) and
[literal-style inventory](design-system/style-audit-baseline.json).
The literal scan finds 354 direct `Color`/Material `Colors` references, including
the existing token definitions, transparent paint and media overlays. These are
not all defects: chart/pose encoding and transparent paint require distinct
treatment. There are 296 explicit numeric font sizes and 135 numeric circular
radii in the widget-oriented scan. A scan count alone cannot establish visual
consistency.

Current source/golden baseline preserved at
`/tmp/momcozy-me-design-baseline-20260911`; the source hash manifest covers all
297 Dart files. The immediately preceding full Flutter regression passed 964
tests and analyzer was clean. No UI implementation changed before this audit.

### Me's observed visual language

Inspected current `mother_home_page.dart`, `mother_status_card.dart`, diary and
lactation pages/editors/chart, `KnowledgeBanner`, `ChoiceField`, product feedback,
expert support, the root shell and bottom navigation. Visually inspected the
390px Me home, diary and lactation goldens, and compared Schedule, booking and
the 1024px workbench. The current goldens were included in the preceding passing
full test run.

- Warm off-white page `#FAF7F3`, almost-white surface `#FFFEFC`, deep warm ink
  `#302A29`, secondary ink `#786F6C`, quiet border `#E5DAD4`.
- Rose action emphasis `#B45870` / `#8E3F54`, pale rose `#F6E7EB`. Primary filled
  form actions use deep ink with light text; secondary/text actions use rose.
- Knowledge/assistant/nav accent `#8752C7` and `#F3EBF9`; the actual Me knowledge
  card combines lavender and a quiet peach radial wash. Preserve this hierarchy.
- Existing green (`care`), amber, blue and danger semantic colors remain the
  source for status messages. No new arbitrary success/warning/error palette.
- Me's actual text inherits DM Sans with Noto Sans SC/PingFang fallback. Manrope
  already exists but is not the default Me title font; do not silently replace it.
- Page greeting 26/700; section 19/700; editor title 22/700; form label 16/600;
  body 14; secondary 13; caption 12; compact label 11; chart/nav micro label 10;
  measured value 34/500. Knowledge text has deliberate 1.5/1.75 line height.
- Home scroll inset is 8px left/right, 24px top, 28px bottom; section gap 24,
  status-grid gap 10, heading-to-content gap 14. Form/card interiors use 16–20.
- Ordinary cards have 18px corners and a quiet border, with no large shadow.
  Status cards and editor dialogs use 22px. Controls use 12px. Pills/circles
  remain appropriate for badges/avatars. Me's knowledge avatar has a soft glow.
- Rounded/outlined Material icons, 24px section/nav icons, smaller 16–20px
  contextual icons; existing character avatar and wordmark are kept.
- Errors retain entered data and retry; loading/empty are distinct. Dialogs and
  record editors already use scroll/constraints and explicit save/discard flows.

### Main inconsistencies and duplicates

| Area | Current difference from Me / duplication | Treatment |
|---|---|---|
| Shared theme | Incomplete AppBar, dialog/sheet, snack bar, chip, list, tab and state themes; error red differs from existing danger token | Extend the existing theme and semantic tokens |
| Agent / artifacts / forms | Many legacy pink, teal, grey palettes; separate card shadows, 14/22px card shapes, bespoke buttons and nested theme overrides | Align all visible layers to Me; retain streaming/tool/form behavior |
| Baby | Similar foundation, but teal knowledge variant, custom heading/card rules and mixed 8/20px margins | Reuse Me heading/surfaces, preserve chart/data semantics |
| Schedule / More / notifications | 20px page insets vs Me 8px, varied header spacing; bespoke inbox states | Shared layout/header/state presentation |
| Services / booking / summaries | Repeated bordered Container panels, 18/20/22px radii, slightly different titles/body sizes | Shared surface and typography roles; preserve routes and workflows |
| Auth / onboarding / account | Native themed fields mixed with local buttons, default dialog shapes, independently constrained widths | Use the same theme/form/layout rules across every step |
| Forms / overlays | Repeated padding and radius definitions in diary, baby, intake, purchase, Agent and IBCLC editors | Keep existing controllers/validation; consolidate presentation only |
| Consultation / media / motion | Dark viewing surfaces and signal overlays serve visibility, unlike ordinary product chrome | Align chrome/forms/states; explicitly retain readable media/pose semantics |
| IBCLC | Same broad palette but separate headings/badges/cards and desktop insets | Share tokens/components, retain responsive desktop table/navigation behavior |

No app-wide dark mode is currently configured (`darkTheme`, `themeMode` and
`ThemeData.dark` absent). Existing dark media/chart stages are deliberate local
surfaces, not a new dark theme to remove or recolor indiscriminately.

## Design-system plan

Extend `lib/shared/design_system/momcozy_design_system.dart` and
`momcozy_theme.dart`; do not create parallel themes or feature token files.
Add a small shared component layer only for reusable presentation currently
missing. Keep the existing `ChoiceField`, knowledge banner, month selector,
date-time field, error/empty views and wordmark as the canonical components.

| System | Planned rule from Me |
|---|---|
| Color | Existing primary/secondary/background/surface/ink/border; semantic success/warning/danger/info aliases; Me illustration/knowledge tokens; readable media foreground/overlay tokens |
| Typography | Named sizes/styles for page, dialog, section, title, body, secondary, caption, label, micro and metric; one font/fallback; eliminate fractional near-duplicates |
| Spacing | Core 4/8/12/16/20/24/32; explicit Me home gutter, grid gap, heading gap and card/form content roles instead of unrestricted numbers |
| Radius | Card 18, featured/status/dialog 22, control 12, compact tag/media thumbnail 8, pill/circle; normalize unexplained intermediate radii |
| Shadows/borders | Quiet 1px Me border; flat ordinary cards; retained measured soft overlay/knowledge-avatar shadows; theme focus/error borders |
| Icons/sizes | Rounded/outlined Material family, 16/20/24 contextual scale; existing illustration/brand assets; minimum 44px interactive target, text-scaled control heights |
| Interaction | Theme-driven focus/pressed/disabled/loading; primary/secondary/text/destructive semantics; no business-enabled-state changes |
| Layout | Same mobile content width and Me-derived page gutter/header/section rhythm; SafeArea/keyboard handling; desktop workbench retains wider responsive layout |

Material widgets styled by the shared theme are canonical components, not a
reason to add duplicate wrappers around every button, field or picker. Add/reuse
shared page body, heading/section heading, card surface, badge, loading/skeleton
and state presentation where they replace real duplication. Fullscreen media,
chart paints and procedural Me illustrations may use documented specialized
geometry or colors; ordinary product cards may not invent another palette.

## Phases, scope and gates

1. **Audit and Me extraction** — inventories and visual baseline above; done
   before editing UI.
2. **Tokens/theme/shared components** — regression tests for typography/colors,
   controls, cards, forms, states, overlays, long text and keyboard; inspect renders.
3. **Primary modules** — Me (extract without redesign), Baby, Cozymate, Schedule,
   More and service catalog. Compare navigation, margins, headings and cards.
4. **Details/forms** — all Me/Baby records and charts, services/purchase/booking/
   intake/progress/summaries, account/auth/onboarding, notifications/settings,
   consultation, Agent nested forms/cards/conversation panels.
5. **IBCLC and specialized surfaces** — all workbench pages and responsive shell;
   media/assessment chrome/states with visibility exceptions recorded.
6. **Overlays/states/cleanup** — dialogs, sheets, snack bars, skeleton/loading,
   empty/error/offline; remove only confirmed duplicate/dead presentation.
7. **Full visual and functional audit** — 320/390/430px mobile, long text/text
   scale, keyboard and safe area, desktop workbench, navigation/form/modal/scroll
   behavior, all Flutter tests and analyzer. Inspect rendered outputs; updating
   golden files or passing a literal-style scan is not sufficient evidence.

Expected modified files are the existing theme/tokens, shared widgets, app shell/
bottom navigation and the presentation files in the inventory. Expected new
files: only missing shared presentation components, regression/visual tests and
audit tooling/docs. Expected deletions: only duplicated local style/component
implementations after callers migrate; no route, data or asset removal assumed.

## Completion checklist — open until verified

- [x] Full inventory, Me extraction, inconsistencies, tokens/component plan and phase order.
- [ ] Color/type/spacing/radius/shadow/border/icon/size/state tokens centralized.
- [ ] Shared components and Material themes cover all requested control families.
- [ ] All primary modules aligned and visually reviewed.
- [ ] All details/forms/Agent embedded components aligned and reviewed.
- [ ] All overlays and loading/empty/error/offline/success/disabled states reviewed.
- [ ] IBCLC, media and assessment surfaces reviewed; exceptions justified.
- [ ] Mobile sizes, text scaling, localization/long text, keyboard/SafeArea/scroll verified.
- [ ] Existing navigation, APIs/models/controllers/permissions and business behavior preserved.
- [ ] Duplicate styles/components and unused assets audited without destructive cleanup.
- [ ] Full visual consistency review completed with rendered evidence.
- [ ] Full tests/analyzer pass; final changed/deleted files and remaining UX suggestions documented.

Implementation evidence will be appended here after each phase. An unchecked
item remains part of the active goal.

## Implementation evidence

### Shared foundation and Me extraction

Extended the existing design-system/theme files and added
`shared/widgets/momcozy_components.dart`: page body, page/section headings,
surface, badge and loading primary action. Existing Material buttons, fields,
cards, tabs, chips, app bars and overlays receive the shared theme. Existing
product feedback now also supplies loading/skeleton and optional empty-state
icons; no second state controller or router was introduced.

Me colors, status gradients, knowledge gradients/avatar shadows, text sizes and
font metrics were extracted from the saved baseline. Me inherits body metrics
1.43 / 0.25 letter spacing. The Chip theme must retain the complete inherited
font fallback; overriding it with an incomplete label style produced missing
Chinese glyphs and was corrected before proceeding. `me_theme_test.dart` and
`me_components_test.dart` exercise narrow/large-text controls, keyboard, scrolling
and dismissal. The three shared component renders have been visually reviewed.
The Me home plus shared component run passed 13 tests with original Me home
goldens unchanged (`/tmp/momcozy-ui-me-type-metrics.log`). The later expert-heading
migration changes its horizontal inset by 4px to match other Me headings; that
small golden difference was subsequently reviewed at all three mobile widths and accepted.

### Primary modules and Agent embedded surfaces

Baby home and compact knowledge card now use the Me heading/palette/card rules;
Schedule and More share page insets/header; root content width uses the shared
page container. Baby home/growth and Schedule 390px renders have been inspected.
Me home (three widths), Baby home/growth, Schedule (three widths), and More (three widths) renders were subsequently reviewed and their baselines accepted. Schedule date cells now grow with 2x text instead of overflowing a fixed 42px height; More privacy content scrolls in its dialog. More avatar precaching was rechecked at 320px.

Agent chat, markdown, progress text, action cards, composer, attachment chrome,
conversation drawer, generic/unsupported/specialized artifacts, consultation
consent card and embedded form entry/dialog now use the Me tokens. Generic and
specialized artifact cards share `MomCozySurface`; the private consultant tag
and conversation empty-state component were removed in favor of shared
components. The form's nested 0.92 font-size theme and bespoke input/teal button
rules were removed. The new regression first reproduced 12.88px embedded body
text instead of the shared 14px. Submission, consent, history selection,
attachments, scrolling and runtime code paths retain their original contracts.

`agent_me_design_test.dart` adds 12 tests covering 320/390/430px, 2x form/history
text, keyboard submission, consultation consent and the finished transcript.
All twelve chat/cards/form/history renders have been inspected; a black fringe
in the top fade was corrected by fading to transparent **background RGB**.
Asset precaching makes the avatar captures deterministic. The complete Agent
suite plus Me home/shared component/theme checks passed **285 tests** in
`/tmp/momcozy-ui-agent-green.log` before the later service-heading migration.
`/tmp/momcozy-ui-agent-visual.log` records the 12 visual/interaction cases.

Intentional Agent exceptions: monospace code, dark image viewing overlays,
animated avatar pulse/light geometry and composer measurements needed for its
existing streaming/attachment interaction. Pulse and light colors use Me colors;
no literal colors, numeric font sizes or numeric circular radii remain in Agent
presentation files. Layout geometry still requires the final spacing audit.

### Service detail and forms

Catalog, active expert support, package details, service progress/timeline,
appointment summary/detail, booking, intake, purchase dialog, and consultation
summary now use Me page widths/insets, semantic typography and shared surfaces.
The private booking panel and intake card helper were removed. The purchase
region dropdown now expands and wraps at 320px / 2x text; its old fixed-width
selected item overflowed. Purchase/Stripe callbacks, reminders, validation,
consent, API requests and route destinations retain their original contracts.

`service_design_test.dart` passes **30 tests** across 320/390/430px and 1x/2x
text. Catalog/provider dialogs, package/purchase entry, active expert actions,
progress/booking and appointment destination routes are exercised. All fifteen
service/expert/package/progress/appointment-detail renders were reviewed. Nine
new large-text cases in the existing booking, intake and purchase tests scroll
through their forms. That group passed **31 tests** after its nine normal-size
renders were reviewed (`/tmp/momcozy-ui-service-form-green.log`). Consultation
summary renders were also reviewed at all three widths; the filtered published
summary group passed **3 tests** (`/tmp/momcozy-ui-summary-green.log`). Workbench
goldens were not accepted as part of the consumer summary phase.

### Consumer authentication, account and onboarding

Login, registration, email verification, password reset, internal invite entry
and account management use the shared page width/insets and Material form theme.
Account content uses shared surfaces; loading/failure and destructive confirmation
use shared components. Dialog content scrolls with the keyboard or large text.
The invite screen now scrolls: the new 568px-height/300px-keyboard/2x-text test
reproduced a bottom overflow before this fix. Password hints and validation text
wrap. Authentication decisions, fields, persistence and deletion confirmation
remain unchanged; test actions use controlled local transports only.

`auth_design_test.dart` adds **24 tests** across the three widths and two text
scales. It covers input validation, registration, reset submission, invite error,
account navigation into password/deletion dialogs and cancellation without
mutations. All eighteen normal-size login/register/reset/invite/account/deletion
renders were reviewed. The full auth group passed **37 tests** in
`/tmp/momcozy-ui-auth-green.log`.

Onboarding now uses the shared page container and primary button (extended with
an optional icon), shared loading/empty components and flat generation recipe/
timeline surfaces. Removed its duplicate `_PrimaryButton`, `_LoadingView` and
`_LoadFailureView`. Its heading/body/secondary roles, radii, success/error colors
and regular gaps use the Me tokens. Photo reference and candidate artwork retain
their necessary aspect-ratio/illustration geometry. The task banner uses semantic
state colors and the common card radius/insets; long titles/descriptions wrap
instead of truncating. No onboarding controller, route, generation/polling,
privacy, upload, candidate gating or activation logic was changed.

`onboarding_design_test.dart` adds **36 tests**, covering all three widths at
1x/2x text: basics/delivery/birth forms with keyboard, date and dropdown selection,
profile save, required/generating/review/failed avatar screens, upload source sheet,
candidate/default selection, scrolling and task banners. All thirty normal-size
renders were reviewed. Existing auth/onboarding plus shared component tests passed
**112 tests** before the six banner cases were added; the final onboarding visual
file passes **36 tests** (`/tmp/momcozy-ui-onboarding-visual.log`). Controlled asset
images stand in for generated portraits. No external provider or payment action
was performed. Initial test harness failures (ambiguous scroll finder, a mistaken
shared-test path, and an unexpired fake completion timer) were corrected separately
from product fixes.

These phase results do not establish full-App completion. workbench, specialized
media/assessment, remaining overlays/state/icon/spacing cleanup and full final
visual/regression gates remain open. Onboarding task-mode success, load/error and
long lower-page content still need the final all-state visual pass. A current-state
file manifest and dependency-proven unused-style/asset audit are also still due.

### Notification presentation and current cross-module checks

Notification inbox/settings now use the common page body/insets and card
surface. The loading and empty implementations were removed in favor of shared
feedback components; refresh failures retain their original message and retry
behavior in a shared amber surface. The mark-all/settings row wraps on narrow
screens. Settings permission information and its action share a surface, and
permission dialog content scrolls. No coordinator, APNs/FCM gateway, permission
controller or reminder data behavior was changed in this presentation phase.

`notification_design_test.dart` adds **12 tests** at 320/390/430px and 1x/2x text:
long inbox content, refresh failure with retained content, retry/read/archive,
empty state, back/settings actions, preferences, consent cancellation and status
refresh. Fifteen normal-size renders were inspected. All notification tests plus
the App notification-session regression passed **45 tests** in
`/tmp/momcozy-ui-notification-green.log`. A dialog leaves its existing background
busy indicator running, so its visual tests use finite animation pumps instead
of waiting for all animations to settle. Real providers remain unconfigured and
unverified.

Before the notification presentation phase, all Agent/auth/onboarding/notification,
service/Baby/Schedule, Me home, More, theme/shared-component and notification-runtime
checks passed **551 tests** (`/tmp/momcozy-ui-primary-account-regression.log`). Full
analyzer remains clean after notification presentation
(`/tmp/momcozy-ui-phase-analyze.log`). This is a broad completed-phase regression,
not the final full-App suite. Workbench golden acceptance, among other remaining scopes above, still
requires work.

`design-system/implementation-file-manifest.json` records current library changes
against the saved pre-UI worktree, preserving unrelated preexisting work. It is an
in-progress source manifest, not a completion certificate or the final complete
test/doc/asset change list.


### Me/Baby detail pages and record dialogs

Diary/lactation pages and Baby history use the common page container. Record
editors share header/body insets, typography and control radii; history cards
use shared surfaces. The original Me lactation chart keeps its dark palette,
now named in the shared color tokens. Chart geometry and recorded values are
unchanged. The Baby growth card uses the common card radius.

The 320px/2x-text/300px-keyboard diary test reproduced a 25px overflow when a
save failed. Its error now lives in the form scroll area and is scrolled into
view after failure, while the existing save action remains reachable. Discard
confirmations scroll; the Baby profile dropdown allows wrapped items. Record
repositories, validation, field values, units, dates and save/delete/undo logic
are unchanged.

This phase adds 46 tests: six lactation large-text cases, eighteen diary modal
cases, fifteen Baby editor cases, three profile cases and four history cases.
All thirty new normal-size renders (diary rest/body/mood, five Baby record
kinds, profile and history at 320/390/430px), the 320px keyboard/error render,
nine existing Me detail renders and two Baby home/growth renders were visually
reviewed. Me/Baby alone passed 118 tests; a subsequent non-update run including
shared components passed **126 tests** (`/tmp/momcozy-ui-mom-baby-verified.log`).
Actions cover dirty-dismiss/cancel, offline-save/retry, saved feedback, Baby
record editing, delete/undo and profile save. Two new test brace-style findings
were corrected. Full-App completion and the remaining cross-module gates above
are still open.


### Consultation room and device-check presentation

The room now uses the shared page container (440px consumer width, its existing
760px expert working width), Me page insets, shared notice/consent/location and
outcome surfaces, and the common status badge. Typography, regular gaps, control
radii and icons use the shared tokens. The camera/video stage keeps its existing
dark colors as explicitly named media tokens; aspect ratios, picture-in-picture
geometry, track renderers and media controls' enabled conditions are preserved.
Leave/end confirmation dialogs scroll, the end-reason sheet supports long content,
and device-check title/content share one scroll area. Location dropdown items can
wrap. No consultation controller, repository, presence/permission/consent decision,
join/end behavior or RTC integration was changed.

Six new 2x-text variants extend the existing preparation/waiting-room tests;
`room_design_test.dart` adds 24 tests for device initial/error/retry-ready states,
video-consent selection and location dropdown, expert interruption sheet/end
confirmation cancellation, and outcome navigation. All 24 normal-size renders
(six existing room screens plus eighteen new detail/dialog screens) were reviewed
at 320/390/430px. The consultation suite passes **46 tests**. The first visual
run correctly flagged old/missing goldens; two new tests initially tapped controls
before they were visible and were corrected to scroll first. No product overflow
was observed in the final 1x/2x cases.

A non-update cross-module run covering all feature tests, Me/Baby/Schedule/service/
consultation modules, shared components and App tests passes **875 tests** in
`/tmp/momcozy-ui-consumer-room-regression.log`. This is not a full-App result:
workbench presentation, specialized media/assessment, remaining state/overlay/icon/
spacing audits, dependency-proven cleanup and final full-suite/visual gates are
still required. Real camera/microphone/RTC behavior is outside these controlled
local presentation tests.

Full `flutter analyze` is clean after this phase
(`/tmp/momcozy-ui-room-final-analyze.log`); formatting checks pass for the changed
consultation sources/tests, tokens and two corrected Me tests.

### Motion assessment and IBCLC workbench follow-up

Motion assessment chrome now uses named Me-derived media and interaction tokens;
its failure surface reuses the shared card/button system and is scrollable under
short-height, safe-area and 2x text conditions. Camera preview, pose skeleton
contrast, assessment phases, retry/exit callbacks and upload/permission behavior
remain unchanged. The focused responsive suite covers 320/390/430px at 1x/2x,
including failure, retry and exit, and passes 6 tests; the full motion plus IBCLC
suite passes 96 tests. Two 1x motion renders were inspected and stored under
`test/goldens/design_system/`.

IBCLC's shared workbench body, heading, pagination and badge now consume the
same spacing, typography, radius and max-width tokens while preserving the wider
responsive desktop layout. Its baseline goldens were regenerated after the
intentional visual change. The complete motion/workbench verification passes 96
tests. `flutter analyze` reports no issue in the changed production files; one
pre-existing test-only curly-brace info remains in
`test/native/media_pdf_design_test.dart`.

Current completion remains open for a full all-module rendered review, dependency
proven style/asset cleanup, and a complete app test run after all current
worktree changes. These follow-up changes do not establish completion by
 themselves.
