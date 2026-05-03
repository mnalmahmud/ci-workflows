# Projects

This directory holds per-project build configuration. Each subdirectory
corresponds to a **project key** that you supply as the `project_key` input
when triggering a workflow.

> **Convention:** use `username-reponame` as the project key — replace the `/`
> in the GitHub `owner/name` with `-`.
> Example: repo `acme/my-app` → project key `acme-my-app`.

```
projects/
└── <project_key>/
    ├── project.env          # Build configuration (required)
    └── patches/
        └── <patch_set>/     # e.g. "default", "hotfix-1"
            ├── 0001-fix.patch
            └── …
```

---

## Creating a new project

1. **Create the directory**

   ```bash
   mkdir -p projects/<project_key>/patches/default
   ```

2. **Copy the example config and customise it**

   ```bash
   cp projects/example-owner-repo/project.env projects/<project_key>/project.env
   # Edit the new file to set your build commands, artifact globs, etc.
   ```

3. **Add patches (optional)**

   Drop any `.patch` files into `projects/<project_key>/patches/<patch_set>/`.
   The files are applied in lexicographic order by `scripts/apply_patches.sh`.
   If the directory is empty or missing the step is silently skipped.

---

## project.env reference

| Variable | Description |
|---|---|
| `USE_FLUTTER` | `true` to enable Flutter/Dart toolchain setup (default `false`) |
| `BUILD_CMD_ANDROID_APK` | Shell command(s) to produce an APK inside `work/target/` |
| `BUILD_CMD_ANDROID_AAB` | Shell command(s) to produce an AAB inside `work/target/` |
| `BUILD_CMD_ANDROID` | Fallback Android build command used when no variant-specific command is set |
| `ARTIFACT_GLOBS_ANDROID_APK` | Space-separated glob patterns for APK output files |
| `ARTIFACT_GLOBS_ANDROID_AAB` | Space-separated glob patterns for AAB output files |
| `ARTIFACT_GLOBS_ANDROID` | Fallback artifact globs for Android (used when variant-specific globs are not set) |
| `APT_PACKAGES_ANDROID` | Extra APT packages for Android builds |
| `BUILD_CMD_LINUX` | Shell command(s) to build the Linux target inside `work/target/` |
| `ARTIFACT_GLOBS_LINUX` | Space-separated glob patterns for Linux output files |
| `APT_PACKAGES_LINUX` | Extra APT packages for Linux builds |

All variables are optional; `run_build.sh` will report an error only when the
required `BUILD_CMD_*` for the chosen platform is undefined.

---

## Patch sets

A project can have multiple named patch sets (e.g. `default`, `staging`,
`hotfix-1`). Pass the desired name as the `patch_set` workflow input.
Patches are applied with `git apply --ignore-whitespace` in sorted order.

---

## Auth for private target repositories

The workflows use `secrets.TARGET_REPO_TOKEN` when the secret is set.
For public repos no token is needed.
Add a repository secret named `TARGET_REPO_TOKEN` with a PAT that has
`repo` scope to enable private-repo access.

---

## Android signing secrets

To produce a **signed** APK or AAB add these three repository secrets:

| Secret | What to put there |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Your `.jks` / `.keystore` file encoded as Base64 (`base64 < release.jks`) |
| `ANDROID_KEYSTORE_ALIAS` | The key alias inside the keystore |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password (also used as the key password) |

When those secrets are present the workflow:

1. Decodes the keystore to `/tmp/keystore.jks`
2. Exports `ANDROID_KEYSTORE_PATH`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` into the job environment
3. Writes `android/key.properties` in the target working tree (the standard Flutter / Gradle convention)

Your build command can then sign without extra flags if it reads `key.properties`, or reference the env vars directly — see `projects/example-owner-repo/project.env` for examples.

When the secrets are **not** configured the signing step is skipped and an unsigned build is produced.
