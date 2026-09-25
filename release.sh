#!/bin/bash
# 发布 dsh 版本：按最后一个 tag 递增版本号，打附注 tag 并推送。
# 推送 tag 会触发 .github/workflows/release-cli-archive.yml 打包并上传 zip。
set -euo pipefail

# 获取最新标签，如果没有则设为 dsh-v0.0.0
LAST_TAG=$(git describe --tags --abbrev=0 --match 'dsh-v*' 2>/dev/null || echo "dsh-v0.0.0")
# 去掉前缀和预发布后缀（如 -rc.1），只按 x.y.z 递增
BASE="${LAST_TAG#dsh-v}"
BASE="${BASE%%-*}"
IFS='.' read -r MAJOR MINOR PATCH <<< "${BASE}"

# 根据参数自动递增版本号
case ${1:-} in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Usage: ./release.sh [major|minor|patch]"; exit 1 ;;
esac

NEW_TAG="dsh-v${MAJOR}.${MINOR}.${PATCH}"

# 创建附注标签并推送
git tag -a "${NEW_TAG}" -m "Release ${NEW_TAG}"
git push origin "${NEW_TAG}"

echo "🎉 成功发布新版本: ${NEW_TAG}"
