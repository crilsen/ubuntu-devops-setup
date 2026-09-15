# Session Handoff

## Resume block (read first)

- Repo state: branch `dev` (tracking `origin/dev`), HEAD `6496be3`, working tree `dirty: modified ubuntu-system-prepare-common.sh, README.md, .ai/*`
- Source of truth: `AGENTS.md` → `.ai/`
- Budget / usage observed: `<unknown>`
- Checkpoint updated: `2026-09-15`
- Last goal: Review the physical/`vm-dev` scripts, resolve the pending TASKS decisions, and validate in a disposable container.
- Exact next action: Validate `ubuntu-system-prepare.sh` and `ubuntu-system-prepare-vm-dev.sh` end-to-end on a real Ubuntu 24.04/26.04 **amd64** desktop (snap/flatpak/GUI), then commit the review changes (context + script guards are uncommitted).
- Blocked by: No disposable Ubuntu **amd64 desktop** target available in this session (only a headless arm64 container; snapd needs systemd and Spotify/VirtualBox are amd64-only).
- Resume prompt: `Read AGENTS.md and .ai/HANDOFF.md. Continue from the Resume block. Do not rediscover context.`

## Goal

Keep an accurate, portable context for `ubuntu-devops-setup` and keep the provisioning scripts current with Ubuntu 24.04 / 26.04 LTS and the newest app versions.

## Current State

The scripts are modernized and pass `bash -n` and `shellcheck`. `ubuntu-system-prepare-wsl-dev.sh` runs end-to-end (exit 0) in a disposable `ubuntu:24.04` arm64 container. The physical and `vm-dev` entry points are still unvalidated (they need snap/flatpak/GUI). Nothing is committed yet.

## What Was Done

- Rewrote `ubuntu-system-prepare.sh`, `ubuntu-system-prepare-vm-dev.sh`, and `ubuntu-system-prepare-wsl-dev.sh` as thin entry points.
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

## Files Changed

- `ubuntu-system-prepare.sh`, `ubuntu-system-prepare-vm-dev.sh`, `ubuntu-system-prepare-wsl-dev.sh`
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

## Problems / Risks

- Physical and `vm-dev` scripts are unvalidated end-to-end; they need an `amd64` desktop target with snap/flatpak/GUI. Running any script mutates a host (packages, `/etc/sudoers.d`, services).
- `ENABLE_PASSWORDLESS_SUDO=1`, `DISABLE_UFW=1`, `DISABLE_CUPS=1` carry security impact and are on by default for behavior parity (ADR-007).
- Spotify (amd64-only) and VirtualBox (amd64-only) are skipped on arm64; a full `amd64` verification run is still pending.
- `K8S_MINOR` defaults to `v1.36` (`kubectl` 1.36.4 verified) and may lag the latest release.
- PyDrive was removed; no Google Drive client is installed now (use `pipx`/`rclone`).
- Review changes (script guards + context) are uncommitted; commit and push before any agent or machine switch (L-002).

## Validation Performed

- `bash -n` on all four scripts → Validated.
- `shellcheck` (container) → Validated; clean.
- `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → Validated (exit 0).
- Function-level apt installers for physical/`vm-dev` in `ubuntu:24.04` arm64 → Validated (all pass except the documented amd64-only/container-artifact cases).
- Snap/flatpak GUI apps, TeamViewer, and VirtualBox → Not validated (see `VALIDATION.md`).

## Next Actions

- Validate physical/`vm-dev` end-to-end on a real Ubuntu 24.04/26.04 **amd64** desktop.
- Commit and push this review (guards + context).
- Decide whether to install a Google Drive client by default; revisit `K8S_MINOR`.
