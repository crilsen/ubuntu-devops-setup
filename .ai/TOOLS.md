# Tools

## Current availability

The repository is pure Bash and is provisioned for Ubuntu. Tooling relevant to this project: a POSIX/Bash shell, `bash -n` for syntax checks, and optionally `shellcheck` for linting (not currently installed). The scripts themselves install `apt`, `snap`, and `flatpak` packages on the target. No credentials, environments, or command wrappers are stored here. Never store secrets in this file.

## Allowed without additional authorization

- Read and search repository files.
- Make scoped task-related edits.
- Run safe, local checks: `bash -n <file>` and `shellcheck <file>` when available.
- Run read-only commands and safe dry runs.
- Update this portable context.

## Requires explicit authorization

- Running any `ubuntu-system-prepare*.sh` script on a real host: it installs packages, edits `/etc/sudoers`, enables/disables system services, and downloads from third-party repositories.
- Any command that changes apt sources, GPG keys, services, or users on a real machine.
- Secret changes, destructive operations, or any external operation with material impact.

## Technology-specific guidance

| Technology | Usually safe | Restricted |
| --- | --- | --- |
| Bash scripts | `bash -n`, `shellcheck`, reading | executing provisioning scripts on a real host |
| apt/apt-key | reading current lists | adding repos/keys, installing/removing packages on a real host |
| `test`/disposable VM | run scripts end-to-end in a disposable Ubuntu VM or container | running them on the author's workstation |

Disposable container recipe (validated 2026-09-15; use for the non-GUI scripts):
`docker run --rm --privileged -v "$PWD:/work:ro" ubuntu:24.04 bash -c 'apt-get update && apt-get install -y sudo && mkdir -p /root/scripts && cp /work/*.sh /root/scripts/ && APT_UPGRADE=0 bash /root/scripts/ubuntu-system-prepare-wsl-dev.sh'`

Before running a command, confirm it is appropriate for the repository and does not mutate the host or external systems without authorization.
