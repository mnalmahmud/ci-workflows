#!/usr/bin/env bash
# run_build.sh – Load the project config and execute the appropriate build.
#
# Usage:
#   scripts/run_build.sh <platform>
#
# Positional arguments:
#   platform  – "android" or "linux"
#
# Environment variables (set by the workflow):
#   PROJECT_KEY     – Key that maps to projects/<PROJECT_KEY>/project.env
#   BUILD_VARIANT   – Optional variant: "apk" or "aab" (android only; default uses BUILD_CMD_ANDROID)
#   FLUTTER_CHANNEL – Flutter channel (default: stable); ignored unless USE_FLUTTER=true
#   FLUTTER_VERSION – Flutter version pin (default: any); ignored unless USE_FLUTTER=true
#
# After running this script ARTIFACT_GLOBS is written to $GITHUB_ENV (when
# available) so subsequent workflow steps can reference it.

set -euo pipefail

PLATFORM="${1:?Usage: run_build.sh <android|linux>}"

case "${PLATFORM}" in
  android|linux) ;;
  *) echo "[run_build] ERROR: unsupported platform '${PLATFORM}'. Use 'android' or 'linux'." >&2; exit 1 ;;
esac

PROJECT_KEY="${PROJECT_KEY:?PROJECT_KEY must be set}"
BUILD_VARIANT="${BUILD_VARIANT:-}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_VERSION="${FLUTTER_VERSION:-any}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ENV="${REPO_ROOT}/projects/${PROJECT_KEY}/project.env"

if [[ ! -f "${PROJECT_ENV}" ]]; then
  echo "[run_build] ERROR: project config not found: ${PROJECT_ENV}" >&2
  exit 1
fi

echo "[run_build] Loading project config: ${PROJECT_ENV}"
# shellcheck source=/dev/null
source "${PROJECT_ENV}"

# ── Platform-specific variable selection ──────────────────────────────────────
case "${PLATFORM}" in
  android)
    # Allow variant-specific overrides (apk/aab), falling back to generic android
    if [[ -n "${BUILD_VARIANT}" ]]; then
      _VAR_SUFFIX="_$(echo "${BUILD_VARIANT}" | tr '[:lower:]' '[:upper:]')"
      _BUILD_CMD_VAR="BUILD_CMD_ANDROID${_VAR_SUFFIX}"
      _GLOBS_VAR="ARTIFACT_GLOBS_ANDROID${_VAR_SUFFIX}"
      BUILD_CMD="${!_BUILD_CMD_VAR:-${BUILD_CMD_ANDROID:-}}"
      ARTIFACT_GLOBS="${!_GLOBS_VAR:-${ARTIFACT_GLOBS_ANDROID:-}}"
    else
      BUILD_CMD="${BUILD_CMD_ANDROID:-}"
      ARTIFACT_GLOBS="${ARTIFACT_GLOBS_ANDROID:-}"
    fi
    APT_PACKAGES="${APT_PACKAGES_ANDROID:-}"
    ;;
  linux)
    BUILD_CMD="${BUILD_CMD_LINUX:-}"
    ARTIFACT_GLOBS="${ARTIFACT_GLOBS_LINUX:-}"
    APT_PACKAGES="${APT_PACKAGES_LINUX:-}"
    ;;
esac

export ARTIFACT_GLOBS

# Publish ARTIFACT_GLOBS to the GitHub Actions environment file so that
# subsequent workflow steps can consume it via ${{ env.ARTIFACT_GLOBS }}.
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ARTIFACT_GLOBS=${ARTIFACT_GLOBS}" >> "${GITHUB_ENV}"
fi

echo "[run_build] Platform      : ${PLATFORM}"
echo "[run_build] BUILD_VARIANT : ${BUILD_VARIANT:-<none>}"
echo "[run_build] BUILD_CMD     : ${BUILD_CMD:-<none>}"
echo "[run_build] ARTIFACT_GLOBS: ${ARTIFACT_GLOBS:-<none>}"

# ── Install APT dependencies ───────────────────────────────────────────────────
if [[ -n "${APT_PACKAGES:-}" ]]; then
  echo "[run_build] Installing APT packages: ${APT_PACKAGES}"
  sudo apt-get update -qq
  # shellcheck disable=SC2086
  sudo apt-get install -y --no-install-recommends ${APT_PACKAGES}
fi

# ── Flutter / Dart toolchain setup ────────────────────────────────────────────
USE_FLUTTER="${USE_FLUTTER:-false}"
if [[ "${USE_FLUTTER}" == "true" ]]; then
  echo "[run_build] Setting up Flutter (channel=${FLUTTER_CHANNEL}, version=${FLUTTER_VERSION})"

  FLUTTER_ROOT="${HOME}/flutter"

  if [[ ! -d "${FLUTTER_ROOT}" ]]; then
    git clone --depth=1 --branch "${FLUTTER_CHANNEL}" \
      https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
  fi

  export PATH="${FLUTTER_ROOT}/bin:${PATH}"

  if [[ "${FLUTTER_VERSION}" != "any" ]]; then
    flutter version "${FLUTTER_VERSION}" --no-force-upgrade || true
  fi

  flutter doctor --android-licenses <<< "y" || true
  flutter doctor -v
fi

# ── Android SDK / Gradle env (only when platform is android) ──────────────────
if [[ "${PLATFORM}" == "android" ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-${HOME}/android-sdk}"
  export ANDROID_SDK_ROOT="${ANDROID_HOME}"
fi

# ── Run the build ──────────────────────────────────────────────────────────────
if [[ -z "${BUILD_CMD}" ]]; then
  echo "[run_build] ERROR: no BUILD_CMD defined for platform '${PLATFORM}' in ${PROJECT_ENV}" >&2
  exit 1
fi

TARGET_DIR="${TARGET_DIR:-work/target}"
echo "[run_build] Entering target directory: ${TARGET_DIR}"
cd "${TARGET_DIR}"

echo "[run_build] Running build command: ${BUILD_CMD}"
eval "${BUILD_CMD}"

echo "[run_build] Build completed successfully."
