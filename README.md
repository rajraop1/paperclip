# ClippyPet for macOS

A tiny native AppKit desktop pet inspired by the classic Microsoft Office Assistant. Clippy floats transparently above your desktop without a normal window, Dock icon, speech balloon, unsolicited text, or sound. The only menu appears when you right-click him.

## Features

- Drag Clippy anywhere; his position is remembered between launches.
- Forty-five random animations while the window itself remains stationary.
- Left-click to change the animation immediately.
- Right-click for **Change Animation** and **Close Clippy**.
- A new automatic animation begins two seconds after the previous one finishes.
- Option-double-click to quit.
- Reduced Motion uses a quieter animation pool.
- Separate native builds for Apple Silicon and Intel Macs.
- Minimum deployment target: macOS 13 Ventura.

## Requirements

- macOS 13 or later
- Apple Command Line Tools or Xcode (`xcode-select --install`)
- Internet access once to fetch the untracked sprite atlas

## Set up and build

```bash
./scripts/fetch-assets.sh
./scripts/build.sh all
```

This creates:

- `dist/ClippyPet-arm64.app` for Apple Silicon
- `dist/ClippyPet-x86_64.app` for Intel Macs

Open the package matching your Mac. These local builds are ad-hoc signed and are not notarized for external distribution.

## Verify

Run architecture, deployment-target, bundle, and signature checks:

```bash
./scripts/verify.sh
```

From a normal desktop Terminal, include the native GUI smoke test with:

```bash
./scripts/verify.sh --launch
```

The GUI check launches the build native to the current Mac. Run it once on Intel and once on Apple Silicon to launch-test both packages. GitHub Actions cross-compiles and verifies both packages without launching the GUI.

## Repository layout

- `Sources/ClippyPet/` — AppKit application and animation engine
- `Resources/Info.plist` — application bundle metadata
- `scripts/` — asset setup, build, and verification tools
- `.github/workflows/build.yml` — Intel and Apple Silicon CI

## Artwork and redistribution

`Resources/map.png` is intentionally excluded from Git. The setup script downloads the known atlas and verifies its SHA-256 checksum before use.

The Clippy identity, artwork, and source animation data are Microsoft-owned and are not covered by the upstream software license. Excluding the atlas from Git does not itself grant permission to publish the remaining Microsoft-derived material. This project is intended for private development and evaluation unless you have the necessary permission or replace those elements with original material.

This project is not affiliated with, endorsed by, or sponsored by Microsoft. No source-code license has been selected; choose one before inviting third-party reuse or contributions. Review [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before making a repository or build public.
