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
- Offers a menu bar item for quick switching and background use.
- Restarts Codex App when switching so the desktop app can reload auth.
- Includes Launch at Login support through macOS ServiceManagement.
- Keeps each saved snapshot in lock-step with `~/.codex/auth.json` so the
  rotating OAuth refresh token never goes stale: whenever Codex App rewrites
  the live auth file, the app captures the new bytes back into the matching
  saved snapshot (and refuses to switch away from an account without first
  re-snapshotting its rotated token).
- Remembers per-account Codex agent settings (model, reasoning effort,
  approval/sandbox mode, Full Access / Auto Review, and the "skip
  full-access confirm" toggle) and restores them on the next switch.
  Enabled by default; toggle off from Settings → "Remember per-account
  agent settings". The switch flow restarts Codex App so the rewrite of
  `~/.codex/config.toml` and `~/.codex/.codex-global-state.json` happens
  while Codex App is stopped.
  Unrelated keys in those files (project trust levels, `[features]`,
  workspace history, window bounds, etc.) are preserved byte-for-byte.

The first version intentionally avoids quota/account API calls. The setting is
visible but disabled until a future version explicitly implements it.

## Build And Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM target, stages a project-local app bundle at
`dist/Codex Keyring.app`, and launches it.

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

The Codex app Run action is wired in `.codex/environments/environment.toml`.

## Safe Basic Workflow

1. Click the add button to open the Codex ChatGPT login page.
2. Complete login in the browser. The new auth snapshot is saved under this
   app's Application Support folder, while the current Codex auth is restored.
3. Repeat the add flow for another account or import an existing auth snapshot.
4. Switch accounts from the manager window or menu bar. The switch also
   restarts Codex App so it reloads the new auth state.

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
