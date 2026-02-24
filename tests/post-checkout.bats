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

@test "Modify" {
  export BUILDKITE_PLUGIN_ANKA_MODIFY_CPU="6"
  export BUILDKITE_PLUGIN_ANKA_MODIFY_RAM="32"
  export BUILDKITE_PLUGIN_ANKA_MODIFY_MAC="00:1B:44:11:3A:B7"

  stub anka \
    "clone $VM $JOB_IMAGE : echo 'cloned vm'" \
    "list $JOB_IMAGE : echo 'suspended'" \
    "stop --force $JOB_IMAGE : echo 'stopped'" \
    "modify $JOB_IMAGE set cpu 6 : echo 'set cpu 6'" \
    "modify $JOB_IMAGE set ram 32G : echo 'set ram 32G'" \
    "modify $JOB_IMAGE set network-card --mac 00:1B:44:11:3A:B7 : echo 'set network-card mac address to 00:1B:44:11:3A:B7'"

  run $PWD/hooks/post-checkout

  assert_success
  assert_output --partial "cloned vm"
  assert_output --partial "stopped"
  assert_output --partial "set cpu 6"
  assert_output --partial "set ram 32G"
  assert_output --partial "set network-card mac address to 00:1B:44:11:3A:B7"

  unset BUILDKITE_PLUGIN_ANKA_MODIFY_MAC
  unset BUILDKITE_PLUGIN_ANKA_MODIFY_RAM
  unset BUILDKITE_PLUGIN_ANKA_MODIFY_CPU
}

@test "Modify CPU Failure" {
  export BUILDKITE_PLUGIN_ANKA_MODIFY_CPU="t"

  stub anka \
    "clone $VM $JOB_IMAGE : echo 'cloned vm'" \
    "list $JOB_IMAGE : echo 'suspended'" \
    "stop --force $JOB_IMAGE : echo 'stopped'"

  run $PWD/hooks/post-checkout

  assert_failure
  assert_output --partial "cloned vm"
  assert_output --partial "stopped"
  assert_output --partial "Acceptable input"

  unset BUILDKITE_PLUGIN_ANKA_MODIFY_CPU
}

@test "Modify RAM Failure" {
  export BUILDKITE_PLUGIN_ANKA_MODIFY_RAM="t"

  stub anka \
    "clone $VM $JOB_IMAGE : echo 'cloned vm'" \
    "list $JOB_IMAGE : echo 'suspended'" \
    "stop --force $JOB_IMAGE : echo 'stopped'"

  run $PWD/hooks/post-checkout

  assert_failure
  assert_output --partial "cloned vm"
  assert_output --partial "stopped"
  assert_output --partial "Acceptable input"

  unset BUILDKITE_PLUGIN_ANKA_MODIFY_RAM
}

@test "Modify MAC Failure" {
  export BUILDKITE_PLUGIN_ANKA_MODIFY_MAC="192.14"

  stub anka \
    "clone $VM $JOB_IMAGE : echo 'cloned vm'" \
    "list $JOB_IMAGE : echo 'suspended'" \
    "stop --force $JOB_IMAGE : echo 'stopped'"

  run $PWD/hooks/post-checkout

  assert_failure
  assert_output --partial "cloned vm"
  assert_output --partial "stopped"
  assert_output --partial "Acceptable input"

  unset BUILDKITE_PLUGIN_ANKA_MODIFY_MAC
}

@test "Modify --force" {
  export BUILDKITE_PLUGIN_ANKA_MODIFY_CPU="6"
  export BUILDKITE_PLUGIN_ANKA_MODIFY_RAM="32"
  export FORCED=true

  stub anka \
    "clone $VM $JOB_IMAGE : echo 'cloned vm'" \
    "stop --force $JOB_IMAGE : echo 'stopped'" \
    "modify $JOB_IMAGE set cpu 6 : echo 'set cpu 6'" \
    "modify $JOB_IMAGE set ram 32G : echo 'set ram 32'"

  run $PWD/hooks/post-checkout

  assert_output --partial "stopped"

  unset BUILDKITE_PLUGIN_ANKA_MODIFY_RAM
  unset BUILDKITE_PLUGIN_ANKA_MODIFY_CPU
  unset FORCED
}
