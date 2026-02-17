VERSION = $(shell cat VERSION)

.PHONY: lint shellcheck bats

all: lint bats shellcheck

lint:
	docker run --rm -v "$(PWD):/plugin" buildkite/plugin-linter:v3.0.0 --id veertuinc/anka

bats:
	docker compose run --rm tests

shellcheck:
	docker run --rm -v "$(PWD):/mnt" koalaman/shellcheck:stable hooks/*