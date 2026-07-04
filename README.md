# agent-browser-nix

Minimal flake exporting an `agent-browser` Nix package for `aarch64-darwin` and `x86_64-linux`. We use the [nixpkgs package definition](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ag/agent-browser/package.nix) but keep the version and hashes in `VERSION.json` so updating is easier. Package fixes should be upstreamed to nixpkgs when possible.
