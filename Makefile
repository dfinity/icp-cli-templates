# Template testing pipeline — see docs/template-testing-prd.md.
# Tests always run inside the container, against the icp CLI pinned in the
# image; the host only needs Docker.

IMAGE ?= icp-template-tests
# Optional permutation filter, e.g. `make test FILTER=hello-world:rust:react`
FILTER ?=

.PHONY: test test-image

test-image:
	docker build -t $(IMAGE) tests

# Named volumes keep dependency caches warm across local runs.
CACHE_VOLUMES = \
	-v $(IMAGE)-cargo:/usr/local/cargo/registry \
	-v $(IMAGE)-npm:/root/.npm \
	-v $(IMAGE)-cache:/root/.cache

test: test-image
	docker run --rm -v "$(CURDIR)":/repo:ro $(CACHE_VOLUMES) $(IMAGE) /repo/tests/run.sh $(FILTER)
