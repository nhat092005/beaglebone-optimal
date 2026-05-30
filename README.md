# beaglebone-optimal

## Docker Builder

This repo uses a Docker-only phase 1 builder workflow. Runtime config lives in
[`compose.yaml`](compose.yaml). Image build config lives in
[`docker/Dockerfile`](docker/Dockerfile).

### Setup

1. Copy `local.mk.example` to `local.mk`.
2. Set `PROJECT_STORAGE_ROOT` to an absolute path on your machine.

Example:

```make
PROJECT_STORAGE_ROOT := /mnt/data/beaglebone-optimal
WORKSPACE_NAME := default
```

### Commands

```bash
make help
make doctor
make docker-build
make docker-shell
make docker-run CMD='uname -a'
```

### Storage

`PROJECT_STORAGE_ROOT` is required for `make doctor`, `make docker-shell`, and
`make docker-run`. The builder container mounts:

- repo root at `/workspace`
- storage root at `/storage`

Generated data is created under `/storage`, not in the source tree.
