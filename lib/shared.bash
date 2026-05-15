#!/bin/bash

# Guest-visible root for host directory shares (Apple-enforced; Anka 3.9.0+). See:
# https://docs.veertu.com/anka/whats-new/anka-3.9.0/#ability-to-mount-host-directories-inside-of-the-vm
readonly ANKA_VM_HOST_DIRECTORY_SHARE_ROOT="/Volumes/My Shared Files"
readonly ANKA_VM_HOST_DIRECTORY_MOUNT_MINIMUM_CLI_VERSION="3.9.0"

# Returns 0 when dotted semver $1 is >= dotted semver $2 (numeric comparison per segment).
function anka_semver_is_at_least() {
  local actual_version="$1"
  local required_version="$2"
  local -a actual_segments required_segments
  local actual_major actual_minor actual_patch required_major required_minor required_patch
  IFS='.' read -ra actual_segments <<<"$actual_version"
  IFS='.' read -ra required_segments <<<"$required_version"
  actual_major="${actual_segments[0]:-0}"
  actual_minor="${actual_segments[1]:-0}"
  actual_patch="${actual_segments[2]:-0}"
  required_major="${required_segments[0]:-0}"
  required_minor="${required_segments[1]:-0}"
  required_patch="${required_segments[2]:-0}"
  ((actual_major > required_major)) && return 0
  ((actual_major < required_major)) && return 1
  ((actual_minor > required_minor)) && return 0
  ((actual_minor < required_minor)) && return 1
  ((actual_patch >= required_patch))
}

# Prints X.Y.Z or X.Y parsed from `anka version`, preferring full three-part semver lines.
function anka_cli_semver_from_version_command() {
  local version_output extracted_three extracted_two
  version_output="$(anka version 2>/dev/null || true)"
  extracted_three="$(printf '%s\n' "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  if [[ -n "$extracted_three" ]]; then
    printf '%s' "$extracted_three"
    return 0
  fi
  extracted_two="$(printf '%s\n' "$version_output" | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  if [[ -n "$extracted_two" ]]; then
    printf '%s' "$extracted_two"
    return 0
  fi
  printf ''
}

# Normalizes two-component semver to three-component (e.g. 3.9 -> 3.9.0).
function anka_semver_normalize_patch_level() {
  local version="$1"
  if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    printf '%s.0' "$version"
  else
    printf '%s' "$version"
  fi
}

# Validates optional guest folder name for `anka modify … mount host_path[:guest_folder_name]`.
function plugin_mount_guest_folder_name() {
  local guest_folder_name
  guest_folder_name="$(plugin_read_config MOUNT_GUEST_FOLDER_NAME buildkite)"
  if [[ -z "$guest_folder_name" ]]; then
    echo "ERROR: mount-guest-folder-name cannot be empty." >&2
    exit 1
  fi
  if [[ "$guest_folder_name" == *"/"* ]]; then
    echo "ERROR: mount-guest-folder-name must not contain '/'." >&2
    exit 1
  fi
  printf '%s' "$guest_folder_name"
}

# Absolute guest path where the shared host folder appears (…/My Shared Files/<name>).
function plugin_guest_path_for_host_directory_mount() {
  printf '%s/%s' "$ANKA_VM_HOST_DIRECTORY_SHARE_ROOT" "$(plugin_mount_guest_folder_name)"
}

function plugin_assert_anka_cli_supports_host_directory_mounts() {
  local parsed_version normalized_version
  parsed_version="$(anka_cli_semver_from_version_command)"
  normalized_version="$(anka_semver_normalize_patch_level "${parsed_version:-}")"
  if [[ -z "$normalized_version" ]]; then
    echo "ERROR: Could not determine Anka CLI version from 'anka version'. Host directory mounts require Anka Virtualization ${ANKA_VM_HOST_DIRECTORY_MOUNT_MINIMUM_CLI_VERSION}+." >&2
    exit 1
  fi
  if ! anka_semver_is_at_least "$normalized_version" "$ANKA_VM_HOST_DIRECTORY_MOUNT_MINIMUM_CLI_VERSION"; then
    echo "ERROR: Host directory mounts require Anka CLI (Virtualization package) ${ANKA_VM_HOST_DIRECTORY_MOUNT_MINIMUM_CLI_VERSION} or newer (found ${normalized_version}). See https://docs.veertu.com/anka/whats-new/anka-3.9.0/#ability-to-mount-host-directories-inside-of-the-vm" >&2
    exit 1
  fi
}

