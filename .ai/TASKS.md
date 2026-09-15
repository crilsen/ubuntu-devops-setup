# Current Work

## Active

- End-to-end validation of `ubuntu-system-prepare.sh` and `ubuntu-system-prepare-vm-dev.sh` on a disposable Ubuntu 24.04/26.04 desktop (they need snap/flatpak/GUI; the WSL entry point already passed — see Completed).

## Planned

- Run `shellcheck` once available and fix findings. (Done 2026-09-15; findings fixed.)
- Decide the security defaults: `ENABLE_PASSWORDLESS_SUDO`, `DISABLE_UFW`, `DISABLE_CUPS` are currently `1` to preserve the old behavior.
- Decide whether AD/domain integration (`realmd`/`sssd`/`realm join`, `cid`) is in scope; it is still commented out.
- Consider replacing the removed PyDrive Google Drive step with a supported client (`rclone`) or a venv/pipx-based install.
- Revisit `K8S_MINOR` (default `v1.36`) as new Kubernetes versions are released.

## Blocked

- None.

## Completed

- Adopted the portable agent-context template with observed facts.
- Modernized all scripts per ADR-004/ADR-005/ADR-006:
  - Fixed the `ubuntu-system-prepare.sh` syntax error and the `puthon3`/`java-default`/`aws-iam-authenticatorku` bugs.
  - Replaced `apt-key` with keyring `signed-by` sources; Docker Compose v2 plugin; `kubectl` via `pkgs.k8s.io`.
  - Teams for Linux via snap; removed retired Skype and redundant `aws-iam-authenticator`.
  - Added `set -euo pipefail`, root guard, `TARGET_USER`/`ARCH`/`CODENAME` detection, and idempotency.
  - Extracted shared logic into `ubuntu-system-prepare-common.sh` (ADR-005).
- `bash -n` passes for all four scripts.
- Ran `shellcheck` via the `koalaman/shellcheck:stable` container; fixed the only finding (`SC1091`) with a `# shellcheck source=/dev/null` directive.
- Ran `ubuntu-system-prepare-wsl-dev.sh` end-to-end in a disposable `ubuntu:24.04` arm64 container → exit 0 (base, git, java, python, Docker CE, kubectl 1.36.4, AWS CLI v2, zsh, passwordless sudo).
