# Anka Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Anka](https://docs.veertu.com/anka/what-is-anka/) virtual machines.

The plugin will create a cloned VM to run commands inside of and will then delete the VM on pipeline status `cancellation`, `failure`, or `success`.

You do not need to install the Buildkite agent in the VM, the plugin will do that for you using the host's Buildkite agent.

## Prerequisites

- You need to ensure your Anka Nodes (host machines running Anka software) have the Buildkite agent installed and show under your Agents listing inside of Buildkite.
- You need to [install the Anka CLI](https://docs.veertu.com/anka/anka-virtualization-cli/getting-started/installing-the-anka-virtualization-package/) on your host machines.


## Pipeline Step Definition Example

```yml
steps:
  - label: "Build"
    key: "build-key"
    command: make build
    plugins:
      - veertuinc/anka#v2.0.0:
          vm-name: 26.3-arm64
          copy-in-vm-path: "/tmp/buildkite-cache"
          copy-in-host-path: "/tmp/buildkite-cache/:agent_id:/:step_key:"
          copy-out-vm-path: "/tmp/buildkite-cache"
          copy-out-host-path: "/tmp/buildkite-cache/:agent_id:/:step_key:"

  - label: "Test"
    key: "test-key"
    command: make test
    depends_on:
      - "build-key"
    plugins:
      - veertuinc/anka#v2.0.0:
          vm-name: 26.3-arm64
          copy-in-vm-path: "/tmp/buildkite-cache"
          copy-in-host-path: "/tmp/buildkite-cache/:agent_id:/build-key"
          copy-out-vm-path: "/tmp/buildkite-cache"
          copy-out-host-path: "/tmp/buildkite-cache/:agent_id:/test-key"
```

This example runs two steps in sequence. The first step builds and copies `/tmp/buildkite-cache` from the VM to the host. The second step copies that cache from build-key into the VM (if it exists), runs tests, and copies the updated cache back for subsequent steps.

Note: Use `key` on steps when using `depends_on`.

## Hook Steps

Hook | Description
--- | ---
`pre-checkout` | Download the specified virtual machine template from your registry (if applicable).
`post-checkout` | Clone the virtual machine template to a temporary step-specific VM and perform any modifications to the VM (e.g. CPU, RAM, MAC address).
`pre-command` | Run any of your `pre-commands` (see below).
`command` | Start the cloned virtual machine, copy any files from the host to the VM, and then run `buildkite-agent bootstrap` inside. After, copy any files from the VM to the host.
`post-command` | Run any of your `post-commands` (see below).
`pre-exit` | Perform any clean up steps

## Step Configuration

### `vm-name` (required)

The name of the Anka VM Template to use as the base. The plugin will create a step-specific clone prior to execution.

Example: `macos-base`

### `vm-registry-tag` (optional)

The tag associated with the VM Template (`vm-name`) you wish to pull from the Anka Cloud Registry.

Example: `latest`

### `vm-registry-version` (optional)

A version associated with the VM Template you wish to pull from the Anka Registry (every tag has a version number assigned to it).

Example: `1`

### `always-pull` (optional)

By default, the `anka-buildkite-plugin` will only pull the VM Template from the Anka Registry if it's not on the Node. Set this value to `true` if you wish to pull the VM Template before the VM is cloned and started.

- Should your registry be down and the pull fail, the plugin will not fail the buildkite run. This prevents your registry from being a single point of failure for pipelines. We suggest monitoring for registry availability or failures.
- You can set the value to `"shrink"` in order to remove other local tags for the `vm-name`, optimizing the footprint.

Example: `true`

### `environment-file` (optional)

Path to an additional file of environment variables to pass into the VM. The agent's job environment is always passed; this option is for extra vars only.

Example: `./my-env.txt`

### `copy-in-host-path` (optional)

Host path to copy into the VM before `buildkite-agent bootstrap` runs. Supports `${BUILDKITE_*}` expansion where Buildkite interpolates (e.g. `${BUILDKITE_AGENT_ID}`). For step-specific values, use `:step_key:` or `:agent_id:` placeholders (Buildkite pre-interpolates plugin config and may omit step vars). Copy-in is skipped if the path does not exist on the host.

Must be used together with `copy-in-vm-path`.

Example: `"/tmp/buildkite-cache/${BUILDKITE_AGENT_ID}/:step_key:"` (quotes required for `:step_key:` in YAML)

### `copy-in-vm-path` (optional)

Destination path in the VM for `copy-in-host-path`.

Must be used together with `copy-in-host-path`.

Example: `/tmp/buildkite-cache`

### `copy-out-vm-path` (optional)

VM path to copy back to the host after `buildkite-agent bootstrap` exits.

Must be used together with `copy-out-host-path`.

Example: `/tmp/buildkite-cache`

### `copy-out-host-path` (optional)

Host destination for `copy-out-vm-path`. Supports `${BUILDKITE_*}` expansion where Buildkite interpolates (e.g. `${BUILDKITE_AGENT_ID}`). For step-specific values, use `:step_key:` or `:agent_id:` placeholders (Buildkite pre-interpolates plugin config and may omit step vars).

Must be used together with `copy-out-vm-path`.

Example: `"/tmp/buildkite-cache/${BUILDKITE_AGENT_ID}/:step_key:"` (quotes required for `:step_key:` in YAML)

Note: The plugin creates `copy-out-host-path` if it does not exist. Copy-out copies the *contents* of the VM path into the host path (not the folder itself). Use `:step_key:` and `:agent_id:` placeholders for step-specific paths; Buildkite pre-interpolates plugin config and may omit `${BUILDKITE_STEP_KEY}`.

### `wait-time` (optional)

When enabled, the plugin runs `sleep` inside the VM before bootstrap to allow sntp to update the system time. Use `true` for a 10-second default, or an integer for custom seconds.

Example: `true` or `15`

### Deprecated and Removed Options

The following options were removed in v2.0.0: `workdir`, `workdir-create`, `bash-interactive`, `pre-execute-sleep`, `pre-execute-ping-sleep`, `wait-network`, `volume`, `no-volume`.

### `debug` (optional)

Set this to `true` to enable debug output within the plugin.

Example: `true`

### `anka-debug` (optional)

Set this to `true` to enable anka --debug output when running anka commands.

Example: `true`

### `cleanup` (optional)

Set this to `false` to leave the cloned images in a failed or complete build for investigation.
- You will need to run your buildkite agent with `cancel-grace-period=60`, as the [default 10 seconds is not enough time](https://forum.buildkite.community/t/problems-with-anka-plugin-and-pre-exit/365/7).

Example: `false`

### `pre-commands` (optional) (DANGEROUS)

Commands to run on the HOST machine BEFORE any guest/anka run commands. Useful if you need to download buildkite artifacts into the current working directory from a previous step. This can destroy your host. Be very careful what you do with it.

> Be sure to double escape variables you don't want eval to try and interpolate too soon.

```yml
steps:
  - command: make test
    plugins:
      - veertuinc/anka#v2.0.0:
          vm-name: macos-base
          pre-commands:
            - 'echo 123 && echo 456'
            - 'buildkite-agent artifact download "build.tar.gz" . --step "build"'
            - 'echo \\$variableOnTheHost'
```

### `post-commands` (optional) (DANGEROUS)

Commands to run on the HOST machine AFTER any guest/anka run commands. Useful if you need to upload artifacts created in the build/test process. This can destroy your host. Be very careful what you do with it.

Hint: Cloned VM names become `${vm_name}-${BUILDKITE_JOB_ID}`, so use that in the `post-commands` to target the proper VM to copy files out of.

Example: A YAML list, similar to pre-commands.

### `failover-registries` (optional)

Should the default registry not be available, the failover registries you specify will be used. It will go through each in the list and use the first available.

```yml
steps:
  - command: make test
    plugins:
      - veertuinc/anka#v2.0.0:
          vm-name: macos-base
          failover-registries:
            - 'registry_1'
            - 'registry_2'
            - 'registry_3'
```

## Anka Modify ---

### `modify-cpu` (optional)

Will stop the VM, set CPU cores, and then execute commands you've specified.

Example: `6`

### `modify-ram` (optional)

Will stop the VM, set memory size, and then execute commands you've specified.

- Input is interpreted as G; if you input 32, it will use 32G in the anka modify command.

Example: `32`

### `modify-mac` (optional)

Will stop the VM, set the MAC address, and then execute commands you've specified.

Example: `00:1B:44:11:3A:B7`


## Notes

- If `buildkite-agent` is not in the VM's `PATH`, the plugin copies it from the host into `/usr/local/bin`. If it already exists in the VM, it will not be copied again.
- A lock file (`/tmp/anka-buildkite-plugin-lock`) is created around pull and cloning. This prevents collision/ram state corruption when you're running two different jobs and pulling two different tags on the same anka node. The error you'd see otherwise is `state_lib/b026f71c-7675-11e9-8883-f01898ec0a5d.ank: failed to open image, error 2`

