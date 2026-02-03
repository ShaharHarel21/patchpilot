# PatchPilot

PatchPilot is a macOS app that scans installed applications, compares versions, and surfaces update actions. It also supports self-updates using Sparkle.

## Local build

```bash
scripts/build_dmg.sh
```

Optional overrides:

```bash
SPARKLE_FEED_URL="https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml" \
SPARKLE_PUBLIC_KEY="<public key>" \
APP_VERSION="1.0" \
APP_BUILD="1" \
BUNDLE_ID="com.yourcompany.patchpilot" \
scripts/build_dmg.sh
```

## GitHub Releases auto-update workflow

This repo includes a GitHub Actions workflow that builds a DMG, generates an appcast, and uploads both to the release on every `v*` tag push.

### One-time setup

1. Create a GitHub repo and push this project.
2. Generate Sparkle keys using the Sparkle tools and copy the public key.
3. Add GitHub Actions secrets:
   - `SPARKLE_PUBLIC_KEY`
   - `SPARKLE_PRIVATE_KEY`

### Release

```bash
scripts/release.sh 1.0.0
```

The app will self-update from:

```
https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
```

## Notes

- Without a Developer ID certificate, macOS will warn on first launch and after updates. Use right-click -> Open to allow it.
- Sparkle updates are signed with the private key. Keep it secret.
