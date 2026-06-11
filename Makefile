# Template testing pipeline — see tests/README.md.
# Tests always run inside the container, against the icp CLI pinned in the
# image; the host only needs Docker.

# Official ICP dev environment; the tag pins the icp CLI version under test.
IMAGE ?= ghcr.io/dfinity/icp-dev-env-all:0.3.2
# Optional permutation filter, e.g. `make test FILTER=hello-world:rust:react`
FILTER ?=

# Named volumes keep dependency caches warm across local runs.
CACHE_VOLUMES = \
	-v icp-template-tests-cargo:/usr/local/cargo/registry \
	-v icp-template-tests-npm:/root/.npm \
	-v icp-template-tests-cache:/root/.cache

.PHONY: test

test:
	docker run --rm -v "$(CURDIR)":/repo:ro $(CACHE_VOLUMES) $(IMAGE) /repo/tests/run.sh $(FILTER)
