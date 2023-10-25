# This file uses `dockerTools.streamLayeredImage` to build a minimal
# container. Instead of generating a tarball in the store,
# `streamLayeredImage` generates a script that dumps the container to
# stdout.
#
# After you build the container from the flake using
# `nix build .#tiny-container`, you can load the image by running
# `./result | docker load` and then tag and push the container to your
# registry.

{ bootstrap, buildEnv, busybox, dockerTools, runCommandLocal, writeScript }:
dockerTools.streamLayeredImage {
  name = "wai-handler-hal-example-tiny-container";
  tag = "latest";

  contents =
    let
      # Grab the runtime interface emulator from a GitHub release.
      runtimeInterfaceEmulator = builtins.fetchurl {
        url = "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/v1.0/aws-lambda-rie";
        sha256 = "1x0200q4cnwwjiqsdqqm1ypz5hah9v7fzdc66kqw9sv3j1da11d4";
      };

      # This is basically the same as /lambda-entrypoint.sh in a real
      # Amazon container image.
      entrypoint = writeScript "lambda-entrypoint.sh" ''
        #!${busybox}/bin/sh
        if [ -z "''${AWS_LAMBDA_RUNTIME_API}" ]; then
          exec /usr/local/bin/aws-lambda-rie /var/runtime/bootstrap
        else
          exec /var/runtime/bootstrap
        fi
      '';

      otherContents = runCommandLocal "other-contents" { } ''
        mkdir -p $out/usr/local/bin $out/var/runtime $out/var/task
        cp ${entrypoint} $out/lambda-entrypoint.sh
        cp ${runtimeInterfaceEmulator} $out/usr/local/bin/aws-lambda-rie
        chmod +x $out/usr/local/bin/aws-lambda-rie
        cp ${bootstrap}/bootstrap $out/var/runtime/bootstrap
      '';
    in
    [ busybox otherContents ];

  # Config is unchanged from `container.nix`; there is no
  # technical requirement for EntryPoint or WorkingDir to have these
  # values but they need to be set to something. We reuse the values
  # from Amazon's base image to minimise surprise.
  config = {
    Cmd = [ "UNUSED" ];
    EntryPoint = [ "/lambda-entrypoint.sh" ];
    WorkingDir = "/var/task";
  };
}
