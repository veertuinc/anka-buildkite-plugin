#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export BATS_MOCK_DETAIL=/dev/tty
# export ANKA_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_JOB_ID="UUID"
  export BUILDKITE_PLUGIN_ANKA_VM_NAME="26.2"
  export BUILDKITE_COMMAND='command "a string"'
  export BUILDKITE_REPO="git@github.com:org/repo.git"
  export BUILDKITE_COMMIT="abc123"
  VM="$BUILDKITE_PLUGIN_ANKA_VM_NAME"
  JOB_IMAGE="${VM}-${BUILDKITE_JOB_ID}"
}

teardown() {
  unstub anka

  unset BUILDKITE_JOB_ID
  unset BUILDKITE_PLUGIN_ANKA_VM_NAME
  unset BUILDKITE_COMMAND
  unset BUILDKITE_REPO
  unset BUILDKITE_COMMIT
}

@test "Run buildkite-agent bootstrap in VM" {
  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran bootstrap in anka"
}

@test "Run buildkite-agent bootstrap with inherited env vars" {
  export BUILDKITE_PLUGIN_ANKA_INHERIT_ENVIRONMENT_VARS="true"

  stub anka \
    "run --env $JOB_IMAGE true : echo 'vm ok'" \
    "run --env $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run --env $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran bootstrap in anka"

  unset BUILDKITE_PLUGIN_ANKA_INHERIT_ENVIRONMENT_VARS
}

@test "Run buildkite-agent bootstrap with env vars from file" {
  export BUILDKITE_PLUGIN_ANKA_ENVIRONMENT_FILE="./env-file"

  stub anka \
    "run --env-file ./env-file $JOB_IMAGE true : echo 'vm ok'" \
    "run --env-file ./env-file $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run --env-file ./env-file $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran bootstrap in anka"

  unset BUILDKITE_PLUGIN_ANKA_ENVIRONMENT_FILE
}

@test "Run buildkite-agent bootstrap and wait for time" {
  export BUILDKITE_PLUGIN_ANKA_WAIT_TIME="true"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE sleep 10 : echo 'waited'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "waited"
  assert_output --partial "ran bootstrap in anka"

  unset BUILDKITE_PLUGIN_ANKA_WAIT_TIME
}

@test "Run buildkite-agent bootstrap with custom wait-time seconds" {
  export BUILDKITE_PLUGIN_ANKA_WAIT_TIME="15"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE sleep 15 : echo 'waited 15s'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "waited 15s"
  assert_output --partial "ran bootstrap in anka"

  unset BUILDKITE_PLUGIN_ANKA_WAIT_TIME
}

@test "Copy host path into VM before bootstrap" {
  export BUILDKITE_PLUGIN_ANKA_COPY_IN_HOST_PATH="./.cache"
  export BUILDKITE_PLUGIN_ANKA_COPY_IN_VM_PATH="/private/var/tmp/cache"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "cp -a ./.cache $JOB_IMAGE:/private/var/tmp/cache : echo 'copied into vm'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "copied into vm"
  assert_output --partial "ran bootstrap in anka"

  unset BUILDKITE_PLUGIN_ANKA_COPY_IN_HOST_PATH
  unset BUILDKITE_PLUGIN_ANKA_COPY_IN_VM_PATH
}

@test "Copy VM path to host after bootstrap" {
  export BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH="/private/var/tmp/cache"
  export BUILDKITE_PLUGIN_ANKA_COPY_OUT_HOST_PATH="./.cache"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'" \
    "cp -a $JOB_IMAGE:/private/var/tmp/cache ./.cache : echo 'copied out of vm'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran bootstrap in anka"
  assert_output --partial "copied out of vm"

  unset BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH
  unset BUILDKITE_PLUGIN_ANKA_COPY_OUT_HOST_PATH
}

@test "Copy VM path to host after bootstrap failure" {
  export BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH="/private/var/tmp/cache"
  export BUILDKITE_PLUGIN_ANKA_COPY_OUT_HOST_PATH="./.cache"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : echo '/usr/local/bin/buildkite-agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'bootstrap failed'; exit 1" \
    "cp -a $JOB_IMAGE:/private/var/tmp/cache ./.cache : echo 'copied out of vm'"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "bootstrap failed"
  assert_output --partial "copied out of vm"

  unset BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH
  unset BUILDKITE_PLUGIN_ANKA_COPY_OUT_HOST_PATH
}

@test "Copy buildkite-agent from host when not in VM" {
  fake_agent_dir="$(mktemp -d)"
  touch "${fake_agent_dir}/buildkite-agent"
  chmod +x "${fake_agent_dir}/buildkite-agent"
  export PATH="${fake_agent_dir}:${PATH}"

  stub anka \
    "run $JOB_IMAGE true : echo 'vm ok'" \
    "run $JOB_IMAGE bash -c 'command -v buildkite-agent' : exit 1" \
    "run $JOB_IMAGE bash -c 'set -x; if [ ! -d /usr/local/bin ]; then sudo mkdir -p /usr/local/bin && sudo chown \"\$(whoami)\" /usr/local/bin; fi' : echo 'mkdir ok'" \
    "cp -a ${fake_agent_dir}/buildkite-agent $JOB_IMAGE:/usr/local/bin/ : echo 'copied agent'" \
    "run $JOB_IMAGE buildkite-agent bootstrap --job UUID --command 'command \"a string\"' --repository git@github.com:org/repo.git --commit abc123 : echo 'ran bootstrap in anka'"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "copying from host"
  assert_output --partial "copied agent"
  assert_output --partial "ran bootstrap in anka"

  rm -rf "${fake_agent_dir}"
}

@test "Exit when VM is not functional" {
  stub anka \
    "run $JOB_IMAGE true : exit 1"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "VM ${JOB_IMAGE} is not functional"
}

@test "Require both copy-in options" {
  export BUILDKITE_PLUGIN_ANKA_COPY_IN_HOST_PATH="./.cache"

  stub anka "run $JOB_IMAGE true : echo 'vm ok'"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "Both copy-in-host-path and copy-in-vm-path are required together."

  unset BUILDKITE_PLUGIN_ANKA_COPY_IN_HOST_PATH
}

@test "Require both copy-out options" {
  export BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH="/private/var/tmp/cache"

  stub anka "run $JOB_IMAGE true : echo 'vm ok'"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "Both copy-out-vm-path and copy-out-host-path are required together."

  unset BUILDKITE_PLUGIN_ANKA_COPY_OUT_VM_PATH
}
