# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{
  description = "Nix flake for GoatCounter, a privacy-focused self-hosted web analytics platform.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

    # flake-parts and friends.
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix = { url = "github:numtide/treefmt-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, moduleWithSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;

        # Goatcounter (privacy-focused, self-hosted web analytics)
        flakeModules.options-doc = importApply ./render { localFlake = self; inherit withSystem; };
      in
      {
        debug = true;
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.flake-root.flakeModule

          flakeModules.options-doc
        ];

        # Export flakeModules.
        flake = { inherit flakeModules; };

        flake.nixosModules.goatcounter = { pkgs, ... }: {
          imports = [ ./nixos/modules/services/web-apps/goatcounter ];
          services.goatcounter.package = withSystem pkgs.stdenv.hostPlatform.system ({ config, ... }:
            config.packages.default
          );
        };

        perSystem = { self', config, pkgs, ... }: {
          packages = rec {
            goatcounter = pkgs.callPackage ./pkgs/servers/web-apps/goatcounter { };
            default = goatcounter;
          };

          # Shell with treefmt.
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ config.treefmt.build.wrapper pkgs.reuse ];
          };

          # Treefmt configuration.
          treefmt.config = {
            inherit (config.flake-root) projectRootFile;
            package = pkgs.treefmt;
            programs.nixpkgs-fmt.enable = true;
          };
        };
      });
}
