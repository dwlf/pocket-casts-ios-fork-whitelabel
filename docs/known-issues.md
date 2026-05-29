# Known issues

First-clone and build-environment gotchas, with workarounds.

## SwiftPM keychain hang on SwiftGen artifact downloads

**Symptom.** On first build (e.g. `make build` or `make build_whitelabel`)
after a fresh clone, the L10n prebuild phase appears to hang
indefinitely. `xcodebuild` log stops advancing. `ps` shows
`swift-package` at 0.0% CPU. `lsof -p <pid>` shows no TCP sockets.

**Cause.** The L10n prebuild phase runs `make generate_code`, which
invokes `swift package plugin … generate-code-for-resources`. That
nested SwiftPM invocation downloads two binary artifact bundles from
GitHub releases (`SwiftGen` and `SwiftLint`). SwiftPM's
`AuthorizationProvider` consults the macOS Keychain for download
credentials, and securityd blocks on an unanswered SecurityAgent
authorization dialog — `swift-package` stays parked in
`SecItemCopyMatching → mach_msg`.

**Workaround.** Run the codegen once standalone with keychain and
netrc disabled. SwiftPM caches the artifact bundles locally;
subsequent build-phase invocations find them cached and never
re-fetch, never touching the keychain.

```bash
cd BuildTools
SDKROOT=$(xcrun --sdk macosx --show-sdk-path) \
  swift package --disable-keychain --disable-netrc plugin \
    --allow-writing-to-directory .. \
    --allow-writing-to-package-directory \
    generate-code-for-resources --config ../swiftgen.yml
```

Verify artifacts cached:

```bash
ls BuildTools/.build/artifacts/swiftgenplugin/swiftgen
ls BuildTools/.build/artifacts/swiftlintplugins/SwiftLintBinary
```

After this one-time workaround, normal `make build` and
`make build_whitelabel` work without intervention.

## Xcode platform / simulator runtime missing

**Symptom.** `xcodebuild` fails with:

```
Unable to find a destination matching the provided destination specifier:
  { generic:1, platform:iOS Simulator }

Ineligible destinations for the "pocketcasts" scheme:
  { platform:iOS, ... error:iOS 26.5 is not installed. … }
```

**Cause.** Fresh Xcode 26+ installs do not include the iOS or watchOS
simulator runtimes by default. The `pocketcasts` scheme embeds a
watchOS Watch App target, so both runtimes are required.

**Workaround.** Download both platform runtimes (one-time per Xcode
version, ~12 GB total):

```bash
xcodebuild -downloadPlatform iOS
xcodebuild -downloadPlatform watchOS
```

The downloads work without `sudo`.

## `plutil -extract` overwrites the input file

**Symptom.** After running a diagnostic like
`plutil -extract CFBundleIdentifier raw "$APP/Info.plist"` against a
built app's Info.plist, the file shrinks to a single value and the
rest of the keys disappear. Subsequent builds and runs may behave
strangely until a `make clean` + rebuild restores the file.

**Cause.** `plutil -extract` without an explicit `-o -` (stdout) or
`-o <other-path>` writes the extracted value **back to the input
file**, replacing the whole Info.plist with the extracted fragment.
This is documented but easy to miss; many introductions to plutil
show `-extract … raw` examples without the output redirect.

**Workaround.** Always pass `-o -` to send extraction to stdout:

```bash
# Safe:
plutil -extract CFBundleIdentifier raw -o - "$APP/Info.plist"

# Even safer: use plutil -p for read-only inspection
plutil -p "$APP/Info.plist" | grep CFBundleIdentifier
```

`plutil -p` is purely read-only and is the right tool for build
verification scripts.

## Xcode license / xcode-select / first-launch components

**Symptom.** `xcodebuild` fails with one of:

- `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`
- `You have not agreed to the Xcode license agreements.`
- Plug-in load failures referencing `IDESimulatorFoundation` and
  `DVTDownloads` symbol-not-found errors.

**Cause.** Fresh macOS or Xcode install without the one-time
configuration steps complete.

**Workaround.** One time per machine:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

The last step installs additional Xcode components (~1–3 minutes) and
clears stale `IDESimulatorFoundation` plug-in load failures.

## Deferred no-backend brand/upsell surfaces

