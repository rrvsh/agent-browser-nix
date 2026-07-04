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
      pnpm = pkgs.${versionInfo.pnpmPackage or "pnpm_10"};

      version = versionInfo.version;

      src = pkgs.fetchFromGitHub {
        owner = "vercel-labs";
        repo = "agent-browser";
        tag = "v${version}";
        hash = versionInfo.srcHash;
      };

      # The Rust CLI embeds the dashboard UI via RustEmbed at compile time.
      # Build the Next.js static export so it can be placed at the expected path.
      dashboard = pkgs.stdenv.mkDerivation {
        pname = "agent-browser-dashboard";
        inherit version src;

        nativeBuildInputs = [
          pkgs.nodejs
          pnpm
          pkgs.pnpmConfigHook
        ];

        __darwinAllowLocalNetworking = true;

        pnpmDeps = pkgs.fetchPnpmDeps {
          pname = "agent-browser-dashboard";
          inherit version src pnpm;
          pnpmWorkspaces = [ "dashboard" ];
          fetcherVersion = 3;
          hash = versionInfo.pnpmDepsHash;
        };

        pnpmWorkspaces = [ "dashboard" ];

        # Replace Google Fonts fetch with a local font from nixpkgs since the
        # Nix sandbox has no network access.
        postPatch = ''
          substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
            '{ Geist } from "next/font/google"' \
            'localFont from "next/font/local"'

          substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
            'Geist({ subsets: ["latin"], variable: "--font-sans" })' \
            'localFont({ src: "./Geist-Regular.otf", variable: "--font-sans" })'

          cp "${pkgs.geist-font}/share/fonts/opentype/Geist-Regular.otf" \
            packages/dashboard/src/app/Geist-Regular.otf
        '';

        buildPhase = ''
          runHook preBuild
          pnpm --filter dashboard build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          cp -r packages/dashboard/out $out
          runHook postInstall
        '';
      };
    in
    {
      packages.agent-browser = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "agent-browser";
        inherit version src;

        sourceRoot = "${finalAttrs.src.name}/cli";

        cargoHash = versionInfo.cargoHash;

        # Place the pre-built dashboard where RustEmbed expects it.
        postUnpack = ''
          chmod u+w source/packages/dashboard
          cp -r ${dashboard} source/packages/dashboard/out
        '';

        # `which_exists` spawns the external `which` binary at runtime to probe
        # for optional tools; pin it to an absolute store path.
        postPatch = ''
          substituteInPlace src/doctor/helpers.rs src/install.rs --replace-fail \
            '"which"' '"${lib.getExe pkgs.which}"'
        '';

        nativeCheckInputs = [
          pkgs.writableTmpDirAsHomeHook
        ];

        __darwinAllowLocalNetworking = true;

        # The `skills` subcommand looks for `skills/` and `skill-data/` next to
        # `bin/`, relative to the canonical exe path. See cli/src/skills.rs.
        postInstall = ''
          cp -r ../skills $out/skills
          cp -r ../skill-data $out/skill-data
        '';

        meta = {
          description = "Headless browser automation CLI for AI agents";
          homepage = "https://github.com/vercel-labs/agent-browser";
          license = lib.licenses.asl20;
          sourceProvenance = with lib.sourceTypes; [ fromSource ];
          platforms = lib.platforms.linux ++ lib.platforms.darwin;
          mainProgram = "agent-browser";
        };
      });
    };
}
