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

| Option | Required | Description | Example |
|--------|----------|-------------|---------|
| `vm-name` | Yes | Anka VM Template to use as the base. The plugin creates a step-specific clone prior to execution. | `macos-base` |
| `vm-registry-tag` | No | Tag for the VM Template to pull from the Anka Cloud Registry. | `latest` |
| `vm-registry-version` | No | Version number for the VM Template in the Anka Registry. | `1` |
| `always-pull` | No | Pull the VM Template before cloning. Use `true` or `"shrink"` to remove other local tags. Registry failures do not fail the build. | `true` |
| `environment-file` | No | Path to a file with additional environment variables to inject into the VM. The agent's job environment is always passed. | `./my-env.txt` |
| `copy-in-host-path` | No | Host path to copy into the VM before bootstrap. Use `:step_key:` and `:agent_id:` placeholders. Copy-in is skipped if the path does not exist. Requires `copy-in-vm-path`. | `"/tmp/buildkite-cache/:agent_id:/:step_key:"` |
| `copy-in-vm-path` | No | Destination path in the VM for `copy-in-host-path`. Requires `copy-in-host-path`. | `/tmp/buildkite-cache` |
| `copy-out-vm-path` | No | VM path to copy back to the host after bootstrap. Requires `copy-out-host-path`. | `/tmp/buildkite-cache` |
| `copy-out-host-path` | No | Host destination for `copy-out-vm-path`. Use `:step_key:` and `:agent_id:` placeholders. Copy-out copies *contents* (not the folder). Created if missing. Requires `copy-out-vm-path`. | `"/tmp/buildkite-cache/:agent_id:/:step_key:"` |
| `wait-time` | No | Run `sleep` inside the VM before bootstrap for sntp time sync. Use `true` for 10s default, or an integer for custom seconds. | `true` or `15` |
| `debug` | No | Enable debug output within the plugin. | `true` |
| `anka-debug` | No | Enable `anka --debug` output when running anka commands. | `true` |
| `cleanup` | No | Set to `false` to leave cloned images for investigation. Use `cancel-grace-period=60` on the agent. | `false` |
| `pre-commands` | No | **(DANGEROUS)** Commands to run on the HOST before guest commands. E.g. download artifacts. Double-escape variables. | YAML list |
| `post-commands` | No | **(DANGEROUS)** Commands to run on the HOST after guest commands. E.g. upload artifacts. VM names are `${vm_name}-${BUILDKITE_JOB_ID}`. | YAML list |
| `failover-registries` | No | List of registries to try if the default is unavailable. Uses the first available. | `['registry_1', 'registry_2']` |
| `modify-cpu` | No | Stop VM, set CPU cores, then run commands. | `6` |
| `modify-ram` | No | Stop VM, set memory (G), then run commands. | `32` |
| `modify-mac` | No | Stop VM, set MAC address, then run commands. | `00:1B:44:11:3A:B7` |

**Deprecated and removed (v2.0.0):** `workdir`, `workdir-create`, `bash-interactive`, `pre-execute-sleep`, `pre-execute-ping-sleep`, `wait-network`, `volume`, `no-volume`

### Example: `pre-commands` and `post-commands`

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

### Example: `failover-registries`

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


## Notes

- If `buildkite-agent` is not in the VM's `PATH`, the plugin copies it from the host into `/usr/local/bin`. If it already exists in the VM, it will not be copied again.
- A lock file (`/tmp/anka-buildkite-plugin-lock`) is created around pull and cloning. This prevents collision/ram state corruption when you're running two different jobs and pulling two different tags on the same anka node. The error you'd see otherwise is `state_lib/b026f71c-7675-11e9-8883-f01898ec0a5d.ank: failed to open image, error 2`