The no-backend degradation work (`fork#3`) gated the reachable
Pocket Casts brand-art and subscription-upsell surfaces on
`WhitelabelConfig.hasBackend`. The following surfaces are **not yet
gated**. None are reachable in a normal public (empty-config) build —
they require a login, an active subscription, or a seasonal trigger
that the empty backend cannot produce — so they are deferred rather
than leaks in the shipped experience. A branded fork *with* a backend
runs the full upstream behaviour and is unaffected.

- **Discover detail view controllers** (category / list / network /
  collection summaries): their loading spinners do not stop on a
  failed fetch, but they are only reachable *through* the Discover
  tab, which already shows a graceful "Unable to load" state, so the
  spinners cannot be reached without a backend.
- **Share-surface brand art** (`PocketCastsLogoPill`,
  `HowToShareActionImageView`, `ShareProfileCardView`,
  `ShareDestination`): the Pocket Casts mark/wordmark appears on
  clip/profile-card sharing UI. Sharing depends on the sharing
  backend, so these are unreachable without a configured host.
- **Plus/Patron badges, referral cards, promotion redemption,
  Account-screen upgrade rows** (`SubscriptionBadge`,
  `ReferralCardView`, `PromotionViewController`,
  `AccountViewController` upgrade rows): all require a logged-in or
  subscribed account, which is impossible without a backend.
- **End-of-Year stories paywall and `eoy25_pc_logo` / `logo_pill`
  art**: seasonal, and the End-of-Year feature is already excluded
  from white-label builds.
- **Widget brand art** (`logo_red_*`, `logo_white_*` in
  `WidgetExtension`): widgets render their own Pocket Casts marks; a
  branded fork supplies its own widget assets.

When adding a backend-bearing branded fork, none of these need action.
If a future build makes any of them reachable without a backend, gate
them on `WhitelabelConfig.hasBackend` the same way `fork#3` did.

## Locally-ingested feeds: backend-build re-parse not wired

Refresh for locally-ingested feeds is wired for no-backend builds
(`fork#11`): when `WhitelabelConfig.hasBackend == false`, both refresh
entry points re-parse feeds on-device via the
`ServerSyncDelegate.refreshLocalFeeds` seam instead of the cache host —
`RefreshManager` for library-wide triggers (grid pull-to-refresh,
background, foreground) and `PodcastFeedViewModel.reloadFeed` for the
per-podcast detail-screen pull-to-refresh. The deterministic episode UUIDs
make the re-parse idempotent — existing episodes are matched and skipped,
only new ones are inserted.

The remaining gap is **backend builds with manually-pasted RSS feeds**.
`SearchResultsModel.search(term:)` routes any pasted URL to
`FeedIngestion.ingest` with no `hasBackend` gate, so a backend-bearing fork
can hold a locally-ingested podcast the cache host doesn't know about.
Those podcasts are not re-parsed (the `hasBackend` gate keeps backend
builds on the cache-host path), so they never gain new episodes.

To cover that case (recipe, not yet implemented — inert in this no-backend
build, so deferred under YAGNI):

1. **Detect** locally-ingested podcasts. There is no `isLocal` column;
   recompute the deterministic UUID from `podcastUrl` and compare to the
   stored `uuid`:
   `FeedIngestion.deterministicUUID(from: podcast.podcastUrl) == podcast.uuid`.
   Locally-ingested podcasts match (their UUID *is* `SHA-256(feedURL)`);
   cache-host podcasts have server-random UUIDs that don't.
2. **Filter** inside `ServerSyncManager.refreshLocalFeeds` to only the
   podcasts that pass the detector (no-backend: all pass, harmless;
   backend: just the local subset). Detection must live here, not in
   `RefreshManager`, because `deterministicUUID` is in the app target and
   the Server module can't reach it.
3. **Wire** `RefreshManager`'s backend path to call
   `syncDelegate.refreshLocalFeeds(podcasts:)` alongside
   `MainServerHandler.shared.refresh`, and post `manyEpisodesChanged` after
   inserts so the open UI reloads (as `fork#11` did with `podcastUpdated`),
   without double-firing the cache-host refresh notifications.

The detector is a **correctness gate, not an optimization**: running
`FeedIngestion.refresh` on a cache-host podcast would mint deterministic
episode UUIDs that differ from the server-assigned ones, duplicating every
episode. Only podcasts whose episodes already use the deterministic scheme
may be re-parsed.

Cover art *is* shown: `ImageManager.podcastUrl` prefers the podcast's
`imageURL` (set from the feed's `<itunes:image>`) over the cache-host
CDN URL under `#if WHITELABEL`.
