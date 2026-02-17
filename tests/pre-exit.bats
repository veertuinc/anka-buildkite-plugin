#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export ANKA_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_JOB_ID="UUID"
  export BUILDKITE_PLUGIN_ANKA_VM_NAME="test"
  VM="$BUILDKITE_PLUGIN_ANKA_VM_NAME"
  JOB_IMAGE="${VM}-${BUILDKITE_JOB_ID}"
}

teardown() {
  unstub anka
  unset BUILDKITE_JOB_ID
  unset BUILDKITE_PLUGIN_ANKA_VM_NAME
}

@test "Cleanup of lock file" {
  stub anka \
    "delete --yes $JOB_IMAGE : echo 'deleted vm in anka'"

  touch /tmp/anka-buildkite-plugin-lock

  run $PWD/hooks/pre-exit

  assert_success
  assert_output --partial "Deleted /tmp/anka-buildkite-plugin-lock"
}

@test "Cleanup pre-exit runs properly (delete)" {
  stub anka \
    "delete --yes $JOB_IMAGE : echo 'deleted vm in anka'"

  run $PWD/hooks/pre-exit

  assert_success
  assert_output --partial "deleted vm in anka"
}

@test "Cleanup pre-exit runs properly (suspend)" {
  export BUILDKITE_PLUGIN_ANKA_CLEANUP=false

  stub anka \
    "suspend $JOB_IMAGE : echo 'suspended vm in anka'"

  run $PWD/hooks/pre-exit

  assert_success
  assert_output --partial "suspended vm in anka"

  unset BUILDKITE_PLUGIN_ANKA_CLEANUP
}
