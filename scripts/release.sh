#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/release.sh <version>"
  echo "Example: scripts/release.sh 1.2.3"
  exit 1
fi

VERSION="$1"
TAG="v$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists"
  exit 1
fi

git tag "$TAG"
git push origin "$TAG"
