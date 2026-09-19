# Conventions

## Observed conventions

Derived from the scripts as they exist today.

- **Language:** Bash (`#!/usr/bin/env bash`), executed on Ubuntu 24.04+.
- **Entry points:** thin scripts named `ubuntu-system-prepare[-<target>].sh`; the shared logic lives in `ubuntu-system-prepare-common.sh`, sourced via `SCRIPT_DIR`.
- **Strictness:** every script starts with `set -euo pipefail` and calls `require_root`.
- **Context detection:** `TARGET_USER` (`$SUDO_USER`), `ARCH` (`dpkg --print-architecture`), `CODENAME` (`/etc/os-release`) are resolved once in the library; commands run as the invoking user via `as_user`.
- **Structure:** one function per tool in the library (`install_docker`, `install_kubectl`, ...); entry scripts list only the calls for their target.
- **Third-party apt repos:** `add_apt_repo <name> <key-url> <deb-line>` writes a keyring to `/etc/apt/keyrings/<name>.gpg` and a `signed-by=` source to `/etc/apt/sources.list.d/<name>.list`. `apt-key` is not used.
- **Idempotency:** `snap_install` guards with `snap list`; `add_bashrc_block` guards with `>>> tag >>>` markers; the docker group is checked before `usermod`; `add_apt_repo` keeps an existing key.
- **Downloads:** vendor files go to `mktemp -d` and are removed afterwards.
- **Comments:** terse, one section label per step (for example `# docker`).
- **Naming:** lowercase, hyphenated; target suffixes `baremetal` (physical machine), `vm-dev`, and `wsl-dev`.

## Recommended conventions

- Add or change an installer in `ubuntu-system-prepare-common.sh`, then call it from the relevant entry scripts; never copy the block into a second script.
- Keep every function idempotent and safe to re-run.
- Pin nothing ad hoc: put a version that can change (for example `K8S_MINOR`) in a variable at the top of the library.
- Default to `signed-by` keyrings for new repositories and to `snap`/`flatpak` for proprietary GUI apps.
- Do not hardcode Ubuntu codenames; use `$CODENAME` and handle unsupported codenames explicitly (see `install_virtualbox`).
- Guard `amd64`-only vendors by `$ARCH` and skip them with a warning on other architectures (see `install_spotify`, `install_virtualbox`) instead of letting `apt` fail.
- Keep English for technical context; match the existing mixed PT/EN comments only where the repository already does.

## Documentation

- Keep `AGENTS.md` short and route-oriented.
- Reference authoritative docs instead of copying them.
- Keep `TASKS.md` current-state only and `HANDOFF.md` operational, not a chat transcript.
- Treat `LEARNINGS.md` as a bounded, append-only buffer; promote durable learnings into `CONVENTIONS.md`, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md` instead of letting them accumulate.
- Keep tool-specific files as thin adapters that only route to `AGENTS.md`; record their paths in `.ai/ADAPTERS.md`.
- Keep the Resume block in `HANDOFF.md` current as a rolling checkpoint and honor the thresholds in `.ai/LIMITS.md`.
