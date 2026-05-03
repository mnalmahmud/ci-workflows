#!/usr/bin/env bash
# apply_patches.sh – Apply *.patch files from the project's patch set to the
#                    target working tree.
#
# Environment variables:
#   PROJECT_KEY  – Key that maps to a directory under projects/ (required)
#   PATCH_SET    – Name of the patch subdirectory to use (default: default)
#   TARGET_DIR   – Path to the checked-out target repo (default: work/target)

set -euo pipefail

PROJECT_KEY="${PROJECT_KEY:?PROJECT_KEY must be set}"
PATCH_SET="${PATCH_SET:-default}"
TARGET_DIR="${TARGET_DIR:-work/target}"

# Resolve patch directory relative to the *orchestrator* repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_DIR="${REPO_ROOT}/projects/${PROJECT_KEY}/patches/${PATCH_SET}"

echo "[apply_patches] PROJECT_KEY : ${PROJECT_KEY}"
echo "[apply_patches] PATCH_SET   : ${PATCH_SET}"
echo "[apply_patches] PATCH_DIR   : ${PATCH_DIR}"
echo "[apply_patches] TARGET_DIR  : ${TARGET_DIR}"

if [[ ! -d "${PATCH_DIR}" ]]; then
  echo "[apply_patches] Patch directory not found; skipping."
  exit 0
fi

# Collect .patch files in sorted order
mapfile -t PATCHES < <(find "${PATCH_DIR}" -maxdepth 1 -name "*.patch" | sort)

if [[ ${#PATCHES[@]} -eq 0 ]]; then
  echo "[apply_patches] No patches found; skipping."
  exit 0
fi

echo "[apply_patches] Applying ${#PATCHES[@]} patch(es)…"

cd "${TARGET_DIR}"

for patch in "${PATCHES[@]}"; do
  echo "[apply_patches] Applying: ${patch}"
  if ! git apply --ignore-whitespace "${patch}"; then
    echo "[apply_patches] ERROR: Failed to apply patch: ${patch}" >&2
    exit 1
  fi
done

echo "[apply_patches] All patches applied successfully."
