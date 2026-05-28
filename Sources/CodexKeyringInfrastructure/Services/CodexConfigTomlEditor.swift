import Foundation

/// Minimal, *root-table-only* TOML editor for `~/.codex/config.toml`.
///
/// We deliberately do NOT use a full TOML parser. Codex stores its tracked
/// agent settings (`model`, `model_reasoning_effort`, `approval_policy`,
/// `approvals_reviewer`, `sandbox_mode`) as top-level scalar keys before any
/// `[section]` header. Everything below the first section header — project
/// trust levels, `[features]`, `[tui]`, custom user blocks, etc. — is left
/// byte-for-byte untouched, including comments, blank lines and trailing
/// whitespace.
///
/// Supported value types are limited to what Codex writes for these keys:
///   * Bare double-quoted strings (`key = "value"`).
///   * Booleans (`key = true` / `key = false`).
/// Anything else (arrays, inline tables, multi-line strings, dates) in the
/// root table is preserved verbatim but cannot be read or modified through
/// this editor.
public struct CodexConfigTomlEditor: Sendable {
    public init() {}
}
