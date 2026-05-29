# How to Contribute

This repository is a brand- and integration-stripped fork of
[Automattic/pocket-casts-ios](https://github.com/Automattic/pocket-casts-ios),
licensed under MPL-2.0 and unaffiliated with Automattic. It exists to
make the underlying podcast-player codebase reusable as a starting point
for differently-integrated products under unaffiliated branding. See
[`FORK.md`](FORK.md) for the architecture and the decoupling layer.

Because of that split, **where a change belongs depends on what it
touches.**

## Changes that belong upstream

Work on the podcast app itself goes to
[Automattic/pocket-casts-ios](https://github.com/Automattic/pocket-casts-ios),
not here — this fork merges upstream in on a weekly cadence
(`make sync-upstream`). That includes:

- Bug fixes in the playback engine, downloader, sync engine, podcast
  parser, episode UI, etc.
- New features in the app itself
- Localization and translation improvements
- Performance work

Routing app-level work upstream keeps it in front of the widest audience
and keeps this fork's diff against upstream small.

## Changes that belong here

PRs to this fork should be limited to the decoupling layer:

- The `WhitelabelConfig` mechanism and its consumers
- The xcconfig matrix, schemes, and build configurations
- The asset and strings overlay infrastructure
- Upstream-sync tooling and conflict playbooks
- Documentation

If a change is in scope here but also fixes a bug that exists upstream,
file it upstream first, then merge the fix down via `make sync-upstream`.

## Reporting bugs and suggesting changes

Open an issue on this fork's tracker:
[dwlf/pocket-casts-ios-fork-whitelabel/issues](https://github.com/dwlf/pocket-casts-ios-fork-whitelabel/issues).
Include enough detail to reproduce; screenshots help. For bugs in the
podcast app itself (not the decoupling layer), prefer the
[upstream tracker](https://github.com/Automattic/pocket-casts-ios/issues)
so the fix reaches everyone.

Security vulnerabilities follow a separate, private path — see
[`SECURITY.md`](SECURITY.md).

## Submitting code changes

All code contributions pass through pull requests against `trunk`.
Before anything else, please read the
[Code of Conduct](CODE-OF-CONDUCT.md) — we expect all participants to
uphold it.

- State your intent on an issue before starting significant work, so
  effort isn't duplicated.
- Keep one logical change per PR; describe what the diff does now, not
  discarded approaches.
- Run `make format` and the relevant tests before opening the PR.
- A PR needs one approving review before it merges to the base branch.
