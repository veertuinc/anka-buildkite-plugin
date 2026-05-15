#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

. "lib/shared.bash"

@test "Run with failure" {
  run -127 plugin_prompt_and_run builddude
  # assert_output --partial "echo downloaded artifact2"
  [[ $status -eq 127 ]] || ( echo "Status must be 127" >&3 && exit 1 )
  run exit 5
  # assert_output --partial "echo downloaded artifact2"
  [[ $status -eq 5 ]] || ( echo "Status must be 5" >&3 && exit 1 )
}

@test "anka_semver_is_at_least compares dotted versions" {
  anka_semver_is_at_least "3.9.0" "3.9.0"
  anka_semver_is_at_least "3.10.0" "3.9.0"
  anka_semver_is_at_least "4.0.0" "3.9.0"
  ! anka_semver_is_at_least "3.8.99" "3.9.0"
}

@test "anka_semver_normalize_patch_level adds patch when missing" {
  [[ "$(anka_semver_normalize_patch_level "3.9")" == "3.9.0" ]]
  [[ "$(anka_semver_normalize_patch_level "3.9.1")" == "3.9.1" ]]
}
