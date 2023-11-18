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
    enable = mkEnableOption (lib.mdDoc "enable the goatcounter service");
    package = mkOption {
      defaultText = lib.literalMD "`packages.default` from the `goatcounter` flake";
      description = lib.mdDoc "The goatcounter package to use.";
      type = types.package;
    };
    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      example = lib.literalMD "/var/lib/goatcounter.env";
      description = lib.mdDoc ''
        Additional environment file as defined in {manpage}`systemd.exec(5)`.

        Secrets like {env}`PGDATABASE` and {env}`DBHOST` may be passed to the
        service without adding them to the world-readable Nix store.

        Note that this file needs to be available on the host on which
        `goatcounter` is running.
      '';
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "-listen='*:8002'" "-tls=http" "-debug=all" ];
      description = lib.mdDoc ''
        Extra command-line arguments to be passed to `goatcounter serve`.

        By default, GoatCounter listens on port 80 and 443 and tries to generate
        an ACME/Let's Encrypt certificate.

        To run GoatCounter behind a proxy like NGINX, you can change the listening port
        with
        ``` shellSession
        -listen='*:8002'
        ```
        and set
        ``` shellSession
        -tls=http
        ```
        to disable certificate generation.
      '';
    };

    # TODO: seperate sqlite and postgres options.
    database = {
      backend = mkOption {
        type = types.enum [ "postgresql" "sqlite" ];
        default = lib.literalMD "postgresql";
        description = lib.mdDoc "Database backend to use.";
      };

      name = mkOption { type = types.str; description = "Database name to connect to."; };
      user = mkOption { type = types.str; description = "PostgreSQL user to use for database connection."; };
      automigrate = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc "Whether to automatically migrate the database schema.";
      };
      passwordFile = mkOption {
        type = with types; nullOr path;
        default = null;
        example = lib.literalMD "/var/lib/goatcounter.passwd";
        description = lib.mdDoc ''
          Path to a file containing the password for the database user.

          The service will use use `LoadCredential` to expose the file to the service using {env}`PGPASSFILE`.

          Should contain lines of the following format:
          ```
          hostname:port:database:username:password
          ```

          Must have permissions 0600 or less to be read by the user running goatcounter.

          See [PostgreSQL: Documentation: 16: 34.16. The Password File](https://www.postgresql.org/docs/current/libpq-pgpass.html) for more information.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.goatcounter = {
      description = "GoatCounter web analytics";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        DynamicUser = "yes";
        LoadCredential = lib.mkIf (cfg.database.passwordFile != null) "passwordFile:${cfg.database.passwordFile}";
        Environment = [
          "PGDATABASE=${cfg.database.name}"
          (lib.optionalString (cfg.database.user != null) "PGUSER=${cfg.database.user}")
          (lib.optionalString (cfg.database.passwordFile != null) "PGPASSFILE=%d/passwordFile")
        ];
        EnvironmentFile = lib.optionals (cfg.environmentFile != null) [ cfg.environmentFile ];
        ExecStart = lib.concatStringsSep " " [
          "${cfg.package}/bin/goatcounter"
          "serve"
          "-db '${cfg.database.backend}'"
          (lib.optionalString cfg.database.automigrate "-automigrate")
          (lib.concatStringsSep " " cfg.extraArgs)
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
