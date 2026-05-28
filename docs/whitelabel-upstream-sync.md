# Upstream-sync workflow

This fork tracks
[`Automattic/pocket-casts-ios`](https://github.com/Automattic/pocket-casts-ios)
`trunk` on a weekly merge cadence. This document covers the
mechanics, expected conflicts, and per-file resolution patterns.

## Setup (one-time per clone)

```bash
git remote add upstream https://github.com/Automattic/pocket-casts-ios.git
```

Verify:

```bash
git remote -v
# upstream  https://github.com/Automattic/pocket-casts-ios.git (fetch)
# upstream  https://github.com/Automattic/pocket-casts-ios.git (push)
# origin    <your fork remote>                                  (fetch)
# origin    <your fork remote>                                  (push)
```

## Weekly sync

```bash
make sync-upstream      # fetches upstream/trunk and merges into local trunk
make verify-whitelabel  # builds Whitelabel Debug end-to-end
git push origin trunk   # only if verify passed
```

`make sync-upstream` runs `git fetch upstream trunk && git merge --no-ff upstream/trunk`.
On conflict, it stops and prints the conflicted files. Resolve
per the playbooks below, then `git add` and `git merge --continue`.

## Cadence

**Weekly.** Pocket Casts iOS lands ~10–20 PRs per week. Monthly
merges accumulate enough drift that resolving conflicts becomes a
focused workday; weekly keeps each cycle to under 30 minutes.

The pre-push hook enforces `make verify-whitelabel` so you cannot
push an unbuildable merge to origin.

## Expected conflict shape

Given the WhitelabelConfig-based decoupling, conflicts cluster in a
small predictable set. The vast majority of upstream PRs touch files
the fork does not modify — no conflict.

| File | Conflict trigger | Frequency |
|---|---|---|
| `Modules/Sources/PocketCastsServer/Public/Sharing/Structs/ServerConstants.swift` | Upstream adds or renames a URL constant | Common |
| `podcasts.xcodeproj/project.pbxproj` | Upstream adds a build configuration, target, or file reference | Common |
| `podcasts/Strings+L10n.swift` (lines 8–14, proper-noun block) | Upstream edits any of `pocketCasts`, `socialHandle`, `websiteShort`, `supportErrorMsg` | Rare |
| `podcasts/InAppPurchases/IAPTypes.swift` | Upstream changes the `IAPProductID` enum (case added/renamed/removed, helper methods edited) | Rare |
| `podcasts/SharedConstants.swift` | Upstream changes `groupContainerId` or adds new shared constants | Rare |

## Per-file resolution playbook

### `ServerConstants.swift`

The fork wraps every hard-coded URL in a `WhitelabelConfig.*URL`
reference. When upstream changes the file:

1. Accept upstream verbatim:
   ```bash
   git checkout --theirs Modules/Sources/PocketCastsServer/Public/Sharing/Structs/ServerConstants.swift
   ```
2. Re-apply the WhitelabelConfig wrapping. For each
   `production() ? "https://x.pocketcasts.com/…" : "https://x.pocketcasts.net/…"`
   pattern, rewrite as:
   ```swift
   production() ? WhitelabelConfig.xProductionURL : WhitelabelConfig.xStagingURL
   ```
3. If upstream added a *new* URL constant, also add the corresponding
   key to:
   - `podcasts/Whitelabel/WhitelabelConfig.tpl`
   - `config/whitelabel/whitelabel.json` (empty default)
4. `make build_whitelabel` to verify.
5. `git add Modules/Sources/PocketCastsServer/Public/Sharing/Structs/ServerConstants.swift podcasts/Whitelabel/WhitelabelConfig.tpl config/whitelabel/whitelabel.json`
6. `git merge --continue`.

### `podcasts.xcodeproj/project.pbxproj`

The fork adds three configurations (`WhitelabelDebug`,
`WhitelabelStagingDebug`, `WhitelabelRelease`) at the end of each
target's `XCConfigurationList`. When upstream changes the file:

1. Open the conflict in your merge tool. Conflicts almost always
   look like: upstream added something in one region of a list, the
   fork added Whitelabel configurations at the end of the same list.
2. Accept both — keep upstream's addition AND the fork's
   Whitelabel-* configurations.
3. Verify with `xcodebuild -project podcasts.xcodeproj -list` —
   should report all upstream configurations plus the three
   Whitelabel ones for every target.
4. `make build_whitelabel` and `make build` (the upstream scheme)
   to verify both still work.
5. `git add podcasts.xcodeproj/project.pbxproj && git merge --continue`.

### `Strings+L10n.swift`

The fork rewrites lines 8–14 to read from `WhitelabelConfig`. When
upstream edits any of these lines:

1. Accept upstream verbatim.
2. Re-apply the fork's `WhitelabelConfig` reads to the same lines.
3. If upstream added a new proper-noun constant, decide:
   - Does it need to be brand-swappable? → Add a `WhitelabelConfig`
     key, wrap the constant.
   - Is it a proper noun of an *unrelated* company (e.g. another
     SDK, Apple service)? → Leave as-is.
4. `git add` and `git merge --continue`.

### `IAPTypes.swift`

The fork converts `IAPProductID` from a raw-value enum to a struct.
When upstream changes the enum:

1. Accept upstream verbatim.
2. Re-apply the struct conversion to any new cases.
3. If upstream added new helper methods (`renewalPrompt`,
   `isYearlyProduct`, etc.), update the struct shape to match.
4. `make build_whitelabel` to verify (Swift compiler will flag
   missing cases).
5. `git add` and `git merge --continue`.

### `SharedConstants.swift`

The fork reads `groupContainerId` from xcconfig (`APP_GROUP_ID`).
When upstream changes the file:

1. Accept upstream's structure.
2. Re-apply the `WhitelabelConfig.appGroupId` (or xcconfig-derived)
   value for `groupContainerId`.
3. If upstream added other shared constants, leave them alone unless
   they reference `au.com.shiftyjelly.pocketcasts` — in which case
   apply the same Bundle.main-derived pattern used in §24 of the
   plan.

## Verification

After every merge:

```bash
make verify-whitelabel  # required by pre-push hook
make build              # also verify upstream scheme still builds
```

If `make build` fails but `make build_whitelabel` succeeds, the
upstream merge introduced something that needs Automattic-internal
secrets — that's expected and not a blocker for pushing the
whitelabel.

If `make build_whitelabel` fails, do NOT push. Either fix the
issue forward (preferred) or:

```bash
git merge --abort  # if still mid-merge
# or
git reset --hard HEAD~1  # if merge committed but verify failed
```

## Upstream pbxproj changes: avoid pbxproj libraries

When `git merge upstream/trunk` brings in changes to
`podcasts.xcodeproj/project.pbxproj` — especially changes to
`XCConfigurationList` entries, `PBXNativeTarget.fileSystemSynchronizedGroups`,
or any of the `PBXFileSystemSynchronized*` object types — **do not reach
for a pbxproj library to "fix up" the merge**:

- The Ruby `xcodeproj` gem (1.27.0, current as of this writing)
  silently drops `PBXFileSystemSynchronizedBuildFileExceptionSet` entries
  on round-trip — the project compiles in Xcode after re-save but loses
  per-file build exceptions, breaking some targets.
- The Python `pbxproj` package (4.3.3) drops both
  `PBXFileSystemSynchronizedBuildFileExceptionSet` AND any PBX-File
  reference with a non-hex UUID (the project uses some).

Both libraries pre-date Xcode 16's `objectVersion = 74` and have not
caught up. Watch the upstream
[CocoaPods/Xcodeproj](https://github.com/CocoaPods/Xcodeproj) issue
tracker for the fix.

For now:

- **Resolve textual merge conflicts** in `podcasts.xcodeproj/project.pbxproj`
  by hand. Most are append-at-end-of-list conflicts (configurations,
  buildConfigurations array entries, fileSystemSynchronizedGroups) and
  resolve trivially "accept both".
- **If you need to add a new configuration / target / sync group**
  to mirror an upstream change, open `podcasts.xcodeproj` in Xcode and
  use the UI. Xcode itself round-trips its own format faithfully; any
  third-party tooling currently does not.
- **For one-line attribute changes** (e.g. swapping
  `baseConfigurationReferenceRelativePath = X` to
  `Y` on an existing block), a focused text-edit script is safe —
  the failure mode is library-driven block-cloning, not single-line
  attribute swaps.

## When the playbook breaks

If a file outside the predictable set shows a real conflict —
not just a `+/-` whitespace difference, but actual content the fork
modified that upstream also modified — that's a signal the fork has
drifted in a way the architecture is supposed to prevent. Stop, read
the conflict carefully, and consider whether the fork-side change
belongs upstream (where it would avoid the conflict entirely on
future merges).
