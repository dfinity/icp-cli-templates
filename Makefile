# Template testing pipeline — see docs/template-testing-prd.md.
# Tests always run inside the container, against the icp CLI pinned in the
# image; the host only needs Docker.

IMAGE ?= icp-template-tests

.PHONY: test test-image

test-image:
	docker build -t $(IMAGE) tests

test: test-image
	docker run --rm -v "$(CURDIR)":/repo:ro $(IMAGE) /repo/tests/run.sh