# Shows the command being run, and runs it
function plugin_prompt_and_run() {
  if [[ $(plugin_read_config DEBUG "false") =~ (true|on|1) ]] ; then
    echo -ne '\033[90m$\033[0m' >&2
    # Avoid printf write error with many args (e.g. dozens of -e VAR=value)
    if [[ $# -gt 20 ]]; then
      printf " %q" "${@:1:5}" >&2
      printf " ... (%d args) %q %q" $# "${@: -2:1}" "${@: -1}" >&2
    else
      printf " %q" "$@" >&2
    fi
    echo >&2
  fi
  "$@"
}

# Shorthand for reading env config
function plugin_read_config() {
  local var="BUILDKITE_PLUGIN_ANKA_${1}"
  local default="${2:-}"
  echo "${!var:-$default}"
}

# Expands ${VAR} and :placeholder: in a string. Buildkite interpolates plugin config
# when creating jobs; step-specific vars (e.g. BUILDKITE_STEP_KEY) may be unset then.
# Use :step_key: and :agent_id: for values Buildkite may not interpolate correctly.
function expand_env_in_path() {
  local s="$1"
  local var val
  for var in $(printf '%s\n' "${!BUILDKITE_@}" | sort -u); do
    [[ -n "${!var:-}" ]] || continue
    val="${!var}"
    val="${val//\\/\\\\}"
    val="${val//&/\\&}"
    s="${s//\$\{$var\}/$val}"
  done
  # Plugin placeholders (Buildkite won't interpolate these)
  [[ -n "${BUILDKITE_STEP_KEY:-}" ]] && s="${s//:step_key:/${BUILDKITE_STEP_KEY}}"
  [[ -n "${BUILDKITE_AGENT_ID:-}" ]] && s="${s//:agent_id:/${BUILDKITE_AGENT_ID}}"
  printf '%s' "$s"
}

# Reads either a value or a list from plugin config
function plugin_read_list() {
  prefix_read_list "BUILDKITE_PLUGIN_ANKA_$1"
}

# Reads either a value or a list from the given env prefix
function prefix_read_list() {
  local prefix="$1"
  local parameter="${prefix}_0"

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    echo "${!prefix}"
  fi
}

function in_array() {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Clean up job VM (delete or suspend) and lock file. Safe to call from trap or pre-exit.
# Requires: job_image_name, BUILDKITE_JOB_ID, plugin_read_config, plugin_prompt_and_run, ANKA_DEBUG
function cleanup_job_vm() {
  [[ -z "${job_image_name:-}" ]] && return 0
  lock_file disable
  # shellcheck disable=SC2091
  if $(plugin_read_config CLEANUP true); then
    echo "--- :anka: Cleaning up clone (cancellation or exit)" >&2
    # shellcheck disable=SC2086
    anka $ANKA_DEBUG delete --yes "$job_image_name" 2>/dev/null || true
    echo "$job_image_name has been deleted" >&2
  else
    echo "--- :anka: Suspending clone (cancellation or exit)" >&2
    # shellcheck disable=SC2086
    anka $ANKA_DEBUG suspend "$job_image_name" 2>/dev/null || true
    echo "$job_image_name has been suspended" >&2
  fi
}

function lock_file() {
  [[ -z "${1}" ]] && echo "lock_file function requires a single argument" && exit 1
  LOCK_FILE="/tmp/anka-buildkite-plugin-lock"
  if [[ "$1" == "enable" ]]; then
    # Check if lock file already exists and prevent doing anything until it's deleted by the job which created it
    if [[ -f "$LOCK_FILE" ]]; then
      echo "Lock file found on host: Waiting for existing job ($(tail -1 "$LOCK_FILE")) to remove lock file..."
      while [[ -f "$LOCK_FILE" ]]; do
        sleep 5
      done
    fi
    plugin_prompt_and_run echo "$BUILDKITE_BUILD_URL" > "$LOCK_FILE"
    echo "[Created ${LOCK_FILE}]"
  elif [[ "$1" == "disable" ]]; then
    if [[ -f "$LOCK_FILE" ]]; then # Prevent echo and cleanup on pre-exit if it's not needed
      plugin_prompt_and_run rm -f "$LOCK_FILE"
      echo "[Deleted ${LOCK_FILE}]"
    fi
  else
    echo "Requires first argument is either 'enable' or 'disable'"
    exit 1
  fi
}

##############
# Anka --debug
export BUILDKITE_PLUGIN_ANKA_ANKA_DEBUG=$(plugin_read_config ANKA_DEBUG false)
"$BUILDKITE_PLUGIN_ANKA_ANKA_DEBUG" && export ANKA_DEBUG="--debug" || export ANKA_DEBUG=

###################
# Registry Failover
export BUILDKITE_PLUGIN_ANKA_FAILOVER_REGISTRIES=$(plugin_read_list FAILOVER_REGISTRIES)
export FAILOVER_REGISTRY=
if [[ -n "${BUILDKITE_PLUGIN_ANKA_FAILOVER_REGISTRIES}" ]]; then
  if [[ ! $(anka registry list) ]]; then
    # Remove the default (which should be down)
    DEFAULT_REGISTRY=$(anka registry list-repos -d | grep id | cut -d' ' -f8)
    for registry in $BUILDKITE_PLUGIN_ANKA_FAILOVER_REGISTRIES; do # Grab the first available registry from the list
      [[ "$registry" == "$DEFAULT_REGISTRY" ]] && continue
      [[ -n "$FAILOVER_REGISTRY" ]] && continue
      [[ $(anka registry -r "$registry" list) ]] && export FAILOVER_REGISTRY="-r $registry" || continue
    done
  fi
fi
