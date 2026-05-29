# nix/tui.nix — Tribal TUI (Ink/React) compiled with tsc and bundled
{ pkgs, tribalNpmLib, ... }:
let
  src = ../ui-tui;
  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    hash = "sha256-PfmNH6yYEvR7ahwVRwjAkpOfMu5jlRYi6HL9NrKAbZI=";
  };

  npm = tribalNpmLib.mkNpmPassthru { folder = "ui-tui"; attr = "tui"; pname = "tribal-tui"; };

  packageJson = builtins.fromJSON (builtins.readFile (src + "/package.json"));
  version = packageJson.version;
in
pkgs.buildNpmPackage (npm // {
  pname = "tribal-tui";
  inherit src npmDeps version;

  doCheck = false;
  npmFlags = [ "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/tribal-tui

    # Single self-contained bundle built by scripts/build.mjs (esbuild).
    cp -r dist $out/lib/tribal-tui/dist

    # package.json kept for "type": "module" resolution on `node dist/entry.js`.
    cp package.json $out/lib/tribal-tui/

    runHook postInstall
  '';
})
