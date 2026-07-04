{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  versionInfo = builtins.fromJSON (builtins.readFile (root + /VERSION.json));
in
{
  perSystem =
    { pkgs, ... }:
    let
      version = versionInfo.version;
      system = pkgs.stdenv.hostPlatform.system;
      assets = {
        aarch64-darwin = "agent-browser-darwin-arm64";
        x86_64-linux = "agent-browser-linux-musl-x64";
      };
      asset = assets.${system} or (throw "agent-browser-nix: unsupported system ${system}");
      binary = pkgs.fetchurl {
        url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/${asset}";
        hash =
          versionInfo.binaryHashes.${system}
            or (throw "agent-browser-nix: missing binary hash for ${system}");
      };
      src = pkgs.fetchFromGitHub {
        owner = "vercel-labs";
        repo = "agent-browser";
        tag = "v${version}";
        hash = versionInfo.srcHash;
      };
    in
    {
      packages.agent-browser = pkgs.stdenvNoCC.mkDerivation {
        pname = "agent-browser";
        inherit version;

        dontUnpack = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 ${binary} $out/bin/agent-browser
          cp -r ${src}/skills $out/skills
          cp -r ${src}/skill-data $out/skill-data
          runHook postInstall
        '';

        meta = {
          description = "Headless browser automation CLI for AI agents";
          homepage = "https://github.com/vercel-labs/agent-browser";
          license = lib.licenses.asl20;
          sourceProvenance = with lib.sourceTypes; [
            binaryNativeCode
            fromSource
          ];
          platforms = builtins.attrNames assets;
          mainProgram = "agent-browser";
        };
      };
    };
}
