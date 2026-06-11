# Test image for the template testing pipeline (docs/template-testing-prd.md).
#
# Thin layer over the official ICP dev environment, which already ships the
# icp CLI (with embedded cargo-generate and PocketIC), Rust + wasm32 target,
# mops, and Node.js. We only add yq for parsing the rendered icp.yaml files.
ARG BASE_TAG=0.3.2
FROM ghcr.io/dfinity/icp-dev-env-all:${BASE_TAG}

# cargo-generate (inside `icp new`) requires $USER; the base image runs as
# root without it. Also opt out of icp telemetry for test runs.
ENV USER=root \
    DO_NOT_TRACK=1

ARG YQ_VERSION=v4.53.3
RUN ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version
