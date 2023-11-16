{
  description = "Nix flake for GoatCounter, a privacy-focused self-hosted web analytics platform.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-root.url = "github:srid/flake-root";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, moduleWithSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;

        flakeModules.default = flakeModules.goatcounter;
        flakeModules.goatcounter = importApply ./flake-modules/goatcounter { inherit withSystem; };
      in
      {
        debug = true;
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.flake-root.flakeModule

          # This flake's module.
          flakeModules.goatcounter
        ];

        # Export flakeModules.
        flake = { inherit flakeModules; };

        perSystem = { self', config, pkgs, ... }: {
          # Treefmt configuration.
          treefmt.config = {
            inherit (config.flake-root) projectRootFile;
            package = pkgs.treefmt;
            programs.nixpkgs-fmt.enable = true;
          };
        };
      });
}
