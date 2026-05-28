# AGENTS.md

Guidance for AI coding agents (Cursor, Codex, Claude Code, etc.) working in this repo.

## Merge Hygiene

When syncing from `develop` or merging older feature branches, guard against
deleted UI or behavior silently coming back from stale branch history.

- Prefer cherry-picking the specific fix commits needed from old branches over
  merging the whole branch.
- Before merging a branch that touches UI, inspect the UI delta first:
  `git diff develop...<branch> -- Sources/CodexKeyringUI/Views`.
- Treat prior removals of UI copy, sections, menu items, and presentation
  surfaces as intentional unless the user explicitly asks to restore them.
- If a removed UI element must stay removed, keep that removal in a clear,
  named commit and consider adding a narrow regression check for its unique
  text or type name.
- After any merge commit, review what actually entered through the merge:
  `git diff <merge>^1..<merge> -- Sources/CodexKeyringUI/Views`.
- Do not reintroduce previously removed UI from stale branches merely because
  Git can merge it cleanly.

## Commit Messages

All commits MUST follow [Conventional Commits](https://www.conventionalcommits.org/) in **English**.

### Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

- **Subject**: imperative mood, lowercase start, no trailing period, ≤ 72 chars.
- **Body**: include ONLY when the change is non-trivial — explain the **why**, not the what. Wrap at 72 chars. Blank line between subject and body.
- **Footer**: `BREAKING CHANGE: <desc>` or `Refs: #123` when applicable.

### Allowed Types

`feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `build`, `ci`, `chore`, `revert`.

### Suggested Scopes

`accounts`, `auth`, `oauth`, `snapshot`, `menubar`, `ui`, `launch`, `backup`, `build`, `script`, `docs`.

Omit the scope when a change spans the whole app or the scope would be redundant.

### Examples

```
feat(menubar): add quick switch shortcut for saved accounts
fix(oauth): handle expired refresh token before switching
refactor(accounts): extract snapshot rotation into AccountStore
docs: update ROADMAP with quota query milestone
chore(build): bump SwiftPM toolchain pin
```

Example with body (complex change):

```
fix(snapshot): keep saved snapshot in sync with rotated auth.json

Codex App rotates the refresh token in-place. Re-capture the live bytes
back into the matching saved snapshot, and refuse to switch away from an
account whose token has rotated without a re-snapshot.
```

### Hard Rules

- NEVER use vague subjects like "update code", "fix bug", "misc changes".
- NEVER mix unrelated changes in one commit — split them.
- NEVER add tool signatures such as "Generated with ..." or "Co-Authored-By: <bot>" unless explicitly requested.
- NEVER commit unless the user explicitly asks.
