# Runbook

Vietnamese version: [`_RUNBOOK_VN.md`](./_RUNBOOK_VN.md)

## Purpose

This runbook explains how to operate the Docker phase 1 builder workflow for
the `beaglebone-optimal` repository.

Current contract:

- runtime truth lives in `compose.yaml`
- image build lives in `docker/Dockerfile`
- public interface lives in `Makefile`
- local machine override lives in `local.mk`

This builder is an ad-hoc build environment. It is not a long-running service
container.

## Relevant structure

```text
.
├── Makefile
├── compose.yaml
├── docker/
│   └── Dockerfile
├── local.mk.example
└── scripts/docker/
    ├── doctor.sh
    └── lib.sh
```

## Prerequisites

The local machine must have:

- Docker Engine
- Docker Compose plugin, used through `docker compose`
- permission to run Docker from the current user

This runbook assumes the machine's Docker daemon is already healthy.

## Local setup

1. Create the local config file:

```bash
cp local.mk.example local.mk
```

2. Edit `local.mk` and set `PROJECT_STORAGE_ROOT` to an absolute path.

Example:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default

# Optional override. By default Make auto-detects the current host uid:gid.
# DOCKER_USER := 1000:1000
```

Important rules:

- `PROJECT_STORAGE_ROOT` must be an absolute path
- `DOCKER_USER` is an optional override and must match `uid:gid` if set
- do not commit `local.mk`
- large build data must live under `PROJECT_STORAGE_ROOT`, not in the source
  tree

## Storage model

Container mounts:

- repo root -> `/workspace`
- host storage root -> `/storage`

Inside the host storage root, the repo creates this standard layout:

```text
${PROJECT_STORAGE_ROOT}/
├── shared/
│   ├── downloads/
│   └── sstate/
└── workspaces/
    └── ${WORKSPACE_NAME}/
        ├── logs/
        ├── out/
        ├── tmp/
        └── yocto/
            └── build/
```

Meaning:

- `shared/` stores reusable caches
- `workspaces/<name>/` stores outputs and state for the current workspace

## Standard public commands

Show help:

```bash
make help
```

Build the image:

```bash
make docker-build
```

Validate the environment:

```bash
make doctor
```

Open a shell inside the builder container:

```bash
make docker-shell
```

Run any command inside the builder container:

```bash
make docker-run CMD='uname -a'
```

## Behavior of each command

### `make docker-build`

Behavior:

- runs `docker compose build builder`
- does not require `PROJECT_STORAGE_ROOT`
- uses Docker build cache when available

Use it when:

- building the image for the first time
- rebuilding after editing `docker/Dockerfile`

### `make doctor`

Behavior:

- checks `docker compose version`
- checks `PROJECT_STORAGE_ROOT`
- creates the required directory tree under the storage root
- renders `docker compose config`
- auto-builds the image if it does not exist
- runs a container and performs a real write test to `/storage`

Successful output:

```text
doctor: ok
```

Use it when:

- cloning the repo on a new machine
- changing `local.mk`
- debugging mount or permission problems

### `make docker-shell`

Behavior:

- runs a light preflight
- requires a valid `PROJECT_STORAGE_ROOT`
- creates storage directories if missing
- auto-builds the image if it does not exist
- opens a shell in `/workspace`

### `make docker-run CMD='...'`

Behavior:

- runs the same light preflight as `docker-shell`
- fails immediately if `CMD` is empty
- runs the command with this pattern:

```bash
docker compose run --rm builder bash -lc "$CMD"
```

Examples:

```bash
make docker-run CMD='pwd'
make docker-run CMD='ls -la /storage'
make docker-run CMD='env | sort'
```

## Runtime contract

The current Compose service name is `builder`.

Important runtime contract:

- image: `${DOCKER_IMAGE}:${DOCKER_TAG}`
- source bind mount: `.:/workspace`
- storage bind mount: `${PROJECT_STORAGE_ROOT}:/storage`
- user mapped from host: `${DOCKER_USER}`
- env inside the container:
  - `PROJECT_STORAGE_ROOT=/storage`
  - `WORKSPACE_NAME=${WORKSPACE_NAME}`

## Image contract

The current `docker/Dockerfile`:

- uses `ubuntu@sha256:...` pinned by digest
- installs the toolchain and build dependencies for the builder
- uses `--no-install-recommends`
- cleans apt lists
- pins `dtschema==2026.4`
- uses `WORKDIR /workspace`
- uses `bash` as the default command

It does not include:

- `ENTRYPOINT`
- `HEALTHCHECK`
- `EXPOSE`
- hardcoded local APT mirror settings
- hardcoded fixed runtime user

## Recommended operating flow

### First time on a new machine

```bash
cp local.mk.example local.mk
$EDITOR local.mk
make doctor
make docker-shell
```

### After editing the Dockerfile

```bash
make docker-build
make doctor
```

### Quick command checks

```bash
make docker-run CMD='uname -a'
make docker-run CMD='python3 --version'
```

## Common failures

### `PROJECT_STORAGE_ROOT is required`

Cause:

- `local.mk` has not been created yet
- the variable has not been exported

Fix:

```bash
cp local.mk.example local.mk
```

Then set:

```make
PROJECT_STORAGE_ROOT := /absolute/path
```

### `PROJECT_STORAGE_ROOT must be an absolute path`

Cause:

- a relative path was used

Wrong:

```make
PROJECT_STORAGE_ROOT := tmp/build
```

Correct:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
```

### `CMD is required`

Cause:

- `make docker-run` was called without `CMD`

Correct:

```bash
make docker-run CMD='uname -a'
```

### `make doctor` fails on the `/storage` write step

Common causes:

- the host path is not writable
- the current user lacks permission on that path
- the Docker daemon is running but the bind mount target is not suitable

Fix flow:

1. check `PROJECT_STORAGE_ROOT` in `local.mk`
2. check host write permission on that path
3. rerun:

```bash
make doctor
```

### Shell shows `I have no name!`

Meaning:

- the container is still working correctly
- the host-mapped UID/GID does not have a matching name entry inside the image

Impact:

- mostly cosmetic in the shell prompt
- it does not block `docker-shell`, `docker-run`, or `doctor`

Current status:

- this is a known follow-up, not a phase 1 blocker

## What not to do

- do not write build artifacts into the source tree
- do not hardcode local paths such as `/mnt/data/...` into tracked files
- do not change runtime behavior in README only and forget to sync `Makefile`,
  `compose.yaml`, and `scripts/docker/*.sh`
- do not use `rtk` inside repo docs or repo scripts

## When changing the contract

If Docker phase 1 behavior changes, run at least:

```bash
docker compose config
make help
make docker-build
make doctor
make docker-run CMD='uname -a'
```

## Source of truth

If this document conflicts with code, read in this order:

1. `Makefile`
2. `scripts/docker/lib.sh`
3. `scripts/docker/doctor.sh`
4. `compose.yaml`
5. `docker/Dockerfile`
