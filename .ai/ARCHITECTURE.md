# Architecture

## Overview

The repository is a set of Bash provisioning scripts for Ubuntu, one entry point per target environment, backed by a shared library. Each entry script is run once on a fresh Ubuntu installation (24.04 / 26.04 LTS or a derivative) and mutates the host in place; there is no configuration management or IaC.

## Components

| Component | Target | Notes |
| --- | --- | --- |
| `ubuntu-system-prepare.sh` | Physical machine | Fullest set, including GUI, communication and remote-desktop apps |
| `ubuntu-system-prepare-vm-dev.sh` | VM, development | Baseline plus `x2go`, remote-desktop and screenshot tools |
| `ubuntu-system-prepare-wsl-dev.sh` | WSL2, development | Minimum set, no GUI apps: shell, Git, Docker, Kubernetes, AWS |
| `ubuntu-system-prepare-common.sh` | Shared library | Sourced by the three entry points; no execution on its own |

## Execution model (observed)

1. `require_root` and `cd /tmp`; the scripts expect root or `sudo`.
2. The shared library resolves `TARGET_USER` (`$SUDO_USER`), `ARCH` (`dpkg --print-architecture`), and `CODENAME` (`/etc/os-release`).
3. Third-party apt repositories are added with `add_apt_repo`: the key is downloaded to `/etc/apt/keyrings/<name>.gpg` and referenced with `signed-by=` in `/etc/apt/sources.list.d/<name>.list`. No `apt-key`.
4. Packages are installed with `apt`, `snap`, or `flatpak`; vendor `.deb`/zip downloads use a temporary directory.
5. Post-install steps are idempotent: `snap_install` checks `snap list`, `add_bashrc_block` guards with markers, `configure_passwordless_sudo` uses `/etc/sudoers.d/` and `visudo -cf`, group membership is checked before `usermod`.
6. Optional service tuning (`DISABLE_CUPS`, `DISABLE_UFW`), passwordless sudo (`ENABLE_PASSWORDLESS_SUDO`), and the final upgrade (`APT_UPGRADE`) are switchable at the top of the library.
7. Scripts finish with `apt-get upgrade -y` unless `APT_UPGRADE=0`.

## Software installed (by category)

- **Shell/CLI basics:** `vim`, `htop`, `jq`, `unzip`, `zip`, `curl`, `wget`, `git` + `git-lfs` (via `ppa:git-core/ppa`), `zsh`.
- **Containers/orchestration:** Docker CE + CLI + `containerd.io` + `docker-buildx-plugin` + `docker-compose-plugin` (Compose v2) from Docker's apt repo; `kubectl` from `pkgs.k8s.io`; AWS CLI v2; Lens (snap).
- **Editors/IDE:** VS Code (Microsoft apt repo), Sublime Text.
- **Languages:** `default-jdk`; `python3` + `pip3` + `venv` + `pipx`.
- **GUI/communication (physical):** Google Chrome, Teams for Linux (snap), Spotify, Remmina, TeamViewer, AnyDesk, VirtualBox, Terminator, Flameshot, Discord (Flatpak), Flatpak + Flathub.
- **Remote/misc:** `x2goserver` (VM only).
- **Domain/AD:** previously commented `realmd`/`sssd`/`realm join` and `cid`; still not active.

## Changes from the 20.04-era scripts

- `apt-key` and `add-apt-repository "deb ..."` recipes replaced with keyring `signed-by` sources.
- Docker Compose v1 replaced by the Compose v2 plugin; `docker-compose` (v1) no longer installed.
- `kubectl` installed from `pkgs.k8s.io` (the old GCS path and the pinned v1.14 binary are gone).
- Legacy `ms-teams` repo removed in favor of **Teams for Linux**; retired **Skype** removed.
- Invalid installs fixed: `puthon3` → `python3`, `java-default` → `default-jdk`, `aws-iam-authenticatorku` removed.
- `aws-iam-authenticator` dropped because AWS CLI v2 provides `aws eks get-token`.
- Architecture detection for AWS CLI and TeamViewer; `VirtualBox` uses Oracle's repo only where published, otherwise the Ubuntu package.
- `amd64`-only vendors (Spotify, VirtualBox) are skipped with a warning on `arm64` (`install_spotify`/`install_virtualbox`).
- Idempotency, error handling (`set -euo pipefail`), and a real root guard added; `sudo`/bare-command mixing removed.
- Shared logic moved to `ubuntu-system-prepare-common.sh` (ADR-005), removing the triplicated blocks.

## Security and privilege model (observed)

- Scripts run as root; `TARGET_USER` is the invoking user, not `root`.
- `configure_passwordless_sudo` adds `${TARGET_USER} ALL=(ALL) NOPASSWD:ALL` via `/etc/sudoers.d/`, validated with `visudo -cf`; controlled by `ENABLE_PASSWORDLESS_SUDO`.
- `DISABLE_CUPS` and `DISABLE_UFW` are enabled by default to match the previous behavior; both are switchable.
- No secrets are stored in the repository; `gituser`/`gitemail` are supplied at runtime.

## Context-layer layout

```text
Tool-specific adapter (optional)
            ↓
        AGENTS.md
            ↓
          .ai/
  project · architecture · conventions · decisions
  tasks · handoff · tools · validation · workflows · prompts
```

`.ai/` is the portable source of truth. Tool-specific adapters must only route agents to it.
