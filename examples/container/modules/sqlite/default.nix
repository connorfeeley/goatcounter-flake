# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ inputs, ... }: {
  imports = [ inputs.goatcounter.nixosModules.goatcounter ];

  services.goatcounter = {
    enable = true;
    extraArgs = [ "-listen='*:8002'" "-tls=none" "-debug=all" ];
    stateDirectory = "goatcounter";
    database = {
      automigrate = true;
      sqlite.databaseFile = "/var/lib/goatcounter/goatcounter.sqlite3";
    };
  };

  # Accept Let's Encrypt's ToS
  security.acme = {
    acceptTerms = true;
    defaults.email = "example@example.com";
  };

  services.nginx = {
    enable = true;

    virtualHosts."stats.example.com" = {
      forceSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8002/";
        recommendedProxySettings = true;
        proxyWebsockets = true; # needed if you need to use WebSocket
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_pass_header Authorization;
        '';
      };
    };
  };
}
