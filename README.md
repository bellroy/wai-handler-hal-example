# Example binary for wai-handler-hal

This package shows how to run a Servant API on AWS Lambda. Servant
returns a WAI `Application`, which we wrap with `wai-handler-hal` and
run with `hal`'s '`mRuntime`. This allows us to deploy the binary to
AWS Lambda, and use it as a [Lambda Proxy
Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html)
of an AWS API Gateway **REST API** (only).

A second executable runs the same WAI `Application` on the
[`warp`](https://hackage.haskell.org/package/warp) web server. This is
great for local testing.

Two endpoints are provided:

* `GET https://abcde12345.execute-api.us-east-1.amazonaws.com/prod/hoot` --- returns `{ "message": "hoot" }`
* `GET https://abcde12345.execute-api.us-east-1.amazonaws.com/prod/greet?person=Roy` --- returns `{ "message": "Hello, Roy!" }`

## Building

In the `wai-handler-hal-cdk/runtime` directory, run `nix build
.#packages.x86_64-linux` and wait a while. Nix will eventually create
a `result` symlink containing the compressed bootstrap
executable. From there, `npx cdk deploy` should deploy the example to
AWS.

## Hacking

There is a development shell provided. Users on `x86_64-linux` can run
`nix develop`, and then run `npm install` from within the
`wai-handler-hal-cdk` subdirectory.

## Other Targets

Some people might prefer to deploy OCI Container Images to [Elastic
Container Registry](https://aws.amazon.com/ecr/). There are additional
flake outputs showing how to package Lambda binaries into container
images:

* `packages.x86_64-linux.container` is a standard container image
  built atop Amazon's base image.
* `packages.x86_64-linux.tiny-continer` is a minimal container image
  consisting of [busybox](https://www.busybox.net/), Amazon's [AWS
  Lambda Runtime Interface
  Emulator](https://github.com/aws/aws-lambda-runtime-interface-emulator/),
  and the bootstrap binary.

## Maintaining this Repo

We don't provide `haskell-ci` in the development shell, in case people
copying the flake don't want it. To regenerate the GitHub Actions
workflow:

```sh
nix run nixpkgs#haskell-ci regenerate
```
