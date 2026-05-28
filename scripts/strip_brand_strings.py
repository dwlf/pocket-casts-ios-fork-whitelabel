#!/usr/bin/env python3
"""
Strip "Pocket Casts" and "pocketcasts.com" from the built .app's
localized .strings files, replacing with values from the active
Whitelabel xcconfig (MARKETING_NAME, WEBSITE_SHORT). Runs as a
post-Copy-Bundle-Resources Xcode build phase on Whitelabel
configurations only.

Three file families are processed (all binary property lists):

    *.lproj/Localizable.strings   user-facing UI copy
    *.lproj/InfoPlist.strings     system permission prompts and
                                  bundle/scene names per locale
    *.lproj/Intents.strings       Siri Shortcuts voice-command phrases
                                  ("resume Pocket Casts", etc.)

The English source Info.plist uses $(MARKETING_NAME) substitution
directly (Xcode preprocesses Info.plist at build time), so the root
Info.plist is not touched here. Only the localized InfoPlist.strings
need string-level rewriting because Xcode does not apply build-setting
substitution inside *.lproj/*.strings files.

The source .strings files in podcasts/<lang>.lproj/ are never touched —
they stay as upstream so weekly upstream merges remain conflict-free.

No-ops when MARKETING_NAME == "Pocket Casts" (= unmodified upstream
build) so this script can sit in every build configuration's pipeline
without affecting the upstream scheme.

Environment expected (set by Xcode at build time):
    BUILT_PRODUCTS_DIR  - e.g. .../Build/Products/WhitelabelDebug-iphonesimulator
    EXECUTABLE_NAME     - e.g. podcasts  (app name without .app)
    MARKETING_NAME      - from Whitelabel.base.xcconfig
    WEBSITE_SHORT       - from Whitelabel.base.xcconfig (may be empty)
"""
import os
import plistlib
import sys
from pathlib import Path


def main():
    marketing_name = os.environ.get("MARKETING_NAME", "")
    website_short = os.environ.get("WEBSITE_SHORT", "")

    if marketing_name == "Pocket Casts":
        print("strip_brand_strings: MARKETING_NAME='Pocket Casts' (upstream); no-op")
        return 0

    # Empty MARKETING_NAME would produce "Welcome to !" in UI. Fall back
    # to a generic noun so the white-label default is at least readable.
    brand = marketing_name if marketing_name else "Podcasts"

    built_products_dir = os.environ.get("BUILT_PRODUCTS_DIR")
    executable_name = os.environ.get("EXECUTABLE_NAME")
    if not (built_products_dir and executable_name):
        print("strip_brand_strings: BUILT_PRODUCTS_DIR/EXECUTABLE_NAME not set",
              file=sys.stderr)
        return 1

    app_path = Path(built_products_dir) / f"{executable_name}.app"
    if not app_path.is_dir():
        print(f"strip_brand_strings: app not found at {app_path}", file=sys.stderr)
        return 1

    lproj_strings = sorted(
        list(app_path.glob("*.lproj/Localizable.strings"))
        + list(app_path.glob("*.lproj/InfoPlist.strings"))
        + list(app_path.glob("*.lproj/Intents.strings"))
    )
    print(f"strip_brand_strings: app={app_path} brand={brand!r} "
          f"website={website_short!r} files={len(lproj_strings)}")

    rewritten = 0
    for strings_path in lproj_strings:
        with strings_path.open("rb") as fp:
            data = plistlib.load(fp)
        if not isinstance(data, dict):
            print(f"  skip {strings_path.parent.name}: root is {type(data).__name__}, not dict")
            continue

        changed = False
        for key, value in data.items():
            if not isinstance(value, str):
                continue
            new_value = value.replace("Pocket Casts", brand)
            if website_short:
                new_value = new_value.replace("pocketcasts.com", website_short)
            if new_value != value:
                data[key] = new_value
                changed = True

        if changed:
            with strings_path.open("wb") as fp:
                plistlib.dump(data, fp, fmt=plistlib.FMT_BINARY)
            rewritten += 1

    print(f"strip_brand_strings: rewrote {rewritten}/{len(lproj_strings)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
