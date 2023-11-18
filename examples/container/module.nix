# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ inputs, ... }: {
  imports = [ inputs.goatcounter.nixosModules.goatcounter ];

  services.goatcounter = {
    enable = true;
    environmentFile = "/var/lib/goatcounter.env";
    extraArgs = [ "-listen='*:8002'" "-tls=http" "-debug=all" ];
    database = {
      automigrate = true;
      backend = "postgresql";
      name = "goatcounter";
      user = "goatcounter";
      passwordFile = "/var/lib/goatcounter.passwd";
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
        proxyWebsockets = true; # needed if you need to use WebSocket
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;" +
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;"
        ;
      };
    };
  };
}
