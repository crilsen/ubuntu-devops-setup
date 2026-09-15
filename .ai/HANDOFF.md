# Session Handoff

## Resume block (read first)

- Repo state: branch `dev` (tracking `origin/dev`), HEAD `799a37b`, working tree `clean`
- Source of truth: `AGENTS.md` → `.ai/`
- Budget / usage observed: `<unknown>`
- Checkpoint updated: `2026-09-15`
- Last goal: Modernize the provisioning scripts and validate them (shellcheck + container run).
- Exact next action: Validate `ubuntu-system-prepare.sh` and `ubuntu-system-prepare-vm-dev.sh` end-to-end on a disposable Ubuntu 24.04/26.04 desktop (snap/flatpak/GUI); decide the security defaults and the AD/PyDrive questions in `TASKS.md`.
- Blocked by: No disposable Ubuntu desktop target available in this session (only a headless container, which covers the WSL entry point).
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

## Problems / Risks

- Physical and `vm-dev` scripts are unvalidated beyond lint; they need a desktop target with snap/flatpak/GUI. Running any script mutates a host (packages, `/etc/sudoers.d`, services).
- `ENABLE_PASSWORDLESS_SUDO=1`, `DISABLE_UFW=1`, `DISABLE_CUPS=1` carry security impact and are on by default for behavior parity.
- `K8S_MINOR` defaults to `v1.36` and may lag the latest release.
- PyDrive was removed; no Google Drive client is installed now.
- Committed and pushed to `origin/dev` (`799a37b`); `.DS_Store` is ignored via `.gitignore`.

## Validation Performed

- `bash -n` on all four scripts → all Validated.
- `shellcheck` (container) → Validated; one `SC1091` fixed.
- `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → Validated (exit 0).
- Physical and `vm-dev` end-to-end → Not validated (need snap/flatpak/GUI).

## Next Actions

- Validate physical/`vm-dev` on a disposable Ubuntu 24.04/26.04 desktop.
- Commit and push the modernization (context and scripts are uncommitted).
- Decide the security defaults and the AD/PyDrive questions in `TASKS.md`.
