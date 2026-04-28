{
  description = "kwim";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec {
        defaultPackage = pkgs.stdenv.mkDerivation rec {
          name = "kwim";
          src = ./.;

          dontSetZigDefaultFlags = true;
          zigBuildFlags = [
            "--system"
            "${deps}"
            "-Doptimize=ReleaseSafe"
          ];

          deps = pkgs.callPackage ./deps.nix { };

          nativeBuildInputs = with pkgs; [
            pkg-config
            wayland-scanner
            wayland-protocols
            zig_0_15
          ];

          buildInputs = with pkgs; [
            wayland
            libxkbcommon
          ];
        };

        devShell = pkgs.mkShell {
          packages =
            defaultPackage.nativeBuildInputs ++
            defaultPackage.buildInputs ++ [
              # Use `zon2nix > deps.nix` to generate dependencies.
              pkgs.zon2nix
            ];
        };
      }
    );
}
