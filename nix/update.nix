{
  perSystem =
    { pkgs, ... }:
    {
      packages.update = pkgs.writeShellApplication {
        name = "update-agent-browser";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.nix
        ];

        text = ''
          set -euo pipefail

          tag=$(curl -fsSL https://api.github.com/repos/vercel-labs/agent-browser/releases/latest | jq -r .tag_name)
          version="''${tag#v}"
          release_url="https://github.com/vercel-labs/agent-browser/releases/download/''${tag}"
          archive_url="https://github.com/vercel-labs/agent-browser/archive/refs/tags/''${tag}.tar.gz"

          src_hash=$(nix store prefetch-file --json --unpack "$archive_url" | jq -r .hash)
          darwin_arm64_hash=$(nix store prefetch-file --json "$release_url/agent-browser-darwin-arm64" | jq -r .hash)
          linux_musl_x64_hash=$(nix store prefetch-file --json "$release_url/agent-browser-linux-musl-x64" | jq -r .hash)

          jq -n \
            --arg version "$version" \
            --arg srcHash "$src_hash" \
            --arg darwinArm64Hash "$darwin_arm64_hash" \
            --arg linuxMuslX64Hash "$linux_musl_x64_hash" \
            '{
              version: $version,
              srcHash: $srcHash,
              binaryHashes: {
                "aarch64-darwin": $darwinArm64Hash,
                "x86_64-linux": $linuxMuslX64Hash
              }
            }' > VERSION.json

          nix flake update
        '';
      };
    };
}
