{
  perSystem =
    { pkgs, ... }:
    {
      packages.update = pkgs.writeShellApplication {
        name = "update-agent-browser";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.git
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gnutar
          pkgs.gzip
          pkgs.jq
          pkgs.nix
        ];

        text = ''
          set -euo pipefail

          fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
          tag=$(curl -fsSL https://api.github.com/repos/vercel-labs/agent-browser/releases/latest | jq -r .tag_name)
          version="''${tag#v}"
          archive_url="https://github.com/vercel-labs/agent-browser/archive/refs/tags/''${tag}.tar.gz"
          src_hash=$(nix store prefetch-file --json --unpack "$archive_url" | jq -r .hash)

          workdir=$(mktemp -d)
          trap 'rm -rf "$workdir"' EXIT
          curl -fsSL "$archive_url" | tar -xz -C "$workdir"
          src_dir="$workdir/agent-browser-''${version}"

          pnpm_package="pnpm_10"
          if jq -er '.engines.pnpm // empty' "$src_dir/package.json" | grep -q '>=11'; then
            pnpm_package="pnpm_11"
          fi

          write_version() {
            jq -n \
              --arg version "$version" \
              --arg srcHash "$src_hash" \
              --arg pnpmDepsHash "$1" \
              --arg cargoHash "$2" \
              --arg pnpmPackage "$pnpm_package" \
              '{version: $version, srcHash: $srcHash, pnpmDepsHash: $pnpmDepsHash, cargoHash: $cargoHash, pnpmPackage: $pnpmPackage}' > VERSION.json
          }

          extract_got_hash() {
            sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' "$1" | tail -1
          }

          write_version "$fake_hash" "$fake_hash"

          pnpm_log=$(mktemp)
          if nix build .#agent-browser --no-link --print-build-logs >"$pnpm_log" 2>&1; then
            echo "Expected pnpm dependency hash mismatch, but build succeeded unexpectedly." >&2
            exit 1
          fi
          pnpm_hash=$(extract_got_hash "$pnpm_log")
          if [ -z "$pnpm_hash" ]; then
            cat "$pnpm_log" >&2
            echo "Could not extract pnpmDepsHash." >&2
            exit 1
          fi
          write_version "$pnpm_hash" "$fake_hash"

          cargo_log=$(mktemp)
          if nix build .#agent-browser --no-link --print-build-logs >"$cargo_log" 2>&1; then
            echo "Expected cargo hash mismatch, but build succeeded unexpectedly." >&2
            exit 1
          fi
          cargo_hash=$(extract_got_hash "$cargo_log")
          if [ -z "$cargo_hash" ]; then
            cat "$cargo_log" >&2
            echo "Could not extract cargoHash." >&2
            exit 1
          fi
          write_version "$pnpm_hash" "$cargo_hash"

          nix flake update
        '';
      };
    };
}
