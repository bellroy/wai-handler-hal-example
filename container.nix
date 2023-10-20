# Use `dockerTools.buildImage` to add our binary to an Amazon-provided
# base container. You may prefer `streamLayeredImage`, which avoids
# putting the tarball itself in the nix store.
#
# After you build the container from the flake using
# `nix build .#container`, you can load the image by running
# `docker load < ./result`.
{ bootstrap, buildEnv, dockerTools }:
dockerTools.buildImage {
  name = "wai-handler-hal-example-container";
  tag = "latest";

  # Fetch the al2 image from Docker Hub. `dockerTools.pullImage` doesn't
  # understand both tags and digests, so we provide only the digest.
  fromImage = dockerTools.pullImage {
    imageName = "amazon/aws-lambda-provided";
    imageDigest = "sha256:4202908189cc596b5a8a3f45c46dfca7f225d152161a71cc4ad8f426b2478223";
    sha256 = "0zfz292w535fcih7ygijgm3ib0bywrwszrimk78sh4xpg8g1kq2f";
  };

  copyToRoot = buildEnv {
    name = "wai-handler-hal-root";
    paths = [ bootstrap ];
    extraPrefix = "/var/runtime";
  };

  config = {
    # Lambda containers treat CMD as the name of the handler,
    # but we don't use it.
    Cmd = ["UNUSED"];

    # This script is provided by the base image and falls back
    # to the runtime interface emulator if not running on AWS.
    # It expects the binary to be at `/var/runtime/bootstrap`.
    EntryPoint = ["/lambda-entrypoint.sh"];

    # This is the working dir set by the base image. AWS won't
    # boot the Lambda unless it is provided.
    WorkingDir = "/var/task";
  };
}
