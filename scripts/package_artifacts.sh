#!/usr/bin/env bash
# package_artifacts.sh – Collect build outputs and optionally package them into
#                        a .tar.gz archive before the workflow uploads them.
#
# Environment variables:
#   ARTIFACT_GLOBS – Space-separated glob patterns relative to TARGET_DIR
#   ARTIFACT_NAME  – Base name for the archive (default: artifacts)
#   TARGET_DIR     – Path to the built target repo (default: work/target)
#   PACKAGE_DIR    – Directory where collected files are staged (default: work/artifacts)
#   PACKAGE_TAR    – When "true" the staged files are packed into a .tar.gz
#                    (default: false)

set -euo pipefail

ARTIFACT_GLOBS="${ARTIFACT_GLOBS:?ARTIFACT_GLOBS must be set}"
ARTIFACT_NAME="${ARTIFACT_NAME:-artifacts}"
TARGET_DIR="${TARGET_DIR:-work/target}"
PACKAGE_DIR="${PACKAGE_DIR:-work/artifacts}"
PACKAGE_TAR="${PACKAGE_TAR:-false}"

echo "[package_artifacts] TARGET_DIR    : ${TARGET_DIR}"
echo "[package_artifacts] ARTIFACT_GLOBS: ${ARTIFACT_GLOBS}"
echo "[package_artifacts] PACKAGE_DIR   : ${PACKAGE_DIR}"
echo "[package_artifacts] PACKAGE_TAR   : ${PACKAGE_TAR}"

mkdir -p "${PACKAGE_DIR}"

# Collect all matching files
FILE_COUNT=0
for pattern in ${ARTIFACT_GLOBS}; do
  # Expand glob relative to TARGET_DIR
  while IFS= read -r -d '' file; do
    dest="${PACKAGE_DIR}/$(basename "${file}")"
    echo "[package_artifacts] Staging: ${file} -> ${dest}"
    cp -r "${file}" "${dest}"
    (( FILE_COUNT++ )) || true
  done < <(find "${TARGET_DIR}" -path "${TARGET_DIR}/${pattern}" -print0 2>/dev/null || true)
done

if [[ ${FILE_COUNT} -eq 0 ]]; then
  echo "[package_artifacts] WARNING: No artifacts matched the configured globs." >&2
fi

echo "[package_artifacts] Staged ${FILE_COUNT} artifact(s) to ${PACKAGE_DIR}"

# Optionally pack into a .tar.gz
if [[ "${PACKAGE_TAR}" == "true" ]]; then
  ARCHIVE="${ARTIFACT_NAME}.tar.gz"
  echo "[package_artifacts] Creating archive: ${ARCHIVE}"
  tar -czf "${ARCHIVE}" -C "${PACKAGE_DIR}" .
  echo "[package_artifacts] Archive created: ${ARCHIVE}"
fi
