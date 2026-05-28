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

1. `podcasts/Whitelabel/WhitelabelConfig.tpl` — Swift template
   with `%{key_name}` placeholders.
2. `config/whitelabel/whitelabel.json` — flat key/value JSON with
   one entry per template placeholder.
3. `scripts/generate_whitelabel_config.sh` — Xcode build phase
   script. Calls `ruby podcasts/Credentials/replace_secrets.rb -i
   WhitelabelConfig.tpl -s whitelabel.json` to produce
   `podcasts/Whitelabel/WhitelabelConfig.swift`.

The build phase runs before "Compile Sources" on every target that
imports `WhitelabelConfig`.

### What consumes `WhitelabelConfig`

| File | What it reads |
|---|---|
| `Modules/Sources/PocketCastsServer/Public/Sharing/Structs/ServerConstants.swift` | All server URLs |
| `podcasts/Strings+L10n.swift` | Brand name, support email, social handle, website |
| `podcasts/SocialsHelper.swift` | Social handle |
| `podcasts/InAppPurchases/IAPTypes.swift` | IAP product IDs |
| `podcasts/LogsView.swift` | Support email |
| `podcasts/LegalAndMoreView.swift`, `OnlineSupportController.swift`, `StatusPageViewModel.swift` | Support / legal URLs |

The IAP refactor restructures `IAPProductID` from a raw-value enum
to a struct (raw-value enums require compile-time strings).

### What is *not* read from `WhitelabelConfig`

Bundle-ID Swift references (≈20 call sites) are derived from
`Bundle.main.bundleIdentifier` instead — minimal diff against
upstream, no config plumbing needed. App-group identifiers (which
must match `.entitlements` files exactly) are read from
`SharedConstants.GroupUserDefaults.groupContainerId`, populated
from the `APP_GROUP_ID` xcconfig variable.

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
- App-group ID derived from xcconfig (`APP_GROUP_ID`) with
  `.entitlements` files using `$(APP_GROUP_ID)` substitution.
- Asset catalogs (`AppIcon`, `Onboarding`, `Subscription`, etc.)
  overlaid by neutral variants under `podcasts/Whitelabel/`.
  Selection per build configuration via
  `EXCLUDED_SOURCE_FILE_NAMES`.
- `Localizable.strings` brand-stripped at build time (post-Copy
  Bundle Resources phase, via `scripts/strip_brand_strings.sh`).
- End-of-Year feature (`podcasts/End of Year/`) excluded from
  whitelabel builds.
- Alternate app icons trimmed to default + dark; Pocket Casts
  brand alternates remain only in the inherited upstream scheme.
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

## Known issues

[`docs/known-issues.md`](docs/known-issues.md), including the
SwiftPM keychain hang on SwiftGen artifact downloads (workaround
required on first clone).
