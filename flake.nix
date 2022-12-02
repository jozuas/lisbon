{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pgCfg = {
          package = pkgs.postgresql;
          initdbArgs = [ "--auth=trust" ];
          dbName = "lisbon";
        };

        fastApiStart = pkgs.writeShellScriptBin "srv-start" ''
          uvicorn main:app --reload
        '';

        pgInit = pkgs.writeShellScriptBin "pg-init" ''
          set -euo pipefail

          export PATH=${pgCfg.package}/bin:${pkgs.coreutils}/bin

          # Abort if the data dir already exists
          [[ ! -d "$PGDATA" ]] || exit 0

          initdb ${pkgs.lib.concatStringsSep " " pgCfg.initdbArgs}

          # Create a default DB for current user for psql without args
          echo "CREATE DATABASE ''${USER:-$(id -nu)};" | postgres --single -E postgres

          # Create Phoenix project dev DB
          echo "CREATE DATABASE ${pgCfg.dbName}_dev;" | postgres --single -E postgres
        '';

        pgStart = pkgs.writeShellScriptBin "pg-start" ''
          set -euo pipefail

          ${pgInit}/bin/pg-init

          # Abort if already running
          [[ -f "$PGDATA/postmaster.pid" ]] && exit 0

          ${pgCfg.package}/bin/pg_ctl start \
            --log $PGLOG \
            --options '-c listen_addresses=127.0.0.1 -c unix_socket_directories=$PGDATA'
        '';

        pgStop = pkgs.writeShellScriptBin "pg-stop" ''
          ${pgCfg.package}/bin/pg_ctl stop
        '';
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python310
            python310Packages.fastapi
            python310Packages.uvicorn
            python310Packages.sqlalchemy
            python310Packages.psycopg2

            python310Packages.flake8
            nodePackages.pyright
            black
            isort

            postgresql
            pgStart
            pgStop

            fastApiStart
          ];

          ### Environment ###

          # Ireland locale for sane Postgres English European settings
          LC_ALL = "en_IE.UTF-8";

          # Nix flakes are hermetic. To build ENV based on current project directory,
          # we need to do this at run-time instead of compile-time.
          shellHook = ''
            export MAMA="MIA"
            export PGDATA="$PWD/.direnv/postgres"
            export PGLOG="$PGDATA/pg.log"
            export PGHOST="$PGDATA"
          '';
        };
      });
}
