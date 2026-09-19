# Session Handoff

## Resume block (read first)

- Repo state: branch `dev` (tracking `origin/dev`), working tree `clean`; `main` merged via PR #1 (`e57092d`) and carries the same content
- Source of truth: `AGENTS.md` → `.ai/`
- Budget / usage observed: `<unknown>`
- Checkpoint updated: `2026-09-15`
- Last goal: Remove AnyDesk and TeamViewer (ADR-009) and merge the full modernization into `main` (PR #1). Done.
- Exact next action: Validate `ubuntu-system-prepare-baremetal.sh` (bare metal) end-to-end on a real Ubuntu 24.04/26.04 **amd64** desktop (snap/flatpak/GUI).
- Blocked by: No disposable Ubuntu **amd64 desktop** target available in this session.
- Resume prompt: `Read AGENTS.md and .ai/HANDOFF.md. Continue from the Resume block. Do not rediscover context.`

## Goal

Keep an accurate, portable context for `ubuntu-devops-setup` and keep the provisioning scripts current with Ubuntu 24.04 / 26.04 LTS and the newest app versions.

## Current State

The scripts are modernized and pass `bash -n` and `shellcheck`. `ubuntu-system-prepare-wsl-dev.sh` and `ubuntu-system-prepare-vm-dev.sh` run end-to-end (exit 0) in a disposable `ubuntu:24.04` arm64 container. The physical entry point is still unvalidated end-to-end (needs snap/flatpak/GUI). AnyDesk and TeamViewer were removed (ADR-009).

## What Was Done

- Rewrote `ubuntu-system-prepare-baremetal.sh`, `ubuntu-system-prepare-vm-dev.sh`, and `ubuntu-system-prepare-wsl-dev.sh` as thin entry points.
- Added `ubuntu-system-prepare-common.sh` with detected context, safe/idempotent helpers, and one installer per tool.
- Fixed the syntax error (stray sudoers line), `puthon3`, `java-default`, and `aws-iam-authenticatorku`.
- Replaced `apt-key` with keyring `signed-by`; Docker Compose v2; `kubectl` from `pkgs.k8s.io`; arch-aware AWS CLI.
- Teams moved to Teams for Linux (snap); removed retired Skype and redundant `aws-iam-authenticator`; removed the system-wide PyDrive pip install.
- Added `set -euo pipefail`, root guard, `TARGET_USER` handling (was using `root` under sudo), and switchable `ENABLE_PASSWORDLESS_SUDO`/`DISABLE_UFW`/`DISABLE_CUPS`/`APT_UPGRADE`.
- Updated `.ai/ARCHITECTURE.md`, `CONVENTIONS.md`, `DECISIONS.md` (ADR-005 Accepted, ADR-006 added), `VALIDATION.md`, `TASKS.md`, `LEARNINGS.md`, and `README.md`.
- Renamed the repository from `ubuntu` to `ubuntu-devops-setup` (GitHub `crilsen/ubuntu-devops-setup` and the local directory); updated `PROJECT.md`, `HANDOFF.md`, and `README.md`.
- Ran `shellcheck` (container) and fixed the single `SC1091` finding with `# shellcheck source=/dev/null` in `ubuntu-system-prepare-common.sh`.
- Ran `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → exit 0.
- Reviewed the physical/`vm-dev` installers and validated every apt-based one at function level in `ubuntu:24.04` arm64 (Chrome, VS Code, Sublime, Terminator, zsh, Flameshot, Remmina, X2Go, Flatpak all pass).
- Fixed the arm64 bugs found: `install_spotify` and `install_virtualbox` now skip on non-`amd64`; corrected the overstated AD claim in `README.md`.
- Resolved the pending decisions as ADR-007 (security defaults stay `1`, documented) and ADR-008 (AD/domain integration deferred).
- Removed AnyDesk and TeamViewer from the shared library and from `ubuntu-system-prepare-baremetal.sh`/`ubuntu-system-prepare-vm-dev.sh` (ADR-009).
- Renamed the physical entry point to `ubuntu-system-prepare-baremetal.sh` (ADR-010).

## Files Changed

- `ubuntu-system-prepare-baremetal.sh`, `ubuntu-system-prepare-vm-dev.sh`, `ubuntu-system-prepare-wsl-dev.sh`
- `ubuntu-system-prepare-common.sh` (new)
- `README.md`
- `.ai/PROJECT.md`, `.ai/ARCHITECTURE.md`, `.ai/CONVENTIONS.md`, `.ai/DECISIONS.md`
- `.ai/TASKS.md`, `.ai/HANDOFF.md`, `.ai/LEARNINGS.md`, `.ai/VALIDATION.md`

## Decisions Made

- ADR-004: target Ubuntu 24.04/26.04 LTS and newest apps.
- ADR-005 (Accepted): one entry script per target plus a shared library.
- ADR-006: drop Skype, `aws-iam-authenticator`, the legacy `ms-teams` repo, and the system PyDrive install.
- ADR-007 (Accepted): keep `ENABLE_PASSWORDLESS_SUDO`/`DISABLE_UFW`/`DISABLE_CUPS` at `1`, documented and switchable.
- ADR-008 (Accepted): defer AD/domain-controller integration; correct the `README.md` claim.
- ADR-009 (Accepted): remove `install_anydesk`/`install_teamviewer` (unused; X2Go/Remmina cover remote access).

## Problems / Risks

- The physical script is unvalidated end-to-end; it needs an `amd64` desktop target with snap/flatpak/GUI. Running any script mutates a host (packages, `/etc/sudoers.d`, services).
- `ENABLE_PASSWORDLESS_SUDO=1`, `DISABLE_UFW=1`, `DISABLE_CUPS=1` carry security impact and are on by default for behavior parity (ADR-007).
- Spotify (amd64-only) and VirtualBox (amd64-only) are skipped on arm64; a full `amd64` verification run is still pending.
- `K8S_MINOR` defaults to `v1.36` (`kubectl` 1.36.4 verified) and may lag the latest release.
- PyDrive was removed; no Google Drive client is installed now (use `pipx`/`rclone`).
- AnyDesk and TeamViewer were removed; remote desktop is X2Go (VM) with Remmina as client.
- All work is committed, pushed, and merged to `main` (PR #1); nothing is uncommitted.

## Validation Performed

- `bash -n` on all four scripts → Validated.
- `shellcheck` (container) → Validated; clean.
- `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → Validated (exit 0).
- `ubuntu-system-prepare-vm-dev.sh` end-to-end in `ubuntu:24.04` arm64 → Validated (exit 0, before AnyDesk/TeamViewer removal).
- Function-level apt installers for physical/`vm-dev` in `ubuntu:24.04` arm64 → Validated (all pass except the documented amd64-only cases).
- Snap/flatpak GUI apps and VirtualBox → Not validated (see `VALIDATION.md`).

## Next Actions

- Validate the physical/bare-metal script end-to-end on a real Ubuntu 24.04/26.04 **amd64** desktop.
- Decide whether to install a Google Drive client by default; revisit `K8S_MINOR`.
