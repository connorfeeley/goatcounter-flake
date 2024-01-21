# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause

{ lib
, buildGoModule
, fetchFromGitHub
, sqlite
, postgresql
  # SQLite support is optional, but requires CGO.
, enableSqlite ? true
}:

buildGoModule rec {
  pname = "goatcounter";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "arp242";
    repo = "goatcounter";
    rev = "v${version}";
    hash = "sha256-lwiLk/YYxX4QwSDjpU/mAikumGXYMzleRzmPjZGruZU=";
  };
  vendorHash = "sha256-YAb3uBWQc6hWzF1Z5cAg8RzJQSJV+6dkppfczKS832s=";

  subPackages = "cmd/goatcounter";

  buildInputs = [ postgresql ] ++ lib.optional enableSqlite sqlite;

  doCheck = false;

  # Enable CGO if SQLite support is required.
  CGO_ENABLED = if enableSqlite then "1" else "0";
  # Set version.
  ldflags = [ "-X zgo.at/goatcounter/v2.Version=${version}" ];

  meta = with lib; {
    description = "Privacy-focused, self-hosted web analytics";
    homepage = "https://www.goatcounter.com/";
    license = licenses.mit;
    maintainers = with maintainers; [ cfeeley ];
  };
}
