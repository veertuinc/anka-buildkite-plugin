lint:
	docker run -it --rm -v "$(PWD):/plugin" buildkite/plugin-linter --id veertuinc/anka

bats:
	docker-compose run tests

shellcheck:
	shellcheck hooks/**
