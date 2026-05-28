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
