# nix/web.nix — Triibal Web Dashboard (Vite/React) frontend build
{ pkgs, triibalNpmLib, ... }:
let
  src = ../web;
  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    hash = "sha256-HGyF8Uu87b3/AakZDSPrtfGuo6McscDJFZbV2+1SOWA=";
  };

  npm = triibalNpmLib.mkNpmPassthru { folder = "web"; attr = "web"; pname = "triibal-web"; };

  packageJson = builtins.fromJSON (builtins.readFile (src + "/package.json"));
  version = packageJson.version;
in
pkgs.buildNpmPackage (npm // {
  pname = "triibal-web";
  inherit src npmDeps version;

  doCheck = false;

  buildPhase = ''
    npx tsc -b
    npx vite build --outDir dist
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';
})
