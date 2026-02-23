# Anka Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Anka](https://docs.veertu.com/anka/what-is-anka/) virtual machines.

- You need to ensure your Anka Nodes (host machines running Anka software) have the Buildkite agent installed and show under your Agents listing inside of Buildkite.
- The plugin will create a cloned VM to run instructions in and will delete the VM on pipeline status `cancellation`, `failure`, or `success`.
- The plugin executes `buildkite-agent bootstrap` inside of the cloned VM during the `command` hook.
- If `buildkite-agent` is not in the VM's `PATH`, the plugin copies it from the host into `/usr/local/bin`.
- A lock file (`/tmp/anka-buildkite-plugin-lock`) is created around pull and cloning. This prevents collision/ram state corruption when you're running two different jobs and pulling two different tags on the same anka node. The error you'd see otherwise is `state_lib/b026f71c-7675-11e9-8883-f01898ec0a5d.ank: failed to open image, error 2`

## Bootstrap Execution

The plugin now runs the Buildkite bootstrap process in the VM (`buildkite-agent bootstrap`) instead of evaluating `BUILDKITE_COMMAND` line-by-line through `bash -c`.

- Buildkite bootstrap reference: <https://buildkite.com/docs/agent/cli/reference/bootstrap#running-the-bootstrap-usage>
- Use `environment-file` if you need additional environment values available in the guest VM runtime (host env is always passed for bootstrap).
- Use `copy-in-*` and `copy-out-*` options for explicit host/guest directory sync (for example, build cache round trips).

## Anka VM [Template & Tag](https://docs.veertu.com/anka/anka-virtualization-cli/getting-started/creating-vms/#vm-clones) Requirements

1. In the VM, make sure remote login is enabled (`System Settings > General > Sharing`).

## Pipeline Step Definition Example

```yml
steps:
  - command: make test
    agents: "queue=mac-anka-large-node-fleet"
    plugins:
      - veertuinc/anka#v1.0.0:
          vm-name: macos-base
```

## Hook Steps

Hook | Description
--- | ---
`pre-checkout` | Download the specified virtual machine from your registry (if applicable).
`post-checkout` | Clone the virtual machine and perform any hardware modifications.
`pre-command` | Run any of your `pre-commands` (see below).
`command` | Run `buildkite-agent bootstrap` inside of the cloned virtual machine.
`post-command` | Run any of your `post-commands` (see below).
`pre-exit` | Perform any clean up steps

## Configuration

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

The path to a file containing environment variables you wish to inject into you Anka VM.

Example: `./my-env.txt`

### `copy-in-host-path` (optional)

Host path to copy into the VM before `buildkite-agent bootstrap` runs.

Must be used together with `copy-in-vm-path`.

Example: `./.build-cache`

### `copy-in-vm-path` (optional)

Destination path in the VM for `copy-in-host-path`.

Must be used together with `copy-in-host-path`.

Example: `/private/var/tmp/cache`

### `copy-out-vm-path` (optional)

VM path to copy back to the host after `buildkite-agent bootstrap` exits.

Must be used together with `copy-out-host-path`.

Example: `/private/var/tmp/cache`

### `copy-out-host-path` (optional)

Host destination for `copy-out-vm-path`.

Must be used together with `copy-out-vm-path`.

Example: `./.build-cache`

### Copy Round-Trip Example

```yml
steps:
  - command: make test
    agents: "queue=mac-anka-large-node-fleet"
    plugins:
      - veertuinc/anka#v2.0.0:
         vm-name: macos-base
         copy-in-host-path: ./.build-cache
         copy-in-vm-path: /private/var/tmp/cache
         copy-out-vm-path: /private/var/tmp/cache
         copy-out-host-path: ./.build-cache
```

### Deprecated and Removed Options

The following options were removed as part of moving execution to full in-VM bootstrap:

- `workdir`
- `workdir-create`
- `bash-interactive`
- `pre-execute-sleep`
- `pre-execute-ping-sleep`
- `wait-network`

### `wait-time` (optional)

The `anka run` CLI has no `--wait-time` option. When enabled, the plugin runs `sleep` inside the VM before bootstrap to allow sntp to update the system time. Use `true` for a 10-second default, or an integer for custom seconds.

Example: `true` or `15`

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
    agents: "queue=mac-anka-large-node-fleet"
    plugins:
      - veertuinc/anka#v0.8.0:
          vm-name: macos-base
          pre-commands:
            - 'echo 123 && echo 456'
            - 'buildkite-agent artifact download "build.tar.gz" . --step ":aws: Amazon Linux 1 Build"'
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
    agents: "queue=mac-anka-large-node-fleet"
    plugins:
      - veertuinc/anka#v0.8.0:
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