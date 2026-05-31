# Coding Style Contract

This document defines the repo-owned coding-style and public-quality contract
for `beaglebone-optimal`.

## Authority

- `.editorconfig` defines baseline whitespace, line endings, and encoding for
  the repo and the near-term BSP/Yocto file types it expects to grow into.
- `.clang-format` defines the official formatting policy for future C/C++ code.
- `.clangd` is editor assistance only. It must stay portable and must not
  hardcode machine-specific LLVM include paths.
- `.yamllint.yml` defines the YAML lint policy for tracked repo YAML files.
- `.hadolint.yaml` defines the Dockerfile lint policy for tracked Dockerfiles.

## Current Policy

- Shell scripts are formatted with `shfmt -i 4 -ci -sr`.
- Shell scripts are linted with `shellcheck`.
- YAML files covered by the repo contract are linted with `yamllint`.
- Dockerfiles are linted with `hadolint`.
- Markdown belongs to the style contract through `.editorconfig`, but v1 does
  not require a local Markdown linter.

## Make Interface

Use the repo `make` targets as the public interface:

- `make format`
- `make format-check`
- `make lint`
- `make check`

`make doctor` remains a runtime and environment check. It is not part of the
style gate.

## Local Tools

Required local tools for the v1 contract:

- `shfmt`
- `shellcheck`
- `yamllint`

`clang-format` becomes a required local tool when the repo contains tracked
C/C++ files covered by the formatting contract.

`hadolint` is optional for local development but mandatory in CI. If it is not
installed locally, `make lint` warns and skips Dockerfile lint while CI still
enforces it.

## C and C++ Roadmap

When the repo gains real C/C++ build outputs, `compile_commands.json` becomes
the compile-truth for editor tooling. `.clangd` should remain a thin,
portable project config layered on top of that source of truth.

## Repository Hygiene

- Do not keep an empty `.gitmodules`. Track it only when the repo actually uses
  Git submodules.
- Do not add machine-specific editor paths or host-only assumptions to tracked
  tooling config.
- Keep CI aligned with the `make` interface instead of inventing separate lint
  commands in workflow YAML.
