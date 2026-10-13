IMAGE ?= luul-orders-service
SHA   := $(shell git rev-parse --short HEAD 2>/dev/null || echo local)

.PHONY: lint test-unit test-e2e test run build hooks

lint:        ## syntax check
	python3 -m py_compile app/*.py tests/unit/*.py tests/e2e/*.py

test-unit: lint   ## developers' tests
	python3 -m unittest discover -s tests/unit -t . -v

test-e2e:    ## QA's end-to-end tests (set BASE_URL to test a deployed env)
	python3 -m unittest discover -s tests/e2e -t . -v

test: test-unit test-e2e

run:
	python3 -m app.main

build:
	docker build --build-arg GIT_SHA=$(SHA) -t $(IMAGE):$(SHA) .

hooks:       ## install the team's git hooks (blocks secrets, big files, commits on main)
	./scripts/install-hooks.sh
