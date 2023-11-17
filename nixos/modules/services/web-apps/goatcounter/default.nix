# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ lib, config }:
let
  inherit (lib)
    mkIf
    mkOption
    mkPackageOption
    mkEnableOption
    types;
in
{
  options.services.goatcounter = {
    enable = mkEnableOption "Enable the goatcounter service.";
    package = mkOption {
      defaultText = lib.literalMD "`packages.default` from the foo flake";
    };

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
