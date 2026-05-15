# Anka Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Anka](https://docs.veertu.com/anka/what-is-anka/) virtual machines.

The plugin will create a cloned VM to run commands inside of and will then delete the VM on pipeline status `cancellation`, `failure`, or `success`.

You do not need to install the Buildkite agent in the VM, the plugin will do that for you using the host's Buildkite agent.

## Prerequisites

- You need to ensure your Anka Nodes (host machines running Anka software) have the Buildkite agent installed and show under your Agents listing inside of Buildkite.
- You need to [install the Anka CLI](https://docs.veertu.com/anka/anka-virtualization-cli/getting-started/installing-the-anka-virtualization-package/) on your host machines.
- EC2 Mac users: You must launch your agents with `no-pty=true` in the agent config in order for licensing as a non-root user to function for anka CLI commands.

## Pipeline Step Definition Example

```yml
steps:
  - label: "Build"
    key: "build-key"
    command: make build
    plugins:
      - veertuinc/anka#main:
          vm-name: 26.3-arm64
          # Mounts the agent’s builds root into the VM (see “Host directory mounts” below).
          mount-host-path: "${BUILDKITE_BUILD_PATH}"

  - label: "Test"
    key: "test-key"
    command: make test
    depends_on:
      - "build-key"
    plugins:
      - veertuinc/anka#main:
          vm-name: 26.3-arm64
          # Repeat mount-host-path on every step that runs inside the VM; clones are per job.
          mount-host-path: "${BUILDKITE_BUILD_PATH}"
```

The first step runs the build with the host directory shared into the guest. The second runs tests in a **new** VM clone, so it needs the same `mount-host-path` (and options like `mount-guest-folder-name` / `guest-build-path`) if the tests rely on that share.

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

| Option | Description | Example |
|--------|-------------|---------|
| `vm-name` | Anka VM Template to use as the base. The plugin creates a step-specific clone prior to execution. | `macos-base` |
| `vm-registry-tag` | Tag for the VM Template to pull from the Anka Cloud Registry. | `latest` |
| `vm-registry-version` | Version number for the VM Template in the Anka Registry. | `1` |
| `always-pull` | Pull the VM Template before cloning. Use `true` or `"shrink"` to remove other local tags. Registry failures do not fail the build. | `true` |
| `environment-file` | Path to a file with additional environment variables to inject into the VM. The agent's job environment is always passed. | `./my-env.txt` |
| `mount-host-path` | Share a host directory into the VM ([Anka 3.9.0+](https://docs.veertu.com/anka/whats-new/anka-3.9.0/#ability-to-mount-host-directories-inside-of-the-vm); Apple silicon hosts only). The plugin runs `anka modify … mount host_path[:guest_folder_name]` in **post-checkout**; the guest sees the share under `/Volumes/My Shared Files/<mount-guest-folder-name>`. Paths may include `${BUILDKITE_*}` placeholders; the plugin expands these from the job environment. | `"${BUILDKITE_BUILD_PATH}"` or `"/tmp/buildkite-cache"` |
| `mount-guest-folder-name` | Guest folder name under `/Volumes/My Shared Files/` (CLI `guest_folder_name`; default `buildkite`). | `buildkite` |
| `guest-build-path` | Overrides `buildkite-agent bootstrap --build-path` when using `mount-host-path`. Defaults to `/Volumes/My Shared Files/<mount-guest-folder-name>`. | `/Volumes/My Shared Files/buildkite` |
| `bootstrap-skip-checkout` | Passes [`buildkite-agent bootstrap --skip-checkout`](https://buildkite.com/docs/agent/cli/reference/bootstrap) inside the VM so bootstrap skips the git checkout phase there. Same effect as setting job env `BUILDKITE_SKIP_CHECKOUT=true` (also respected). Useful when the workspace is already valid inside the guest (e.g. shared host build dir). | `true` |
| `copy-in-host-path` | Host path to copy into the VM before bootstrap. Use `:step_key:` and `:agent_id:` placeholders. Copy-in is skipped if the path does not exist. Must be used with `copy-in-vm-path`. | `"/tmp/buildkite-cache/:agent_id:/:step_key:"` |
| `copy-in-vm-path` | Destination path in the VM for `copy-in-host-path`. Must be used with `copy-in-host-path`. | `/tmp/buildkite-cache` |
| `copy-out-vm-path` | VM path to copy back to the host after bootstrap. Must be used with `copy-out-host-path`. | `/tmp/buildkite-cache` |
| `copy-out-host-path` | Host destination for `copy-out-vm-path`. Use `:step_key:` and `:agent_id:` placeholders. Copy-out copies *contents* (not the folder). Created if missing. Must be used with `copy-out-vm-path`. | `"/tmp/buildkite-cache/:agent_id:/:step_key:"` |
| `wait-time` | Run `sleep` inside the VM before bootstrap for sntp time sync. Use `true` for 10s default, or an integer for custom seconds. | `true` or `15` |
| `debug` | Enable debug output within the plugin. | `true` |
| `anka-debug` | Enable `anka --debug` output when running anka commands. | `true` |
| `cleanup` | Set to `false` to leave cloned images for investigation. Use `cancel-grace-period=60` on the agent. | `false` |
| `pre-commands` | **(DANGEROUS)** Commands to run on the HOST before guest commands. E.g. download artifacts. Double-escape variables. | YAML list |
| `post-commands` | **(DANGEROUS)** Commands to run on the HOST after guest commands. E.g. upload artifacts. VM names are `${vm_name}-${BUILDKITE_JOB_ID}`. | YAML list |
| `failover-registries` | List of registries to try if the default is unavailable. Uses the first available. | `['registry_1', 'registry_2']` |
| `modify-cpu` | Stop VM, set CPU cores, then run commands. | `6` |
| `modify-ram` | Stop VM, set memory (G), then run commands. | `32` |
| `modify-mac` | Stop VM, set MAC address, then run commands. | `00:1B:44:11:3A:B7` |

**Deprecated and removed (v2.0.0):** `workdir`, `workdir-create`, `bash-interactive`, `pre-execute-sleep`, `pre-execute-ping-sleep`, `wait-network`, `volume`, `no-volume`

### Host directory mounts

- **Anka CLI** must be **3.9.0 or newer**; otherwise the plugin fails with a clear error (`anka version` is checked in **post-checkout**).
- **`BUILDKITE_BUILD_PATH`** is defined by the Buildkite agent (host builds root, e.g. `~/.buildkite-agent/builds`). Use `"${BUILDKITE_BUILD_PATH}"` in `mount-host-path` to share that directory. **Do not try to override `BUILDKITE_BUILD_PATH` in step `env`**—Buildkite ignores it and the mount would not use your custom value. For a **different** host directory, set your own variable (e.g. `ANKA_MOUNT_HOST_PATH`) in `env` and set `mount-host-path` to `"${ANKA_MOUNT_HOST_PATH}"`.
- With **`mount-host-path` set**, `buildkite-agent bootstrap` is run with **`--build-path`** set to `guest-build-path`, or by default **`/Volumes/My Shared Files/<mount-guest-folder-name>`**. Without **`mount-host-path`**, bootstrap uses **`--build-path build`** (relative workspace path in the VM).
- Before bootstrap, the **command** hook runs **`anka mount <clone>`** so mount status appears in the job log.

### Copy options

- **copy-in** and **copy-out** paths support `:step_key:` and `:agent_id:` placeholders. Buildkite pre-interpolates plugin config and may omit `${BUILDKITE_STEP_KEY}`; use the placeholders instead. Quotes are required for `:step_key:` in YAML (e.g. `"/tmp/cache/:agent_id:/:step_key:"`).
- **copy-in** is skipped if the host path does not exist.
- **copy-out** copies the *contents* of the VM path into the host path (not the folder itself). The plugin creates `copy-out-host-path` if it does not exist.

### Other options

- **always-pull**: If the registry is down and the pull fails, the plugin will not fail the build. Monitor for registry availability.
- **cleanup**: When set to `false`, run the buildkite agent with `cancel-grace-period=60`; the [default 10 seconds is not enough time](https://forum.buildkite.community/t/problems-with-anka-plugin-and-pre-exit/365/7).
- **pre-commands** / **post-commands**: Double-escape variables you don't want eval to interpolate too soon. Cloned VM names are `${vm_name}-${BUILDKITE_JOB_ID}`.

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


## Development

### Testing

```bash
make lint
make shellcheck
make bats
```

#### A real pipeline

1. Install the buildkite-agent on your macos host machine.
2. Install the anka CLI on your macos host machine.
3. Start the buildkite agent on your macos host machine.
4. Go to https://buildkite.com/veertu-inc/anka-buildkite-plugin-test and you'll see your branch.
5. Add the proper test changes to pipeline.yml and commit.
6. Run the pipeline and you'll see the test results.