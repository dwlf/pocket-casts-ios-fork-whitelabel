# White-label Pocket Casts fork -- pre-authorized and unaffiliated

> **Not affiliated with, endorsed by, or sponsored by Automattic, Inc.
> or Pocket Casts.** This is an independent fork of the open-source
> [pocket-casts-ios](https://github.com/Automattic/pocket-casts-ios)
> codebase, used under MPL-2.0. "Pocket Casts" and the Pocket Casts
> logo are trademarks of Automattic, Inc.; their use in this
> repository is limited to factual references to the upstream project
> from which this fork derives.

An iOS podcast player. Brand- and integration-stripped fork of
pocket-casts-ios.

[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-black)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-ios%20%7C%20watchos-lightgrey)
![Xcode](https://img.shields.io/badge/Xcode-26.4%2B-informational)

## What this is

The full pocket-casts-ios codebase with all Pocket Casts/Automattic
branding, server endpoints, and credentials extracted to a config
layer. Build it as-is and you get an installable iOS app that plays
local audio. Plug in your own server URLs and brand assets via
`config/whitelabel/whitelabel.json` and the same code talks to your
infrastructure with your branding.

Swift sources are unchanged from upstream wherever possible — brand
and server values are read through a generated `WhitelabelConfig`
struct, not hard-coded.

Batteries included — but just the one. The empty-config build runs out
of the box: install it, add podcasts by RSS or Apple Podcasts link, and
play. The server-backed half of the app (sync, Discover, search,
accounts, IAP) stays dark until you supply a backend — see *What this is
not* below.

## What this is not

- **A working podcast cloud service.** The app launches and plays
  local audio. Cross-device sync, account login, the Discover feed,
  podcast search, sharing, and IAP/subscription features no-op
  until you supply a backend that speaks the Pocket Casts server
  protocol.
- **A drop-in replacement for Pocket Casts.** Bundle ID, signing
  identity, and all user-facing branding are yours to supply.

## Relationship to upstream

- Upstream: <https://github.com/Automattic/pocket-casts-ios> (`trunk`)
- Upstream's original README is preserved verbatim at
  [`README.upstream.md`](README.upstream.md) for provenance.
- This fork tracks upstream `trunk` on a weekly merge cadence.

## Prerequisites

- macOS (tested on 26.5)
- Xcode 26.4+ at `/Applications/Xcode.app`
- iOS 26 + watchOS 26 simulator runtimes
- Ruby 3.2.2 with `bundler`
- `make`

First-clone setup gotchas (including the SwiftPM keychain hang on
SwiftGen artifact downloads):
[`docs/known-issues.md`](docs/known-issues.md).

## Quick start

```bash
# One-time per machine
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
xcodebuild -downloadPlatform watchOS

# One-time per clone
make install_dependencies
make external_contributor

# Build the whitelabel for simulator
make build_whitelabel
```

## More

- **[FORK.md](FORK.md)** — fork architecture, configuration keys,
  upstream-sync workflow, how to build a branded product on top,
  PR-scope discipline. Read this before contributing.
- [`README.upstream.md`](README.upstream.md) — upstream's original
  README, preserved verbatim.

## License

[MPL-2.0](LICENSE.md), inherited from upstream.
[`FORK.md`](FORK.md) covers the implications when building on top.
