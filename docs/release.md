# Release Workflow

Codex Keyring publishes macOS packages through
`.github/workflows/release.yml`.

The workflow can run in two modes:

- Without Apple secrets, it builds an ad hoc signed zip for internal testing.
- With Apple Developer ID secrets, it signs, notarizes, staples, validates, and
  uploads a public macOS release package.

## GitHub Secrets

Set these repository secrets under `Settings > Secrets and variables >
Actions` when public macOS distribution is needed.

| Secret | Description |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application `.p12` certificate. |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate. |
| `CODESIGN_IDENTITY` | Exact Developer ID Application identity name. |
| `APPLE_ID` | Apple ID email used for notarization. |
| `APPLE_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool`. |

Create the certificate secret from macOS with:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Find the signing identity with:

```bash
security find-identity -v -p codesigning
```

Use the full identity string, such as:

```text
Developer ID Application: Example Name (TEAMID1234)
```

## Manual Release Candidate

Use `Actions > Release > Run workflow` for a release candidate build.

- `version`: release version without `v`, such as `0.1.0`.
- `create_release`: leave off for an artifact-only candidate.
- `run_app_smoke`: optional runner launch check.
- `notarize`: `auto` uses notarization only when all Apple secrets exist.

Artifact-only release candidates can run from a development branch. Creating a
GitHub Release manually must run from `main`.

## Official Release

Official releases are cut from `main`. Promote the verified development commit
to `main`, then tag that `main` commit:

```bash
git switch main
git pull --ff-only origin main
git merge --ff-only origin/develop
./script/verify.sh --release
git push origin main
git tag v0.1.0
git push origin v0.1.0
```

Pushing a `v*` tag runs the release workflow and creates or updates the GitHub
Release for that tag. The workflow rejects release tags that do not point to a
commit in `origin/main` history.

## Local Packaging

Internal package:

```bash
./script/package_release.sh --version 0.1.0
```

Developer ID signed and notarized package:

```bash
CODESIGN_IDENTITY="Developer ID Application: Example Name (TEAMID1234)" \
NOTARIZE_RELEASE=1 \
APPLE_ID="name@example.com" \
APPLE_TEAM_ID="TEAMID1234" \
APPLE_APP_SPECIFIC_PASSWORD="app-specific-password" \
./script/package_release.sh --version 0.1.0
```

Artifacts are written to `dist/release`:

- `CodexKeyring-<version>-macOS.zip`
- `CodexKeyring-<version>-macOS.zip.sha256`
- `CodexKeyring-<version>-release-notes.md`
