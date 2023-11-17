# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

# The importApply argument. Use this to reference things defined locally,
# as opposed to the flake where this is imported.
localFlake:

# Regular module arguments; self, inputs, etc all reference the final user flake,
# where this module was imported.
{ self, lib, inputs, flake-parts-lib, moduleWithSystem, withSystem, ... }:
let
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib)
    mkIf
    mkOption
    mkPackageOption
    mkEnableOption
    types;
in
{
  flake = rec {
    nixosModules.goatcounter = moduleWithSystem (
      perSystem@{ config, pkgs }: # NOTE: only explicit params will be in perSystem
      nixos@{ ... }:
      {
        options.services.goatcounter = mkPerSystemOption {
          enable = mkEnableOption "Enable the goatcounter service.";

          postgres = mkOption {
            description = "Postgres database configuration.";
            type = lib.types.submodule {
              options = {
                enable = mkEnableOption "Use Postgres as the database backend.";
                user = mkOption {
                  type = types.nullOr types.string;
                  description = "User to connect to the database as.";
                };
                database = mkOption {
                  type = types.nullOr types.string;
                  description = "Database to connect to.";
                };
              };
            };
          };
        };

        config =
          let cfg = config.services.goatcounter;
          in mkIf cfg.enable {
            services.goatcounter = {
              enable = true;
              config = config.services.goatcounter.config;
            };

            services.postgresql = mkIf cfg.postgres.enable {
              enable = true;
              ensureDatabases = [ config.postgres.database ];
              ensureUsers = [{
                name = config.postgres.user;
                ensurePermissions = { "DATABASE ${config.postgres.database}" = "ALL PRIVILEGES"; };
              }];
            };
          };
      }
    );
  };
}
