# Project

## Identity

- **Name:** ubuntu-devops-setup
- **Objective:** Shell scripts that prepare an Ubuntu machine with everything a developer, DevOps, or platform engineer needs (Git, Docker, kubectl, AWS CLI, editors, communication and remote-desktop apps), including optional Active Directory / domain-controller integration.
- **Repository purpose:** Keep the provisioning scripts used to bootstrap the author's own machines across physical, virtual, and WSL environments.
- **Status:** Working scripts, written for Ubuntu 20.04/22.04; being modernized toward the newest app versions and Ubuntu 24.04 / 26.04 LTS and derivatives.

## Observed

- Three bash scripts exist and are the whole repository (plus `README.md`):
  - `ubuntu-system-prepare.sh` — physical machine (fullest set, includes GUI and communication apps, sudoers and service tuning).
  - `ubuntu-system-prepare-vm-dev.sh` — VM used for development (adds `x2go` remote desktop; no Teams/Skype/Spotify/VirtualBox).
  - `ubuntu-system-prepare-wsl-dev.sh` — WSL2 development environment (smallest set: no flatpak/terminator/GUI-only tooling).
- All scripts start with `cd /tmp`, install via `apt`/`apt-get`/`snap`/`flatpak`, mix `sudo` and bare commands, and end with `apt update && apt upgrade`.
- Each script's header comment still says `#for ubuntu 20.04` (WSL says `20.04-22-04`).
- `gituser` and `gitemail` are expected as shell variables (not defined in the scripts) for `git config --global`.
- No version pinning, no idempotency guards, no `set -euo pipefail`, and no CI; scripts target `amd64` in most download URLs.

## Requirements (stated by owner)

- Support Ubuntu **24.04 / 26.04 LTS and derivatives** as the primary targets.
- Prefer the **newest available app versions** over the versions pinned in the current scripts.
- The Teams install should be considered for **Teams for Linux** (community client) instead of the legacy `ms-teams` package.

## Recommended convention

Document the project as it exists, keep this file an overview rather than a duplicate of `README.md`, and mark anything not yet true of the code (for example the 24.04/26.04 target) as a requirement rather than an observed fact.
