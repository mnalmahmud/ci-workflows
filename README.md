# ci-workflows

A **centralised build-orchestrator** repository.
It runs GitHub Actions workflows that check out other repositories (targets),
optionally apply patch sets stored here, execute project-defined build
commands, and upload the resulting artifacts — all without requiring any
GitHub Actions configuration in the target repositories themselves.

---

## Table of contents

1. [What this repo does](#what-this-repo-does)
2. [Running a build](#running-a-build)
   - [Android APK](#android-apk)
   - [Android App Bundle (AAB)](#android-app-bundle-aab)
   - [Linux amd64](#linux-amd64)
   - [Linux arm64](#linux-arm64)
3. [Adding a new project](#adding-a-new-project)
4. [Patch sets](#patch-sets)
5. [Authentication for private repos](#authentication-for-private-repos)
6. [Android signing](#android-signing)
7. [Repository structure](#repository-structure)
8. [Scripts reference](#scripts-reference)

---

## What this repo does

`ci-workflows` acts as a central build orchestrator for multiple source
repositories.  You trigger a workflow with a handful of inputs, and it:

1. Checks out this orchestrator repo (to get scripts and project configs).
2. Clones the **target repo** at the specified ref into `work/target/`.
3. Applies any `.patch` files found under
   `projects/<project_key>/patches/<patch_set>/` (skipped gracefully when none
   exist).
4. Runs the build command(s) declared in
   `projects/<project_key>/project.env`.
5. Stages the build outputs and uploads them as a GitHub Actions artifact.

---

## Running a build

All workflows are triggered manually via **Actions → select workflow →
Run workflow**.

### Common inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `target_repo` | ✅ | — | `owner/name` of the repo to build |
| `target_ref` | | `main` | Branch, tag, or SHA |
| `project_key` | ✅ | — | Selects `projects/<project_key>/` — use `username-reponame` format |
| `apply_patches` | | `true` | Apply the configured patch set |
| `patch_set` | | `default` | Patch set sub-directory name |
| `artifact_name` | | varies | Name of the uploaded artifact |
| `use_flutter` | | `false` | Set up Flutter via `subosito/flutter-action` before building |
| `flutter_channel` | | `stable` | Flutter channel (used when `use_flutter=true`) |
| `flutter_version` | | `any` | Flutter version pin, e.g. `3.24.0` (used when `use_flutter=true`) |

### Android APK

Workflow: **`.github/workflows/build-android-apk.yml`**

Builds an APK using the command defined in `BUILD_CMD_ANDROID_APK` (or
`BUILD_CMD_ANDROID` as fallback) in the project config.

### Android App Bundle (AAB)

Workflow: **`.github/workflows/build-android-apk-bundle.yml`** (builds an AAB — Android App Bundle, the upload format for Google Play)

Builds an AAB using `BUILD_CMD_ANDROID_AAB` (or `BUILD_CMD_ANDROID` fallback).

### Linux amd64

Workflow: **`.github/workflows/build-linux-amd64.yml`**

Runs on `ubuntu-latest` (x86_64). Artifacts are packaged into a `.tar.gz`.

### Linux arm64

Workflow: **`.github/workflows/build-linux-arm64.yml`**

Runs on `ubuntu-24.04-arm` (AArch64). Artifacts are packaged into a `.tar.gz`.

---

## Adding a new project

**Project key convention:** replace the `/` in `owner/name` with `-`.
Example: `acme/my-app` → project key `acme-my-app`.

```bash
# 1. Create config directory
mkdir -p projects/<project_key>/patches/default

# 2. Copy and customise the example config
cp projects/example-owner-repo/project.env projects/<project_key>/project.env
$EDITOR projects/<project_key>/project.env

# 3. (Optional) Add .patch files
cp my.patch projects/<project_key>/patches/default/0001-my.patch

# 4. Commit and push
git add projects/<project_key>
git commit -m "Add project config for <project_key>"
git push
```

See [`projects/README.md`](projects/README.md) for a full variable reference.

---

## Patch sets

Patches live under `projects/<project_key>/patches/<patch_set>/`.
Each `.patch` file must be in `git diff` / `git format-patch` format.
They are applied in **lexicographic order** using `git apply --ignore-whitespace`.

* If the patch directory is missing or contains no `.patch` files the step is
  logged and skipped without error.
* To use a different patch set pass `patch_set=<name>` when triggering the
  workflow.

---

## Authentication for private repos

By default the workflows clone via HTTPS without authentication, which works
for **public** target repositories.

For **private** repositories:

1. Create a GitHub Personal Access Token (PAT) with `repo` scope.
2. Add it as a repository secret named `TARGET_REPO_TOKEN` in this
   (`ci-workflows`) repository.
3. The workflows automatically pick up the secret via
   `secrets.TARGET_REPO_TOKEN` — no further changes required.

---

## Android signing

To produce a **signed** APK or AAB, add these three secrets to this repository
(**Settings → Secrets and variables → Actions → New repository secret**):

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Your `.jks` / `.keystore` file Base64-encoded: `base64 < release.jks` |
| `ANDROID_KEYSTORE_ALIAS` | The key alias inside the keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password (also used as the key password) |

**How it works:**

1. The "Set up Android signing" workflow step decodes `ANDROID_KEYSTORE_BASE64` → `/tmp/keystore.jks`.
2. It exports `ANDROID_KEYSTORE_PATH`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD` into the job environment.
3. `run_build.sh` writes `android/key.properties` in the target source tree — the file that Flutter and standard Gradle signing configs read automatically.

When the secrets are **not** configured the signing step is skipped and an unsigned build is produced.

For projects that don't use `key.properties` you can reference the env vars
directly in `BUILD_CMD_ANDROID_APK` — see the signing section in
[`projects/example-owner-repo/project.env`](projects/example-owner-repo/project.env)
for examples.

---

## Repository structure

```
ci-workflows/
├── .github/workflows/
│   ├── build-android-apk.yml          # APK workflow
│   ├── build-android-apk-bundle.yml   # AAB workflow
│   ├── build-linux-amd64.yml          # Linux x86_64 workflow
│   └── build-linux-arm64.yml          # Linux arm64 workflow
├── scripts/
│   ├── checkout_target.sh             # Clone & checkout target repo
│   ├── apply_patches.sh               # Apply project patch set
│   ├── run_build.sh                   # Load config + run build
│   └── package_artifacts.sh           # Stage & optionally tar artifacts
├── projects/
│   ├── README.md                           # Project config reference
│   └── example-owner-repo/
│       ├── project.env                     # Example / template config
│       └── patches/default/.gitkeep
└── README.md
```

---

## Scripts reference

| Script | Purpose |
|---|---|
| `scripts/checkout_target.sh` | Clones `TARGET_REPO` into `WORKDIR` and checks out `TARGET_REF` |
| `scripts/apply_patches.sh` | Applies `.patch` files from the configured patch set directory |
| `scripts/run_build.sh <platform>` | Loads `project.env`, optionally sets up toolchains, runs the build |
| `scripts/package_artifacts.sh` | Collects matched files into `PACKAGE_DIR`; creates `.tar.gz` when `PACKAGE_TAR=true` |
