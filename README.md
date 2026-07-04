# agent-browser-nix

Minimal flake exporting an `agent-browser` Nix package for `aarch64-darwin` and `x86_64-linux`.

The package uses upstream release binaries and copies version-matched `skills/` and `skill-data/` from source. This avoids rebuilding the Next.js dashboard and Rust CLI in constrained CI while keeping the browser CLI version reproducible via `VERSION.json`.
