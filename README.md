# Codex Keyring User Guide

Codex Keyring is a macOS menu bar app for managing multiple Codex accounts.
It lets you save accounts, switch between them quickly, check usage limits, and
keep account-specific Codex preferences organized.

Use it when you want to:

- Switch between work and personal Codex accounts.
- Save a new login without switching to it immediately.
- Change accounts from the menu bar.
- See usage limits at a glance.
- Keep each account's model and permission preferences separate.

## First Use

1. Open Codex Keyring.
2. Click the plus button to add a new Codex login.
3. Finish signing in through the browser.
4. Return to Codex Keyring and give the account a clear name.
5. Add more accounts, or save the Codex account you are already using.

Adding an account only saves it in Codex Keyring. Your active Codex account
changes only when you choose to switch.

## Add Accounts

**Add a new browser login**

Use the plus button or `Add New Login`. Codex Keyring opens the browser, waits
for you to sign in, and then adds the account to your list.

**Save the current login**

If Codex is already signed in, use `Save Current Login` to add that account to
Codex Keyring.

**Import an existing login**

Use the import button when you already have login data from another setup.
Imported accounts are saved but not activated until you switch to them.

## Switch Accounts

Select an account in the main window and click `Switch`. You can also switch
directly from the menu bar.

The active account is marked in green. By default, Codex Keyring restarts Codex
App after switching so the new account takes effect immediately.

## Check Usage Limits

Click `Refresh Quotas` to update usage limits. The menu bar also shows compact
usage information for quick checks.

If usage details are missing, open `Settings` and enable usage-limit checks.
Some account types may show unlimited, unavailable, or temporarily unreadable
usage information.

## Settings

- `Restart Codex App after switching accounts`: recommended. This helps Codex
  App pick up the selected account immediately.
- `Launch at Login`: starts Codex Keyring when you sign in to macOS.
- `Remember per-account agent settings`: keeps model, reasoning, and permission
  preferences separate for each saved account.
- Usage refresh interval: controls how often Codex Keyring refreshes usage
  information.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd-0` | Open Manager |
| `Cmd-N` | Add New Login |
| `Cmd-S` | Save Current Login |
| `Cmd-Shift-I` | Import Login |
| `Cmd-R` | Refresh Accounts |
| `Cmd-Shift-R` | Refresh Quotas |

## Command Line

Codex Keyring also ships a `ckr` command for scripted account checks and
explicit account operations.

```bash
ckr list
ckr status
ckr save-current --alias work
ckr import /path/to/auth.json --alias personal
ckr switch work --restart
ckr settings set allowNetworkQuotaAPIs true
ckr quota refresh
```

Use `--json` with read commands and mutation commands when another tool needs
machine-readable output. Account selectors accept UUIDs, UUID prefixes, exact
aliases, exact emails, account identifiers, and fingerprint prefixes. If a
selector matches multiple accounts, the command fails instead of guessing.

The CLI never prints raw `auth.json` contents, refresh tokens, or snapshot file
names. Destructive saved-account removal requires `--yes`. The longer
`codex-keyring` command remains available as a compatibility alias.

## Release

Release builds are produced by the GitHub Actions workflow in
`.github/workflows/release.yml`. See `docs/release.md` for tag-based release
publishing, manual release candidates, and Apple Developer ID notarization
setup.

## Privacy And Safety

Codex Keyring stores account information locally on your Mac. It does not sync
your account list to a cloud service.

Deleting a saved account removes it from Codex Keyring only. It does not delete
your OpenAI or Codex account.

Usage-limit checks are optional. If they are turned off, Codex Keyring does not
refresh usage information in the background.

## Troubleshooting

**Why did my active Codex account not change after adding a login?**

Adding a login only saves it. Choose `Switch` when you want to make it active.

**Why does Codex App restart after switching?**

Restarting helps Codex App use the newly selected account right away. You can
turn this off in `Settings`, but you may need to restart Codex App manually.

**Does removing a saved account delete the real account?**

No. It only removes the saved entry from Codex Keyring.

**Why is usage information missing for an account?**

Usage checks may be disabled, the account type may not expose usage details, or
the information may be temporarily unavailable. Try refreshing again later.

## Uninstall

Quit Codex Keyring and delete the app.

To remove saved Codex Keyring data as well, open `Settings`, reveal the data
location, and delete the saved data from your Mac.

Uninstalling Codex Keyring does not remove the Codex account you are currently
using.
