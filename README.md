# ubuntu-devops-setup

Scripts to prepare an Ubuntu machine with the common software a developer, DevOps, or platform engineer needs. Active Directory / domain-controller integration is planned but not implemented yet.

## Scripts

| Script | Target |
| --- | --- |
| `ubuntu-system-prepare.sh` | Physical machine (baseline + GUI, communication and remote-desktop apps) |
| `ubuntu-system-prepare-vm-dev.sh` | Development VM (baseline + `x2go` and remote-desktop tools) |
| `ubuntu-system-prepare-wsl-dev.sh` | WSL2 development environment (minimum baseline) |
| `ubuntu-system-prepare-common.sh` | Shared library sourced by the scripts above |

## Usage

Run the script matching your environment on a fresh Ubuntu installation, with `sudo`. Set `gituser` and `gitemail` first if you want Git configured:

```bash
export gituser="Your Name"
export gitemail="you@example.com"
sudo -E ./ubuntu-system-prepare.sh
```

The scripts are idempotent and can be re-run. They install packages, add third-party apt repositories (keyring `signed-by`), edit `/etc/sudoers.d/`, and by default disable `cups` and `ufw`. Review them first and run them only on a machine you can rebuild.

Switchable options (set before running): `K8S_MINOR`, `APT_UPGRADE`, `ENABLE_PASSWORDLESS_SUDO`, `DISABLE_UFW`, `DISABLE_CUPS`.

## Target

Ubuntu **24.04 / 26.04 LTS and derivatives**, on `amd64`/`arm64`, installing the newest available versions of each app. The scripts no longer use `apt-key`, Docker Compose v1, or the legacy `ms-teams` package; Teams is installed via **Teams for Linux**.

Vendors that publish `amd64` only (Spotify, VirtualBox) are skipped with a warning on `arm64`.

The `vm-dev` target is validated end-to-end on `arm64` (Ubuntu 24.04); the physical target is `amd64`-oriented because VirtualBox is not published for `arm64` Linux.
