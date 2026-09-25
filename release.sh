#!/bin/bash
# Publish a dsh release: bump every manifest, commit, tag, and push the tag.
#
# The tag is dsh-v<version> and must match the version the manifests carry,
# because release:verify enforces that pairing and the tag push starts
# release-cli-archive.yml.
set -euo pipefail

case "${1:-}" in
  major | minor | patch | [0-9]*.[0-9]*.[0-9]*) ;;
  *)
    echo "Usage: ./release.sh <major|minor|patch|x.y.z>" >&2
    exit 1
    ;;
esac

pnpm run release:dsh "$1"

VERSION=$(node -p "JSON.parse(require('node:fs').readFileSync('package.json','utf8')).version")
TAG="dsh-v${VERSION}"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

git add -u
git commit -m "release(dsh): ${VERSION}"
git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${BRANCH}"
git push origin "${TAG}"

echo "Released ${TAG} from ${BRANCH}"
