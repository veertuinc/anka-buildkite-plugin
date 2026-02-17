VERSION = $(shell cat VERSION)

.PHONY: lint shellcheck bats

all: lint bats shellcheck

lint:
	docker run --rm -v "$(PWD):/plugin" buildkite/plugin-linter:v3.0.0 --id veertuinc/anka

bats:
	docker run --rm -v "$(PWD):/plugin" buildkite/plugin-tester:v4.3.0

shellcheck:
	docker run --rm -v "$(PWD):/mnt" koalaman/shellcheck:stable hooks/*