# nix/tui.nix — Triibal TUI (Ink/React) compiled with tsc and bundled
{ pkgs, triibalNpmLib, ... }:
let
  src = ../ui-tui;
  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    hash = "sha256-FyzS39ObGhiVTll2KKlgc0rHigaskTId0iAaEAszvhk=";
  };

  npm = triibalNpmLib.mkNpmPassthru { folder = "ui-tui"; attr = "tui"; pname = "triibal-tui"; };

  packageJson = builtins.fromJSON (builtins.readFile (src + "/package.json"));
  version = packageJson.version;
in
pkgs.buildNpmPackage (npm // {
  pname = "triibal-tui";
  inherit src npmDeps version;

  doCheck = false;
  npmFlags = [ "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/triibal-tui

    # Single self-contained bundle built by scripts/build.mjs (esbuild).
    cp -r dist $out/lib/triibal-tui/dist

    # package.json kept for "type": "module" resolution on `node dist/entry.js`.
    cp package.json $out/lib/triibal-tui/

    runHook postInstall
  '';
})
