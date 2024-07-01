{
  description = "Example binaries for wai-handler-hal";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
  };

  outputs = inputs:
    let
      # This is all hard-coded towards building x86_64-linux bootstrap
      # binaries. Extending this to support cross-compilation to
      # aarch64-linux is left as an exercise to the reader.
      #
      # Interested readers may also consider adding native
      # aarch64-linux support, which cross-compiles from aarch64-linux
      # to musl, avoiding the cross-architecture troubles.
      pkgsLocal = import inputs.nixpkgs {
        inherit (inputs.haskell-nix) config;
        system = "x86_64-linux";
        overlays = [ inputs.haskell-nix.overlay ];
      };
      pkgsMusl = pkgsLocal.pkgsCross.musl64;

      project = pkgs: pkgs.haskell-nix.project {
        compiler-nix-name = "ghc96";
        evalSystem = "x86_64-linux";
        src = pkgsLocal.haskell-nix.haskellLib.cleanGit {
          name = "wai-handler-hal-example";
          src = ./.;
        };

        # This is usually fine, but can "occasionally cause breakage":
        # https://input-output-hk.github.io/haskell.nix/troubleshooting/#why-does-my-executable-depend-on-ghcgcc
        modules = [{
          # Set this only for packages providing the final binaries that
          # go to AWS, unless you want to rebuild the entire universe.
          packages.wai-handler-hal-example.dontStrip = false;
        }];
      };

      devShells.x86_64-linux.default =
        (project pkgsLocal).shellFor {
          withHoogle = false;
          buildInputs = with pkgsLocal; [
            haskellPackages.cabal-fmt
            nixpkgs-fmt
            nodejs
          ];
        };

      # Compress a binary and put it in a directory under the name
      # `bootstrap`; CDK is smart enough to zip the directory up for
      # deployment.
      lambdaBinary = "${(project pkgsMusl).wai-handler-hal-example.components.exes.wai-handler-hal-example-hal}/bin/wai-handler-hal-example-hal";
      bootstrap = pkgsLocal.runCommand "wai-handler-hal-example-runtime" { } ''
        mkdir $out
        ${pkgsLocal.upx}/bin/upx -9 -o $out/bootstrap ${lambdaBinary}
      '';

      packages.x86_64-linux = {
        default = bootstrap;
        container = pkgsLocal.callPackage ./container.nix {
          inherit bootstrap;
        };
        tiny-container = pkgsLocal.callPackage ./tiny-container.nix {
          inherit bootstrap;

          # We run a tiny shell script to decide whether we need to
          # execute the runtime-interface-emulator. The simplest shell
          # we can get is busybox, statically linked against musl.
          busybox = pkgsMusl.busybox.override {
            enableStatic = true;
          };
        };
      };

      hydraJobs = {
        inherit devShells packages;

        aggregate = pkgsLocal.runCommand "aggregate"
          {
            _hydraAggregate = true;
            constituents = [
              "devShells.x86_64-linux.default"
              "packages.x86_64-linux.default"
              "packages.x86_64-linux.container"
              "packages.x86_64-linux.tiny-container"
            ];
          }
          "touch $out";
      };
    in
    { inherit devShells packages hydraJobs; };

  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
  };
}
