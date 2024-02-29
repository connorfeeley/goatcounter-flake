# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{
  description = "Basic flake with container configured to run goatcounter";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Add this repo to inputs.
    goatcounter.url = "github:connorfeeley/goatcounter-flake";
  };

  outputs = inputs@{ self, nixpkgs, goatcounter }: {
    nixosConfigurations = {
      # Build with `nixos-rebuild --flake .#container-postgresql` or
      # `nix build .#nixosConfigurations.container-postgresql.config.system.build.toplevel`
      container-postgresql = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # Pass `inputs` to so that this configuration's modules can import
        # the goatcounter module.
        specialArgs = { inherit inputs; };

        modules = [
          # Configure as a container to simplify the configuration
          # (don't have to configure filesystems, etc)
          { boot.isContainer = true; system.stateVersion = "23.11"; }

          # Import this repo's module, which imports the GoatCounter module
          # (configured for PostgreSQL) and configures NGINX to expose it
          # behind a reverse proxy.
          ./modules/postgresql
        ];
      };
    };
  };
}
