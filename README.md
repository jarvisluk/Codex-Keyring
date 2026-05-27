# Codex Keyring

A personal macOS account switcher for Codex. It is a native desktop app with a
manager window, a persistent menu bar item, and local-only account snapshots.

## What It Does

- Opens a Codex ChatGPT login flow from the add button and saves the resulting
  auth snapshot locally without switching the active `~/.codex/auth.json`.
- Saves the current `~/.codex/auth.json` as a named local account snapshot.
- Imports another Codex `auth.json` snapshot from disk.
- Lists, renames, removes, and switches saved accounts.
- Replaces `~/.codex/auth.json` only when you explicitly switch accounts.
- Creates a backup before each switch under:
  `~/Library/Application Support/CodexKeyring/Backups`.
- Shows only metadata such as email, plan, auth mode, and a short fingerprint.
- Keeps saved snapshots under:
  `~/Library/Application Support/CodexKeyring/Accounts`.
- Writes auth snapshots, backups, and login staging copies with owner-only
  `0600` file permissions.
- Offers a menu bar item for quick switching and background use.
- Can restart Codex App after switching so the desktop app reloads auth
  immediately. This is enabled by default and can be changed in Settings.
- Includes Launch at Login support through macOS ServiceManagement.
- Optionally checks ChatGPT/Codex account quota for saved OAuth accounts and
  refreshes rotated OAuth tokens back into their local snapshots. Network quota
  checks are opt-in from Settings.
- Keeps each saved snapshot in lock-step with `~/.codex/auth.json` so the
  rotating OAuth refresh token never goes stale: whenever Codex App rewrites
  the live auth file, the app captures the new bytes back into the matching
  saved snapshot (and refuses to switch away from an account without first
  re-snapshotting its rotated token).
- Remembers per-account Codex agent settings (model, reasoning effort,
  approval/sandbox mode, Full Access / Auto Review, and the "skip
  full-access confirm" toggle) and restores them on the next switch.
  Enabled by default; toggle off from Settings → "Remember per-account
  agent settings". Automatic restore requires "Restart Codex App after
  switching accounts" so the rewrite of `~/.codex/config.toml` and
  `~/.codex/.codex-global-state.json` happens while Codex App is stopped.
  Unrelated keys in those files (project trust levels, `[features]`,
  workspace history, window bounds, etc.) are preserved byte-for-byte.

## Build And Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM target, stages a project-local app bundle at
`dist/Codex Keyring.app`, and launches it.

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --verify --release
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

`--verify` waits up to 10 seconds for the staged app process and main manager
window to appear, then quits the smoke-tested app. Override the timeout with
`VERIFY_TIMEOUT_SECONDS=20 ./script/build_and_run.sh --verify` when testing on a
slower machine, or keep the app open for manual inspection with
`VERIFY_KEEP_APP=1 ./script/build_and_run.sh --verify`. Add `--release` when
you want the staged app bundle to use the optimized SwiftPM build. Set
`SWIFT_WARNINGS_AS_ERRORS=1` when you want local run builds to match the stricter
verification compiler settings.

## Validate Changes

```bash
./script/verify.sh
```

This runs the standard local checks: `swift test` with Swift warnings promoted
to errors, shell syntax validation for the scripts, `git diff --check`, and
whitespace/conflict-marker checks for untracked source, test, script, and
documentation files.

After package graph, enum, or model shape changes, or if SwiftPM/xctest reports
an unexpected signal from stale incremental build state, clear build artifacts
before verifying:

```bash
./script/verify.sh --clean
```

For a full smoke test that also builds, launches, and verifies the staged app
bundle, run:

```bash
./script/verify.sh --app
```

Before release-oriented changes, also compile the optimized SwiftPM build:

```bash
./script/verify.sh --release
```

Options compose, so `./script/verify.sh --clean --release --app` is the broadest
local gate. It compiles tests and release builds with Swift warnings promoted to
errors, then smoke-tests the staged release app bundle under the same warning
policy.

The Codex app Run action is wired in `.codex/environments/environment.toml`.

## Safe Basic Workflow

1. Use the toolbar or Accounts menu to add a new Codex ChatGPT login.
2. Complete login in the browser. The new auth snapshot is saved under this
   app's Application Support folder, while the current Codex auth is restored.
3. Use Save Current Login for the live `~/.codex/auth.json`, or import an
   existing auth snapshot from the toolbar or Accounts menu. Imported snapshots
   are saved inactive until you explicitly switch to them.
4. Switch accounts from the manager window or menu bar. By default the switch
   also restarts Codex App so it reloads the new auth state.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd-0` | Open Manager |
| `Cmd-N` | Add New Login |
| `Cmd-S` | Save Current Login |
| `Cmd-Shift-I` | Import Auth Snapshot |
| `Cmd-R` | Refresh Accounts |
| `Cmd-Shift-R` | Refresh Quotas |

## Uninstall

Quit the app, then remove the app bundle and its local support data:

```bash
rm -rf "dist/Codex Keyring.app"
rm -rf "$HOME/Library/Application Support/CodexKeyring"
```

If you copied the bundle into `/Applications`, remove that copy too:

```bash
rm -rf "/Applications/Codex Keyring.app"
```

This does not remove `~/.codex/auth.json`; the current Codex login is preserved
unless you explicitly delete it yourself.
