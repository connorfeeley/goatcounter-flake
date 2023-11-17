# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ lib, config, ... }:
let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types;

  cfg = config.services.goatcounter;

  goatcounterEnv = ([
    "PGDATABASE=${cfg.database.name}"
    (lib.optionalString (cfg.database.user != null) "PGUSER=${cfg.database.user}")
    (lib.optionalString (cfg.database.passwordFile != null) "PGPASSFILE=%d/passwordFile")
  ]);
in
{
  options.services.goatcounter = {
    enable = mkEnableOption "Enable the goatcounter service.";
    package = mkOption { defaultText = lib.literalMD "`packages.default` from the foo flake"; };

    # TODO: seperate sqlite and postgres options.
    database = {
      backend = mkOption {
        type = types.enum [ "postgresql" "sqlite" ];
        default = "postgresql";
        description = "Databse backend.";
      };

      # host = mkOption { type = types.str; description = "Database host."; };
      name = mkOption { type = types.str; description = "Database to connect to."; };
      user = mkOption { type = types.str; description = "Postgresql user."; };
      passwordFile = mkOption {
        type = with types; nullOr path;
        default = null;
        example = "/var/lib/goatcounter.passwd";
        description = lib.mdDoc ''
          Path to a file containing the password for the database user.

          Should contain lines of the following format:
          hostname:port:database:username:password

          Must have permissions 0600 or less to be read by the user running goatcounter.

          See https://www.postgresql.org/docs/current/libpq-pgpass.html for more information.
        '';
      };
    };
    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      example = "/var/lib/goatcounter.env";
      description = lib.mdDoc ''
        Additional environment file as defined in {manpage}`systemd.exec(5)`.

        Secrets like {env}`PGDATABASE` and {env}`DBHOST`
        may be passed to the service without adding them to the world-readable Nix store.

        Note that this file needs to be available on the host on which
        `goatcounter` is running.
      '';
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "-listen='*:8002'" "-tls=none" "-debug=all" ];
    };
  };

  config = mkIf cfg.enable {
    systemd.services.goatcounter = {
      description = "GoatCounter web analytics";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        DynamicUser = "yes";
        Environment = goatcounterEnv;
        EnvironmentFile = [ ] ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential = lib.mkIf (cfg.database.passwordFile != null) "passwordFile:${cfg.database.passwordFile}";
        ExecStart = "${cfg.package}/bin/goatcounter serve -db '${cfg.database.backend}' ${lib.concatStringsSep " " cfg.extraArgs}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
