#!/bin/bash
# 发布 dsh 版本：按最后一个 tag 递增版本号，写进 workspace 清单并提交，
# 再打附注 tag 推送。推送 tag 会触发 .github/workflows/release-cli-archive.yml
# 打包并上传 zip，其中的 CLI 用清单版本报告 `dsh --version`。
#
# 只打 tag 不改清单，zip 里的 CLI 会一直报告旧版本，Docker 工作流的
# “镜像版本与 tag 一致”校验就会失败，因此清单必须先落版本。
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

# 以 tag 而不是清单算出的版本为准：清单落后于 tag 时，按清单递增会重发已存在的版本。
VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="dsh-v${VERSION}"

if git rev-parse -q --verify "refs/tags/${NEW_TAG}" >/dev/null; then
  echo "标签 ${NEW_TAG} 已存在，请先处理该版本"
  exit 1
fi

# 写入 workspace 根、各包与各应用的清单并提交
pnpm release:dsh "${VERSION}"

# 创建附注标签并推送
git tag -a "${NEW_TAG}" -m "Release ${NEW_TAG}"
git push origin HEAD "${NEW_TAG}"

echo "🎉 成功发布新版本: ${NEW_TAG}"
