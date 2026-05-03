#!/usr/bin/env bash
# checkout_target.sh – Clone a target repository and check out the requested ref.
#
# Environment variables (all required unless noted):
#   TARGET_REPO   – GitHub repo in "owner/name" format (required)
#   TARGET_REF    – Branch, tag, or SHA to check out (default: main)
#   WORKDIR       – Destination directory (default: work/target)
#   TARGET_REPO_TOKEN – Optional PAT for private repos; omit for public repos

set -euo pipefail

TARGET_REPO="${TARGET_REPO:?TARGET_REPO must be set (e.g. owner/name)}"
TARGET_REF="${TARGET_REF:-main}"
WORKDIR="${WORKDIR:-work/target}"

if [[ -z "${TARGET_REPO_TOKEN:-}" ]]; then
  CLONE_URL="https://github.com/${TARGET_REPO}.git"
  echo "[checkout_target] Cloning public repo: ${CLONE_URL}"
else
  CLONE_URL="https://x-access-token:${TARGET_REPO_TOKEN}@github.com/${TARGET_REPO}.git"
  echo "[checkout_target] Cloning private repo: https://github.com/${TARGET_REPO}.git (token auth)"
fi

echo "[checkout_target] Destination : ${WORKDIR}"
echo "[checkout_target] Ref         : ${TARGET_REF}"

# Remove stale checkout if present (e.g. re-run on same runner)
if [[ -d "${WORKDIR}" ]]; then
  echo "[checkout_target] Removing existing directory: ${WORKDIR}"
  rm -rf "${WORKDIR}"
fi

git clone --no-tags --depth=1 "${CLONE_URL}" "${WORKDIR}"

cd "${WORKDIR}"

# fetch/checkout the exact ref (handles branches, tags and full SHAs)
git fetch --depth=1 origin "${TARGET_REF}"
git checkout FETCH_HEAD

echo "[checkout_target] Done. Working tree at: $(pwd)"
echo "[checkout_target] HEAD: $(git rev-parse HEAD)"
