# Validation

## Completion rule

Before completion, run all applicable project validations that are available and safe. Report each as **Validated**, **Partially validated**, or **Not validated**, with the reason for anything not run. Never claim validation that did not occur.

## Project checks (this repository)

The project is Bash scripts with no build, test suite, or CI. Run these before considering a change complete:

1. **Syntax check (safe, local):**
   ```bash
   for f in ubuntu-system-prepare*.sh; do bash -n "$f"; done
   ```
2. **Lint (when `shellcheck` is available):**
   ```bash
   shellcheck ubuntu-system-prepare*.sh
   ```
   `shellcheck` was not installed on the machine where this context was written; treat lint as **Not validated** until it is run.
3. **Review, not run, the mutating steps.** Do not execute the scripts to validate them: they install packages, alter `/etc/sudoers`, and disable services on the host. Validate by reading and by dry reasoning, or in a disposable VM/container with explicit authorization.

## Baseline validation performed (2026-09-14, after modernization)

- `bash -n ubuntu-system-prepare-common.sh` → **Validated** (syntax OK).
- `bash -n ubuntu-system-prepare.sh` → **Validated** (syntax OK; the former line-193 error is fixed).
- `bash -n ubuntu-system-prepare-vm-dev.sh` → **Validated** (syntax OK).
- `bash -n ubuntu-system-prepare-wsl-dev.sh` → **Validated** (syntax OK).
- `shellcheck` → **Validated** (2026-09-15, via the `koalaman/shellcheck:stable` container; initially reported `SC1091` on the external `. /etc/os-release` source, fixed with a `# shellcheck source=/dev/null` directive; now clean).
- End-to-end execution → **Partially validated** (2026-09-15, `ubuntu-system-prepare-wsl-dev.sh` ran to completion with exit 0 in a disposable `ubuntu:24.04` arm64 container; the physical and `vm-dev` entry points are still unvalidated because they need snap/flatpak/GUI).

## Validation performed (2026-09-15, shellcheck + container smoke run)

- `bash -n` on all four scripts → **Validated**.
- `shellcheck` (`koalaman/shellcheck:stable`) on all four scripts → **Validated** after adding the `source=/dev/null` directive (`SC1091` only).
- `ubuntu-system-prepare-wsl-dev.sh` in `docker run --rm --privileged -v "$PWD:/work:ro" ubuntu:24.04` (arm64, `APT_UPGRADE=0`) → **Validated**, exit 0. Installed `ca-certificates`/`curl`/`wget`/`gnupg`/`snapd`/`vim`/`htop`/`jq`/`zip`/`git`+`git-lfs` (git-core PPA), `default-jdk`, `python3`/`pip3`/`venv`/`pipx`, Docker CE 29.8.0 + Compose v2, `kubectl` 1.36.4 (`pkgs.k8s.io` v1.36), AWS CLI v2, `zsh`; `configure_passwordless_sudo` wrote `/etc/sudoers.d/90-root` and `visudo` parsed it OK. No `systemd`, so `docker` start and `DISABLE_UFW`/`DISABLE_CUPS` were correctly skipped by `has_systemd`.
- `ubuntu-system-prepare-vm-dev.sh` end-to-end in the same `ubuntu:24.04` arm64 container (`APT_UPGRADE=0`) → **Validated**, exit 0. Every install step passed on arm64, including Flatpak+Flathub, Chrome, VS Code, Sublime, Terminator, Flameshot, Remmina, **AnyDesk** (`8.0.4`, `Architecture: arm64`), **TeamViewer** (`teamviewer_arm64.deb`), and **X2Go**. The VM target has no `amd64`-only package, so it runs unmodified on arm64.
- Physical entry point → **Not validated** end-to-end (needs a real `amd64` desktop with snap/flatpak/GUI). A function-level run of its apt-based installers on `ubuntu:24.04` arm64 → **Validated** (all pass); Spotify is `amd64`-only (not found on arm64; a guard was added).
- Snap-based installs (`teams-for-linux`, `kontena-lens`), `install_discord`, and `install_virtualbox` → **Not validated** in the container (snapd needs systemd; VirtualBox is `amd64`-only and needs a real kernel). Vendor URLs and keys were reachability-checked: Spotify/AnyDesk/Sublime/k8s keys return 200, and TeamViewer `amd64`/`arm64` debs return 200.

## Known runtime assumptions to verify per target

- Run on Ubuntu 24.04 / 26.04 LTS or a derivative; `apt`, `snap`, and (for GUI targets) `flatpak` are available.
- `gituser` / `gitemail` are optionally set before running.
- Third-party repos and vendor URLs publish packages for the target release; `install_virtualbox` falls back to the Ubuntu package where Oracle has no repo.
- Defaults `ENABLE_PASSWORDLESS_SUDO=1`, `DISABLE_UFW=1`, `DISABLE_CUPS=1` alter host security; confirm before running on a managed machine.
