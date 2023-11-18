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
    # Build with `nixos-rebuild --flake .#container` or
    # `nix build .#nixosConfigurations.container.config.system.build.toplevel`
    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # Pass `inputs` to so that this configuration's modules can import
      # the goatcounter module.
      specialArgs = { inherit inputs; };

      modules = [
        # Configure as a container to simplify the configuration
        # (don't have to configure filesystems, etc)
        { boot.isContainer = true; system.stateVersion = "23.11"; }

        # Import this repo's module, which imports the GoatCounter module and
        # configures NGINX to expose it behind a reverse proxy.
        ./module.nix
      ];
    };
  };
}
