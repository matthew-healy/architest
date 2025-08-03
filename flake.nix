{
  description = "Architest is a DSL for testcontainers";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk-pkg = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      pre-commit-hooks,
      naersk-pkg,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        treefmt = treefmt-nix.lib.evalModule pkgs {
          programs.nixfmt.enable = true;
          programs.rustfmt.enable = true;
        };

        naersk = pkgs.callPackage naersk-pkg { };

        on-pre-commit = pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
            flake-checks = {
              enable = true;
              name = "Run flake checks";
              entry = "nix flake check";
              pass_filenames = false;
            };
          };
        };

        mkArchitest =
          args:
          let
            defaultArgs = {
              pname = "architest";
              src = ./.;

              postInstall = ''
                mv $out/bin/architest-cli $out/bin/architest
              '';

              cargoTestCommands =
                prev:
                prev
                ++ [
                  ''cargo $cargo_options clippy -- -Dwarnings''
                ];

              override =
                prev:
                prev
                // {
                  nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.clippy ];
                };
            };
          in
          naersk.buildPackage (defaultArgs // args);
      in
      rec {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            ${on-pre-commit.shellHook}
          '';

          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            clippy
            rust-analyzer
          ];
        };

        formatter = treefmt.config.build.wrapper;

        packages.architest = mkArchitest { };

        apps.architest = {
          type = "app";
          program = "${packages.architest}/bin/architest";
        };

        checks = {
          architest = mkArchitest { doCheck = true; };
          formatting = treefmt.config.build.check self;
        };
      }
    );
}
