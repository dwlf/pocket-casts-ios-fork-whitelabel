# FORK.md

Fork-specific architecture, mechanics, and contribution discipline
for the white-label fork of
[Automattic/pocket-casts-ios](https://github.com/Automattic/pocket-casts-ios).

If you're a first-time visitor, start at
[`README.md`](README.md). This document is for people who will
build on top of this fork, contribute to it, or sync it with
upstream.

## Why this fork exists

`Automattic/pocket-casts-ios` ships a working app bound to Pocket
Casts' production infrastructure — its server URLs, account system,
discover feed, sharing service, and IAP catalog are all hard-coded
into Swift sources. This fork extracts those bindings into a config
layer (`WhitelabelConfig`) so the same codebase can target custom
user experiences, integrations and unaffiliated branding, while
staying mergeable with upstream on a weekly cadence.

The goal is *not* to compete with Pocket Casts, replace it, or
ship a re-skinned version of it. The goal is to make the
underlying iOS podcast-player codebase reusable as a starting
point for differently-integrated products under unaffiliated
branding.

## Architecture: the decoupling layer

### `WhitelabelConfig` — the single injection point

All previously-hard-coded brand and server values are read through
a generated Swift struct:

```swift
enum WhitelabelConfig {
    static let brandName: String           // "" by default
    static let supportEmail: String        // "" by default
    static let apiProductionURL: String    // "" by default
    static let apiStagingURL: String       // "" by default
    static let discoverURL: String         // "" by default
    static let iapPlusYearly: String       // "" by default
    static let bundleRoot: String          // "com.example.whitelabel"
    // ... see config/whitelabel/whitelabel.json for the full list

    static var hasBackend: Bool { !apiProductionURL.isEmpty }
}
```

This file is **generated at build time**, gitignored, and never
committed. The source of truth is
`config/whitelabel/whitelabel.json`.

### Generation pipeline

Mirrors the existing `ApiCredentials.tpl` → `LocalApiCredentials.swift`
pipeline (already in the project for Automattic's secrets):

1. `Modules/Sources/PocketCastsUtils/General/WhitelabelConfig.tpl` —
   Swift template with `%{key_name}` placeholders.
2. `config/whitelabel/whitelabel.json` — flat key/value JSON with
   one entry per template placeholder.
3. `scripts/generate_whitelabel_config.sh` — invoked by
   `make external_contributor` (and re-runnable any time the JSON
   changes). Calls `ruby podcasts/Credentials/replace_secrets.rb -i
   WhitelabelConfig.tpl -s whitelabel.json` to produce
   `Modules/Sources/PocketCastsUtils/General/WhitelabelConfig.swift`.

The generated file lives inside the `PocketCastsUtils` Swift Package
module — every target that imports `PocketCastsUtils` (main app +
NotificationExtension + NotificationContent + PodcastsIntents +
PodcastsIntentsUI + Pocket Casts App Clip + Pocket Casts Watch App +
Pocket Casts TV App + the `PocketCastsServer` module) gets
`WhitelabelConfig` visible without per-target wiring. SPM
auto-includes the generated `.swift` in the module's compile sources.

### What consumes `WhitelabelConfig`

| File | What it reads |
|---|---|
| `Modules/Sources/PocketCastsServer/Public/Sharing/Structs/ServerConstants.swift` | All server URLs |
| `podcasts/Strings+L10n.swift` | Brand name, support email, social handle, website |
| `podcasts/SocialsHelper.swift` | Social handle |
| `podcasts/InAppPurchases/IAPTypes.swift` | IAP product IDs |
| `podcasts/LogsView.swift` | Support email |
| `podcasts/LegalAndMoreView.swift`, `OnlineSupportController.swift`, `StatusPageViewModel.swift` | Support / legal URLs |

The IAP refactor drops the `String` raw backing from `IAPProductID`
and `IAPPromotionID` (raw-value enums require compile-time literals).
The cases stay — the plan set is fixed across brands — and each gains
a computed `productId` sourced from `WhitelabelConfig`, plus a failable
`init?(productId:)` for the store-string reverse lookup. An empty
config id makes every lookup fail, disabling subscription flows per the
config's empty-default contract. Keeping the enum preserves the
exhaustive switches on plan semantics (tier, frequency).

### What is *not* read from `WhitelabelConfig`

Bundle-ID Swift references (≈20 call sites) are derived from
`Bundle.main.bundleIdentifier` instead — minimal diff against
upstream, no config plumbing needed. App-group identifiers (which
must match across all five targets sharing the container) flow from
the `APP_GROUP_ID` xcconfig variable: `.entitlements` files reference
`$(APP_GROUP_ID)` directly, while Swift reads it from each target's
Info.plist (`APP_GROUP_ID` key, also substituted from
`$(APP_GROUP_ID)`) via the single
`SharedConstants.GroupUserDefaults.groupContainerId` accessor. The
two widget-helper constants alias that accessor rather than
re-declaring the value. `scripts/check-app-group-id.sh` (run by
`make build_whitelabel` / `verify-whitelabel`) fails the build if a
hardcoded literal reappears in entitlements or Swift.

## Schemes

| Scheme | Configuration | Purpose |
|---|---|---|
| `Whitelabel Debug` | `WhitelabelDebug` | Whitelabel build, dev signing |
| `Whitelabel Staging` | `WhitelabelStagingDebug` | Whitelabel build with `-D STAGING` |
| `Whitelabel Release` | `WhitelabelRelease` | Whitelabel build for distribution |
| `pocketcasts` *(inherited)* | `Debug` | Unmodified Pocket Casts build — verification only, requires Automattic secrets |
| `Pocket Casts Staging` *(inherited)* | `StagingDebug` | Unmodified Pocket Casts staging — verification only |

The inherited upstream schemes exist to verify `make sync-upstream`
merges still produce a buildable upstream. They are not intended
for distribution from this fork.

## Configuration

All values live in `config/whitelabel/whitelabel.json`. Defaults
ship empty so the public build runs without any secrets.

Empty-value behavior: code paths that depend on absent values
either no-op silently or show a neutral empty state (e.g. the
Discover tab renders "no discover feed configured" rather than
making a network call to a missing host).

### Network privacy

White-label builds must not phone home to Automattic. Two analytics
paths reach Automattic hosts independent of the configurable backend,
so both are gated:

- **Automattic Tracks / ExPlat** — `TracksAdapter` fires an ExPlat
  experiment fetch on init and streams events to Automattic. It is
  excluded from the analytics adapter list under `-D WHITELABEL`
  (`AppDelegate+Analytics.swift`). The remaining adapters are local
  logging and Sentry crash logging.
- **Sentry** — disabled by an empty `ApiCredentials.sentryDSN`.

`LiveAnalyticsStreamer` only transmits to a server-supplied
`liveAnalyticsUrl`; with no backend it is never given one.

`scripts/whitelabel-netcheck.sh` captures DNS while the built app
launches and idles, then fails if any lookup hits a Pocket Casts /
Automattic host (Stage 4 step 37; requires sudo).

Tap-triggered links that opened upstream hosts are also handled: the
podcast-page category link routes to `WhitelabelConfig.websiteURL` (no
link when empty), and the Apple-Podcasts import option, End-of-Year
ratings "learn more" link, and the About → Automattic-family / Work-
With-Us / logo sections are compiled out under `#if !WHITELABEL`. These
fire only on interaction, so they do not affect the idle netcheck.

## Building a branded fork on top

The branded layer is a separate (typically private) repo with this
whitelabel as its `upstream` remote:

```
your-branded-app/
  remote: origin   → github.com/<you>/your-branded-app (private)
  remote: upstream → github.com/<you>/whitelabel       (public)
```

The branded layer adds:

1. `config/brand/<brand>.json` — fills in `WhitelabelConfig` keys
   with brand values.
2. `config/Brand.{base,debug,staging,release}.xcconfig` — overrides
   the whitelabel xcconfigs. Sets `WHITELABEL_CONFIG_JSON =
   $(SRCROOT)/config/brand/<brand>.json`, brand bundle ID prefix,
   dev team, signing identity.
3. `podcasts/Brand/*.xcassets` — brand-specific asset catalogs
   (app icon, onboarding art, theme artwork).
4. New schemes `Brand Debug`, `Brand Staging`, `Brand Release` and
   matching project-level build configurations.

**No Swift code changes are required in the branded layer.** The
WhitelabelConfig mechanism is the entire injection surface. This
is the upstream-sync hygiene payoff.

## Syncing with upstream

```bash
git remote add upstream https://github.com/Automattic/pocket-casts-ios.git
make sync-upstream      # git fetch upstream + merge upstream/trunk
make verify-whitelabel  # builds Whitelabel Debug end-to-end
```

Cadence: **weekly**. Pocket Casts iOS lands ~10–20 PRs per week;
monthly merges accumulate enough drift that conflict resolution
becomes painful. Weekly merges keep each cycle to <30 minutes.

### Expected conflict shape

Conflicts cluster in a small predictable set:

| File | Conflict trigger | Resolution pattern |
|---|---|---|
| `ServerConstants.swift` | Upstream adds/renames a URL | Add the key to `WhitelabelConfig.tpl` + `whitelabel.json`, wrap the new constant in `WhitelabelConfig.<newKey>` |
| `Strings+L10n.swift` lines 8–14 | Upstream edits proper-noun block | Re-apply `WhitelabelConfig` wrap to the proper-noun lines |
| `IAPTypes.swift` | Upstream changes the IAP enum | Re-apply struct conversion |
| `podcasts.xcodeproj/project.pbxproj` | Upstream adds a build configuration or target | Append whitelabel configurations *after* the new upstream additions in each `XCConfigurationList` |

Per-file conflict playbooks:
[`docs/whitelabel-upstream-sync.md`](docs/whitelabel-upstream-sync.md).

### Verification after a sync

`make verify-whitelabel` runs `xcodebuild` against the
`Whitelabel Debug` scheme. The expected outcome:

- Build succeeds.
- The built `.app` carries no calls to `pocketcasts.com` /
  `pocketcasts.net` / `pca.st` when launched with empty
  WhitelabelConfig (verified via Proxyman or `tcpdump`).
- All previously-passing whitelabel-targeted tests still pass.

A pre-push git hook enforces.

## What is different from upstream

- Server URLs and credentials extracted to `WhitelabelConfig`
  (default: empty).
- Brand strings in `Strings+L10n.swift` read from
  `WhitelabelConfig`.
- Bundle ID derived from xcconfig
  (`PRODUCT_BUNDLE_IDENTIFIER_ROOT`) with Swift references using
  `Bundle.main.bundleIdentifier`.
- App-group ID derived from xcconfig (`APP_GROUP_ID`): all 12
  `.entitlements` files and the four shared-container target
  Info.plists use `$(APP_GROUP_ID)` substitution; Swift reads it from
  Info.plist. Guarded by `scripts/check-app-group-id.sh`.
- Associated Domains entitlement empty in whitelabel builds.
  Upstream's `podcasts.entitlements` / `podcastsDebug.entitlements`
  pin 14 entries to `pocketcasts.com`, `pca.st`, `pocketcasts.net`,
  `play.pocketcasts.com`, etc. (across `applinks:`, `webcredentials:`,
  and `appclips:` prefixes); a signed whitelabel build with those
  domains would hijack universal links and share saved passwords
  with `pocketcasts.com`. The three Whitelabel main-app configs
  point at `podcasts/whitelabel{,Debug}.entitlements`, which mirror
  the upstream files but with an empty
  `com.apple.developer.associated-domains` array. The branded
  private fork is expected to override these with its own domains.
- `CFBundleDisplayName` and `CFBundleName` in
  `podcasts/podcasts-Info.plist` substituted via `$(MARKETING_NAME)`.
  `MARKETING_NAME` defaults to `Pocket Casts` in
  `PocketCasts.base.xcconfig` (preserves upstream) and to
  `Whitelabel` in `Whitelabel.base.xcconfig`. The label users see
  under the home-screen icon swaps with the active scheme.
- App icon: neutral "Whitelabel" wordmark on dark slate, sitting
  inline as `AppIcon-Whitelabel.appiconset/` inside the existing
  `podcasts/AppIcon.xcassets/` catalog. The three Whitelabel
  configurations (`WhitelabelDebug`, `WhitelabelRelease`,
  `WhitelabelStagingDebug`) on the main iOS app target set
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Whitelabel` in
  `project.pbxproj`; upstream schemes continue to resolve `AppIcon`.
  Source PNG is reproducible via
  `python3 scripts/generate_whitelabel_appicon.py`. The watch app,
  App Clip, and TV app icons are untouched (out of Stage 3 scope).
- Launch screen: `podcasts/podcasts-Info.plist` selects the nib via
  `UILaunchStoryboardName = $(LAUNCH_STORYBOARD_NAME)`.
  `LAUNCH_STORYBOARD_NAME` is `Launch Screen` in
  `PocketCasts.base.xcconfig` and `Launch Screen-Whitelabel` in
  `Whitelabel.base.xcconfig`. The Whitelabel nib is a plain dark-slate
  background. Both nibs ship in the bundle.
- Pull-to-refresh spinner: under `#if WHITELABEL`,
  `CustomRefreshControl` loads `refresh_inner_whitelabel` /
  `refresh_outer_whitelabel` — neutral concentric ring-arcs that keep
  the two-ring rotation animation. The PNGs (46@2x / 69@3x) are
  reproducible via `python3 scripts/generate_whitelabel_refresh.py`
  and sit inline in `podcasts/CommonImages.xcassets/`.
- No-artwork placeholder: the upstream `noartwork-*` assets
  (`podcasts/NoArtwork.xcassets/`) are the Pocket Casts logo, shown as
  the cover placeholder on the grid, list, podcast page, and player
  whenever a podcast/episode has no loaded artwork. Under
  `#if WHITELABEL`, `ImageManager.placeHolderImage` renders a neutral
  placeholder instead (plain panel + a generic `waveform` SF Symbol,
  light/dark aware), with no new asset files. Branded forks may replace
  it with their own art.
- Other asset catalogs (`Onboarding`, `Subscription`, etc.) remain
  on the plan to be overlaid by neutral variants under a
  `Whitelabel.*.xcassets` parallel set with
  `EXCLUDED_SOURCE_FILE_NAMES`-driven selection. Not yet wired.
- Intro onboarding carousel: all three hero images
  (`intro-carousel-podcasts`, `intro-carousel-effects`,
  `intro-carousel-folders`) are omitted in whitelabel builds via
  `#if !WHITELABEL`. The upstream assets render third-party podcast
  cover art and screenshots of the Pocket Casts player/folders
  chrome; neither is safe under an independent fork's brand. Slides
  still render brand header + quote + author attribution; the
  branded fork is expected to inject its own marketing imagery.
- `Localizable.strings`, `InfoPlist.strings`, and `Intents.strings`
  brand-stripped at build time (post-Copy Bundle Resources phase,
  via `scripts/strip_brand_strings.py`). Reads `MARKETING_NAME` and
  `WEBSITE_SHORT` from xcconfig and rewrites the three binary plist
  families in every locale's `.lproj`. Intents.strings carries
  Siri Shortcuts voice-command phrases ("resume Pocket Casts" etc.)
  in all 15 shipped locales. No-ops when
  `MARKETING_NAME == "Pocket Casts"` so upstream schemes pass
  through unmodified.
- System permission prompts (`NSBluetoothPeripheralUsageDescription`,
  `NSLocalNetworkUsageDescription`, `NSMicrophoneUsageDescription`,
  `NSPhotoLibrary{Add}UsageDescription`) in the source
  `podcasts/podcasts-Info.plist` use `$(MARKETING_NAME)`
  substitution; Xcode preprocesses Info.plist at build time. The
  localized InfoPlist.strings translations are rewritten by the
  strip script above. The label users see on the first permission
  alert reads "Whitelabel needs to access your microphone…" etc.
- File-type and CarPlay scene names in `podcasts/podcasts-Info.plist`
  (`CFBundleTypeName`, `UTTypeDescription` for the podcast bundle UTI,
  and `UISceneConfigurationName` for the CarPlay scene) use
  `$(MARKETING_NAME)` substitution. Files.app, Share Sheet, and the
  CarPlay scene config display "Whitelabel Bundle" / "Whitelabel Car"
  in whitelabel builds.
- End-of-Year feature (`podcasts/End of Year/`) excluded from
  whitelabel builds.
- Alternate app icon picker hidden in whitelabel builds. The 19
  alternate icons in `AlternateAppIcons.xcassets` (Pocket-Cats,
  Patron-*, Pride, Halloween, etc.) all carry Pocket Casts brand
  art; exposing the picker would let users swap the home-screen
  icon back to branded art. `AppearanceViewController.updateTableAndData()`
  removes the `.appIcon` section under `#if WHITELABEL`. The
  catalog itself is still bundled (bundle-size trim is plan items
  28-30 territory); the threat surface is closed because no UI
  reaches the alternates.
- No-backend graceful degradation, gated on the runtime flag
  `WhitelabelConfig.hasBackend` (`!apiProductionURL.isEmpty`; false in
  the public empty-config build, true for branded forks and upstream):
  - Initial onboarding is skipped
    (`MainTabBarController.showInitialOnboardingIfNeeded`); the app opens
    on the Podcasts tab, which is also the default launch tab.
  - Subscription upsells are suppressed: `PaidFeature.isUnlocked`
    returns `true` (premium features work and their locked-state prompts
    never render), `PaidFeature.presentUpgradeController` and
    `NavigationManager.showUpsellView` no-op, and the Profile, Settings,
    Appearance, Files, Watch upgrade banners and the encourage-account
    banner are hidden.
  - Podcast search (`PodcastSearchTask`, `CombinedSearchTask`,
    `PredictiveSearchTask`) returns empty instead of hitting an empty
    host. Adding a podcast by RSS feed URL or Apple Podcasts link works
    via on-device ingestion (below).
  - The About screen shows the brand name instead of the Pocket Casts
    logo.
- Backend-free podcast ingestion (`FeedIngestion`, in
  `podcasts/New Search/`). Pasting an RSS feed URL or an Apple Podcasts
  link (`podcasts.apple.com/.../id<digits>`) into the search bar adds
  the podcast without the Pocket Casts cache host: an Apple link is
  resolved to its RSS feed via the public iTunes Lookup API, the feed is
  fetched and parsed on-device (AEXML), and the channel/items are mapped
  into the shape `Podcast.from` / `Episode.from` consume, then saved via
  the new `ServerPodcastManager.addPodcastFromFeed`. Podcast and episode
  UUIDs are derived deterministically (SHA-256 of the feed URL / episode
  GUID) so re-adds and refreshes are idempotent. `SearchResultsModel`
  routes any URL through ingestion, and `SearchResultsViewController`
  ingests on the as-you-type timer so a pasted link adds without a
  separate submit. Feed refresh and showing the feed's own cover art
  (rather than the neutral placeholder) are not yet wired — see
  `docs/known-issues.md`.
- `.buildkite/` is present but inert. Automattic CI infrastructure
  is not available here.
- `.configure-files/` ships empty. The inherited `pocketcasts`
  scheme will not build here without Automattic-internal secrets.

## Contributing

This fork is the brand-stripping and decoupling layer over
upstream. Bug fixes and feature work on the *podcast app itself*
belong upstream at `Automattic/pocket-casts-ios` — we merge them
in during weekly upstream sync.

PRs to this fork should be limited to:

- The `WhitelabelConfig` mechanism and its consumers
- The xcconfig matrix, schemes, and build configurations
- The asset and strings overlay infrastructure
- Upstream-sync tooling and conflict playbooks
- Documentation

PRs that should go upstream instead:

- Bug fixes in the playback engine, downloader, sync engine,
  podcast parser, episode UI, etc.
- New features in the app itself
- Localization improvements
- Performance work

If a PR is in scope here but also fixes a bug that exists
upstream, file it upstream first, then merge the fix down via
`make sync-upstream`.

## License posture for downstream forks

MPL-2.0 is file-level copyleft. For a closed-source branded
product built on top of this fork:

- **Modifications to MPL files** (e.g. the
  `ServerConstants.swift` changes that wrap URLs in
  `WhitelabelConfig`) **remain MPL-2.0** and must be
  source-available to recipients of the binary. Easiest path:
  keep your modifications in this public whitelabel repo (or
  another public mirror of it) and pull from there.
- **Entirely new files** added in the branded layer
  (`config/Brand.*.xcconfig`, `config/brand/<brand>.json`,
  `podcasts/Brand/*.xcassets`, brand-specific Swift files) can
  be any license you choose, including proprietary.
- **Brand assets** (logos, fonts, illustrations) are yours and
  carry no license obligation from this fork.
- **In-app license notice.** The Acknowledgements screen
  (`podcasts/acknowledgements.html`, reachable via About → Legal &
  More) carries the MPL-2.0 notice and a link to the MPL source. MPL
  obligations are source-form, not UI — there is no requirement to
  credit the upstream author by name, and the notice is worded to
  avoid implying endorsement. A branded fork that keeps its MPL
  modifications in a different public mirror should update that
  source-code URL.

## Gotchas & verification notes

Non-obvious facts worth knowing before working on the decoupling layer.

### Build / architecture

- **`#if WHITELABEL` does not reach the SwiftPM modules.** The
  `-D WHITELABEL` flag lives in `Whitelabel.base.xcconfig` and applies to
  the app and extension targets, not to `Modules/Sources/*`
  (PocketCastsServer, PocketCastsUtils, …). To branch module code by
  brand, gate at the app-target caller or use a value-based
  `WhitelabelConfig` check (which works everywhere).
- **The `pocketcasts` scheme is build-verification only.** Brand values
  route through `WhitelabelConfig` with empty defaults, so the upstream
  scheme is not runtime-functional in this fork, and it needs
  Automattic-internal secrets to build at all. Empty IAP IDs / server
  URLs there are by design, not a regression.
- **`#if` is invalid inside a Swift array/collection literal.** Build the
  array in a closure-initialized `let` and append conditionally instead.
- **Gate server-dependent behaviour on `WhitelabelConfig.hasBackend`
  (runtime), not `#if WHITELABEL` (compile-time).** The branded fork
  compiles with `-D WHITELABEL` but ships real server URLs, so it must
  run the full onboarding / upsell / search flows; only the public
  empty-config build (`hasBackend == false`) skips them. Reserve
  `#if WHITELABEL` for pure brand-art swaps (logos, names) that every
  white-label build wants regardless of backend. `hasBackend` is a
  value check in PocketCastsUtils, so it works inside the SwiftPM
  modules where `#if WHITELABEL` does not reach.
- **The native launch screen renders before app code, so in-app swaps
  can't reach it.** The `splashlogo` watermark in the launch nib is
  invisible to any `#if WHITELABEL` Swift branch or runtime Text-swap.
  Select a logo-free nib per configuration instead:
  `UILaunchStoryboardName = $(LAUNCH_STORYBOARD_NAME)` in the shared
  Info.plist, with the value defined in each base xcconfig. The same
  `$(VAR)`-in-Info.plist substitution pattern works for any launch-time
  plist key that needs to differ by brand without forking the plist.
- **Template-rendered assets only carry shape in their alpha channel.**
  The refresh spinner arcs are loaded `.withRenderingMode(.alwaysTemplate)`,
  so a neutral replacement just needs opaque-on-transparent geometry —
  the runtime tint (`CustomRefreshControl.updateTintColor`) supplies the
  colour. Generate as white-on-transparent and verify by compositing on
  a dark background, not by eyeballing the raw PNG (invisible on white).

### Verification

- **Simulator white-label builds are ad-hoc signed with empty
  entitlements** (no `DEVELOPMENT_TEAM`). The signed app-group entitlement
  cannot be verified on the simulator. Verify instead via each target's
  Info.plist value, `xcrun simctl get_app_container <dev> <bundle>
  group.<id>`, and the on-disk shared-container suite.
- **Enumerate rename/leak sites with the compiler and keyword sweeps, not
  file-name scoping.** `for f in $(rg -l …)` word-splits on spaces in
  paths, and scoping a sweep to files that name a type misses
  inference-typed usages. Use `rg -l … -0 | while IFS= read -r -d '' f`
  and let the build report the rest.
- **Treat audits as bug-finding, not rubber-stamping.** The Stage 4
  network audit surfaced the `TracksAdapter` ExPlat leak and an inverted
  `brandName` About-section gate; budget for fixes, not just a green pass.

### Tooling

- **`gh` defaults to the `upstream` (Automattic) remote** in this
  multi-remote repo. Always pass `--repo dwlf/pocket-casts-ios-fork-whitelabel`
  for issues, or work lands on the wrong tracker. The configured PAT can
  create issues but not comment on them.

## Known issues

[`docs/known-issues.md`](docs/known-issues.md), including the
SwiftPM keychain hang on SwiftGen artifact downloads (workaround
required on first clone).
